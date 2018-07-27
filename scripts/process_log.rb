require 'pp'
require 'date'
require 'time'
require 'file-tail'
require 'thread'
require "resolv"

require_relative "attendance_log"
require_relative "attendance_interface"

def has_internet?
  dns_resolver = Resolv::DNS.new()
  dns_resolver.getaddress("symbolics.com") #the first domain name ever. Will probably not be removed ever.
  true
rescue Resolv::ResolvError => e
  false
end

class ProcessLog
  attr_reader :lock, :times, :checkin, :attendance

  def initialize
    @lock = Mutex.new
    @running = true

    @times = Hash.new { 0 }
    @checkin = {}

    @attendance = Attendance.new

    @thread = Thread.new do 
      while @running do
        if has_internet?
          lock.synchronize do
            if attendance.save
              puts "#{Time.now} Saved attendance data"
            end
          end
        end
        sleep 60
      end  
    end
  end

  def check_in(name, date, time)
    if checkin[name]
      if checkin[name].to_date == date
        # double checkin, do nothing?
      else
        # missed a checkout for previous date, mark it with an X
        row = attendance.get_name_row(name)
        col = attendance.get_date_col(checkin[name].to_date)
        attendance.set(row,col,times[[name,checkin[name].to_date]] || "X")
        checkin[name] = time
      end
    else
      # clean checkin
      checkin[name] = time
      row = attendance.get_name_row(name)
      col = attendance.get_date_col(date)
      attendance.set(row,col, times[[name,date]] || "X")
    end
  end

  def check_out(name, date, time)
    if checkin[name]
      row = attendance.get_name_row(name)
      if checkin[name].to_date == date
        col = attendance.get_date_col(date)
        duration = (time - checkin[name]) / (60.0 * 60.0)
        times[[name,date]] += duration
        attendance.set(row, col, times[[name,date]]) 
        checkin[name] = nil
      else
        col = attendance.get_date_col(checkin[name].to_date)
        checkin[name] = time
        attendance.set(row, col, 'X') 
      end
    else
      # checkout/checkin out of sync? treat this as a checkin
      row = attendance.get_name_row(name)
      col = attendance.get_date_col(time.to_date.to_s)
      checkin[name] = time     
      attendance.set(row, col, 'X') 
    end
  end

  def run
    log = nil
    if ARGV.first
      log = AttendanceLog.new(ARGV.first)
    else
      log = AttendanceLog.new
    end

    log.tail(!ARGV.first) do |date, time, cmd, ip, body|
      sleep(5) until has_internet?

      lock.synchronize do
        fname, lname, pin = *body.split(/\s+/)
        name = "#{fname} #{lname}"
        puts "#{Time.now} Processing #{time} #{cmd} #{ip} #{body}"
        #puts "#{fname.inspect} #{lname.inspect} #{pin.inspect}"

        case cmd
        when "IN"
          check_in(name, date, time)

        when "OUT"
          check_out(name, date, time)

        when "REG"
          #puts "#{Time.now} Resigering #{name}"
          attendance.new_row(fname, lname, pin)

        end
      end
    end
    @running = false
    @thread.join
    attendance.save

  rescue Interrupt
    puts "#{Time.now} Stopping..."
    times.each do |key, time|
      puts "#{key.first}: #{time}"
    end
    @running = false
    @thread.join
    attendance.save
  end
end

puts "#{Time.now} Starting log processing"
ProcessLog.new.run
puts "#{Time.now} Log processing complete"


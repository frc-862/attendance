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
  attr_reader :lock, :times, :checkin, :attendance, :prev_checkin

  def initialize
    @lock = Mutex.new
    @running = true

    @times = Hash.new { 0 }
    @checkin = {}
    @prev_checkin = {}

    @attendance = Attendance.new

    @thread = Thread.new do 
      while @running do
        if has_internet?
          lock.synchronize do
            if attendance.save
              puts "#{Time.now} Saved attendance data"
            end
            STDOUT.flush
          end
        end
        sleep 60
      end  
    end
  end

  def check_in(name, date, time)
    row = attendance.get_name_row(name)
    col = attendance.get_date_col(date)
    attendance.set(row,col,"X")
  end

  def log(*msg)
    puts "#{Time.now} #{msg.join(" ")}"
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
        fname, lname, pin, email = *body.split(/\s+/)
        name = "#{fname} #{lname}"
        row = attendance.get_name_row(name)
        puts "#{Time.now} Processing #{time} #{cmd} #{ip} #{body} (#{row})"
        #puts "#{fname.inspect} #{lname.inspect} #{pin.inspect}"

        case cmd
        when "IN"
          check_in(name, date, time)

        when "REG"
          #puts "#{Time.now} Resigering #{name}"
          attendance.new_row(fname, lname, pin, email)

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
    puts "Saved"
  rescue 
    puts "Unexpected error #{$!}"
    puts $!.backtrace
  end
end

puts "#{Time.now} Starting log processing"
sleep 1 until has_internet?
puts "#{Time.now} Internet connected"

running = true
while running do
  begin
    ProcessLog.new.run
    running = ARGV.first.nil?
  rescue
    puts "#{Time.now} Error: #{$!}"
    sleep 30
  end
end
puts "#{Time.now} Log processing complete"


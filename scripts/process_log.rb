require 'pp'
require 'date'
require 'time'
require 'file-tail'
require 'thread'

require_relative "attendance_log"
require_relative "attendance_interface"

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
        lock.synchronize do
          attendance.save
        end
        sleep 5
      end  
    end
  end

  def run
    log = AttendanceLog.new
    log.tail do |date, time, cmd, ip, body|
      lock.synchronize do
        fname, lname, pin = *body.split(/\s+/)
        name = "#{fname} #{lname}"
        puts "#{date} #{time} #{cmd} #{ip} #{body}"
        puts "#{fname.inspect} #{lname.inspect} #{pin.inspect}"

        case cmd
        when "IN"
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

        when "OUT"
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

        when "REG"
          attendance.new_row(fname, lname, pin)

        end
      end
    end
  rescue Interrupt
    puts "Stopping..."
    times.each do |key, time|
      puts "#{key.first}: #{time}"
    end
    @running = false
    @thread.join
    attendance.save
  end
end

ProcessLog.new.run


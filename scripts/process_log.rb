require 'pp'
require 'date'
require 'time'
require 'file-tail'
require 'thread'

require_relative "attendance_interface"

lock = Mutex.new
running = true

times = Hash.new { 0 }
checkin = {}

attendance = Attendance.new

thread = Thread.new do 
  while running do
    lock.synchronize do
      attendance.save
    end
    sleep 5
  end  
end

File.open("../attendance.log") do |log|
  log.extend(File::Tail)
  log.interval # 10
  #log.backward(10)
  begin
    log.tail do |line| 
      # 2018-07-24 17:22:08 -0400 IN    127.0.0.1       Shane Hurley
      if line.match(/^(.{25})\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*(\S+)?/)
        lock.synchronize do
          puts $~.captures.inspect
          time, cmd, ip, fname, lname, pin = $~.captures 
          name = "#{fname} #{lname}"
          time = Time.parse(time)
          date = time.to_date

          case cmd
          when "IN"
            if checkin[name]
              if checkin[name].to_date == date
                # double checkin, do nothing?
              else
                # missed a checkout for previous date, mark it with an X
                row = attendance.get_name_row("#{fname} #{lname}")
                col = attendance.get_date_col(checkin[name].to_date)
                attendance.set(row,col,times[[name,checkin[name].to_date]] || "X")
                checkin[name] = time
              end
            else
              # clean checkin
              checkin[name] = time
              row = attendance.get_name_row("#{fname} #{lname}")
              col = attendance.get_date_col(date)
              attendance.set(row,col, times[[name,date]] || "X")
            end

          when "OUT"
            if checkin[name]
              row = attendance.get_name_row("#{fname} #{lname}")
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
              row = attendance.get_name_row("#{fname} #{lname}")
              col = attendance.get_date_col(time.to_date.to_s)
              checkin[name] = time     
              attendance.set(row, col, 'X') 
            end

          when "REG"
            attendance.new_row(fname, lname, pin)

          end
        end
      end
    end 
  rescue Interrupt
    puts "Stopping..."
    puts times.inspect
    running = false
  end
end

running = false
thread.join
attendance.save


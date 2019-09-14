require 'time'
require 'date'
require 'fileutils'

require_relative "attendance_log.rb"

Dir.chdir("/home/frc862/attendance")
system("pumactl -F puma.rb stop")
system("pkill -f process_log.rb")

FileUtils.mv("attendance.log", "attendance.tmp")

today = Date.today
files = Hash.new { |hash,key| File.open(key.strftime("attendance-%Y%m%d.log"), "a") }
files[today] = File.open("attendance.log", "a");

File.open("attendance.tmp", "r") do |att|
  att.each_line do |line|
    if line.match(/^(.{25})/)
      date = Time.parse($1).localtime.to_date
      files[date].puts line
    end
  end
end

files.values.each do |out|
  out.close
end

FileUtils.rm("attendance.tmp")

sname = File.join(File.dirname(__FILE__), 'dump_member.rb')
system("ruby #{sname}")
system("/home/frc862/attendance/process-log")
system("pumactl -F puma.rb start")


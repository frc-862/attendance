require 'time'
require 'date'
require 'fileutils'

require_relative "attendance_log.rb"

Dir.chdir("/home/attendance/attendance")
system("pumactl -F puma.rb stop")

FileUtils.mv("attendance.log", "attendance.tmp")

today = Date.today
files = Hash.new { |hash,key| File.open(key.strftime("attendance-%Y%m%d.log"), "a") }
files[today] = File.open("attendance.log", "a");

File.open("attendance.tmp", "r") do |att|
  att.each_line do |line|
    if line.match(/^(.{10})/)
      date = Date.parse($1)
      files[date].puts line
    end
  end
end

files.values.each do |out|
  out.close
end

FileUtils.unlink("attendance.tmp")
system("pumactl -F puma.rb start")


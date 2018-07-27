

class AttendanceLog

  def initialize(fname = File.absolute_path(File.dirname(__FILE__) + "/../attendance.log"))
    @fname = fname
  end

  def append(op, ip, *value)
    File.open(@fname, "a") do |out|
      out.puts("#{Time.now} #{op.to_s.ljust(5)} #{ip.to_s.ljust(15)} #{value.join("\t")}")
    end
  end

  def foreach
    File.open(@fname).each_line do |line|
      if line.match(/^(.{25})\s+(\S+)\s+(\S+)\s+(.*)$/)
        time, cmd, ip, body = $~.captures 
        time = Time.parse(time)
        date = time.to_date
        yield date, time, cmd, ip, body
      end
    end
  end

  def tail
    File.open(@fname) do |log| 
      log.extend(File::Tail)
      log.interval # 10
      log.tail do |line| 
        if line.match(/^(.{25})\s+(\S+)\s+(\S+)\s+(.*)$/)
          time, cmd, ip, body = $~.captures 
          time = Time.parse(time)
          date = time.to_date
          yield date, time, cmd, ip, body
        end
      end
    end
  end

end



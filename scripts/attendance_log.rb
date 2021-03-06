

class AttendanceLog

  def initialize(fname = File.absolute_path(File.dirname(__FILE__) + "/../attendance.log"))
    @fname = fname
  end

  def append(op, ip, *value)
    File.open(@fname, "a") do |out|
      out.puts("#{Time.now} #{op.to_s.ljust(5)} #{ip.to_s.ljust(15)} #{value.join("\t")}")
    end
  end

  def process_line(line)
    if line.match(/^(.{25})\s+(\S+)\s+(\S+)\s+(.*)$/)
      time, cmd, ip, body = $~.captures 
      time = Time.parse(time).localtime
      date = time.to_date
      yield date, time, cmd, ip, body
    end
  end

  def foreach(&block)
    File.open(@fname).each_line do |line|
      process_line(line, &block)
    end
  end

  def tail(follow = true, &block)
    if follow
      File.open(@fname) do |log| 
        log.extend(File::Tail)
        log.interval # 10
        log.tail do |line| 
          process_line(line, &block)
        end
      end
    else
      File.open(@fname).each_line do |line|
        process_line(line, &block)
      end
    end
  end

end



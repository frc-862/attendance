require 'google_drive'
require 'faker'
require 'pp'

class Attendance 
  def initialize 
    @session = GoogleDrive.saved_session("config.json")
    @sheet = @session.spreadsheet_by_title("2019-2020 Attendance Tracker")
    @hours = @sheet.worksheets[0]
  end
 
  def session
    @session
  end

  def set(row, col,value)
    @hours[row,col] = value
  end

  def get(row, col)
    @hours[row,col]
  end

  def save 
    @hours.save
  end 

  FIRST_NAMECOL = 1
  LAST_NAMECOL = 2
  RFIDCOL = 3
  TOTALCOL = 4
  STUDCOL = 5
  EMAILCOL = 6
  FIRST_DATE_COL = 7

  DATEROW = 1
  HOURROW = 2
  TYPEROW = 4
  NAMEROW = 5

  def dump_members
    fname = File.join(File.dirname(__FILE__), '..', "names.txt")
    File.open(fname, "w") do |members|
      (NAMEROW..@hours.num_rows).each do |row|
	email = @hours[row, EMAILCOL].to_s
        name = "#{@hours[row,FIRST_NAMECOL]} #{@hours[row,LAST_NAMECOL]}".strip
        id = @hours[row, RFIDCOL].to_s.rjust(10,'0')
	stud = @hours[row, STUDCOL].to_i
        studid = @hours[row, STUDCOL].to_s
        @hours[row, STUDCOL] = studid

        name = Faker::Name.name if name.to_s.length == 0

        members.puts "#{name}\t#{stud}\t#{email}"
      end
    end
  end

  def get_date_col(date)
    date = date.to_s
    (1..@hours.num_cols).each do |col|
      next if col <= EMAILCOL

      if date == @hours[DATEROW,col]
        return col
      end
    end

    # did not find date, add it 
    col = @hours.num_cols + 1
    @hours[DATEROW, col] = date 
    newdate = Date.parse(date)
    weekday = (1..5) === newdate.wday
    after_kickoff = newdate >= Date.new(2020,1,4)
    if weekday
      @hours[HOURROW, col] = after_kickoff ? 4 : 3
      @hours[TYPEROW, col] = 'M'
    else
      @hours[HOURROW, col] = 8
      @hours[TYPEROW, col] = after_kickoff ? 'M' : 'O'
    end
    return @hours.num_cols
  end 

  def get_rfid_row(rfid)
    rfid = rfid.to_i
    (1..@hours.num_rows).each do |row|
      if rfid == @hours[row, RFIDCOL].to_i
        return row
      end 
    end 
    #could not find the id number
    new_row = @hours.num_rows + 1 
    @hours[new_row, RFIDCOL] = rfid
    @hours[new_row, TOTALCOL] = %Q|=SUMIF(G#{new_row}:#{new_row}, "X", G2:2)|
    return new_row
  end 

  def new_row(fname, lname, id, email='')
    newrow = get_name_row("#{fname} #{lname}")
    if newrow 
      #@hours[newrow, STUDCOL] = id
    else
      new_row = @hours.num_rows + 1 
      @hours[new_row, STUDCOL] = id
      @hours[new_row, FIRST_NAMECOL] = fname
      @hours[new_row, LAST_NAMECOL] = lname
      @hours[new_row, EMAILCOL] = email
      @hours[new_row, TOTALCOL] = %Q|=SUMIF(G#{new_row}:#{new_row}, "X", G2:2)|
    end

    new_row
  end

  def get_name_row(name)
    name = name.to_s.strip.gsub(/\s+/," ")
    (1..@hours.num_rows).each do |row|
      #puts "#{name.chars.inspect} -- #{row}"
      #puts "#{@hours[row, FIRST_NAMECOL]} #{@hours[row, LAST_NAMECOL]}".strip.gsub(/\s+/," ").chars.inspect
      if name == "#{@hours[row, FIRST_NAMECOL]} #{@hours[row, LAST_NAMECOL]}".strip.gsub(/\s+/," ")
        return row
      end 
    end 

    return nil
  end 

  def each_date 
    (FIRST_DATE_COL..@hours.num_cols).each do |col|
      yield col, @hours[DATEROW, col]
    end
  end

  def each_student(col)
    data = nil
    (2..@hours.num_rows).each do |row|
      data = @hours[row, col] unless col.nil?
      yield row, @hours[row, FIRST_NAMECOL], @hours[row, LAST_NAMECOL], data
    end
  end

end 


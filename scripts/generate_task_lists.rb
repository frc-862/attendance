require 'smartsheet'
require 'prawn'
require 'date'
require 'time'
require 'pp'

class SSheet
  def self.client
    @Smartsheet_client ||= Smartsheet::Client.new(token: IO.read("key.txt"))
  end

  def sheets
    @sheets ||= client.sheets.list
  end

  def client
    SSheet.client
  end

  def initialize(name)
    # Select sheet by name
    @sheet_id = sheets[:data].first { |s| s[0][:name] == name }[:id]

    # Load the entire sheet
    @sheet = client.sheets.get(sheet_id: @sheet_id)
  end

  def dump
    @sheet
  end

  def modified_at
    Time.parse(@sheet[:modified_at])
  end

  def columns
    # :id, :title, :index
    @sheet[:columns] 
  end

  def rows
    @sheet[:rows]
  end

  def row(num)
    rows.find { |r| r[:row_number].to_i - 1 == num  || r[:id].to_i == num }
  end

  def find_column_id(id)
    result = columns.find { |c| c[:index] == id || c[:title] == id || c[:id] == id }
    result[:id] 
  end

  def find_cell(r, column)
    colid = find_column_id(column)
    r = row(r)
    r[:cells].find { |c| c[:column_id] == colid }
  end

  def parent_cell(r, column)
    r = row(r)
    if r && r[:parent_id]
      find_cell(r[:parent_id], column)[:value]
    end
  end

  def cell(r, column)
    find_cell(r, column)[:value]
  end

  def display_cell(r, column)
    find_cell(r, column)[:display_value]
  end

  def column_hash
    columns.map { |c| [c[:title], c[:index] ] }
  end

  def length
    @sheet[:total_row_count]
  end
end

def build_report(fname)
  # select first task without a predecessor or a fulfilled predecessor by date
  # if all tasks have a predecessor 

  #if File.exists?(fname) && File.mtime(__FILE__) <= File.mtime(fname)
    #return
  #end

  ss = SSheet.new("2019 Build Season")

  if File.exists?(fname)
    if File.mtime(fname) > ss.modified_at && 
        File.mtime(__FILE__) <= File.mtime(fname) &&
        File.mtime(__FILE__) <= ss.modified_at
      ## skip if up to date
      return
    end
  end

  puts "Building report #{fname}"

  tasks = {}
  tasks["Strategy"] = nil
  tasks["Design"] = nil
  tasks["Fabrication"] = nil
  tasks["Electrical"] = nil
  tasks["Programming"] = nil

  completed = {}
  stats = {}

  ss.length.times do |i|
    assigned = ss.display_cell(i, "Assigned To")

    if assigned == "Robot Statistics"
      stats[ss.cell(i,0)] = ss.cell(i, "Comments")
      next
    end

    status = ss.cell(i, "Status")
    #next if status == "Complete"
    next if completed[i+1] = (status == "Complete")

    start = Date.parse(ss.cell(i, "Start")) rescue nil
    #next if start > (Date.today + 4)

    next if assigned.to_s.strip.empty?
    next if assigned.to_s.strip == "Leadership"
    next if assigned.to_s.strip == "Full Team"
    next if assigned.to_s.strip == "Full team"
    next if assigned.to_s.strip.match(/^Team/)
    #next if assigned.to_s.strip == "Controls"
    next if assigned.to_s.strip == "EO"

    priority = ss.cell(i, "Priority").to_i
    next if priority < 1 || priority > 3

    #next if tasks[assigned]
    tasks[assigned] ||= []

    predecessor = ss.cell(i, "Predecessors")
    if predecessor.nil?
      predecessor = ss.parent_cell(i, "Predecessors")
    end

    tasks[assigned] << [ ss.cell(i,0), ss.cell(i, "Duration"), 
                         (Date.parse(ss.cell(i, "Start")) rescue nil), 
                         (Date.parse(ss.cell(i, "Finish")) rescue nil), 
                         predecessor, ss.cell(i, "% Complete"), 
                         status, ss.cell(i, "Comments"), priority]
  end

  #pp completed
  #pp tasks
  #pp ss.column_hash

  black = '000000'
  white = 'FFFFFF'
  green = '36DA5C'
  yellow = "a5aa05"
  red = "8e0202"

  today = Date.today
  first = true
  Prawn::Document.generate(fname, page_layout: :landscape, page_size: "LETTER") do
    tasks.keys.each do |group|
      start_new_page unless first
      image "lightning.png", width: 150
      text_box "<b><font size='20'>#{group} Task List</font></b>\n" +
        "#{Date.today.strftime("%-d %b %Y")}\n" +
        "\n" + 
        "Current robot weight is <b>#{stats['Weight']} lbs</b>, and our BOM is at <b>" +
        "$#{sprintf("%.02f", stats['BOM'].to_f)}</b>\n" + 
        "#{stats['Notes']}\n",
        at: [175, bounds.top - 55], 
        width: bounds.right,
        inline_format: true

      move_down 20
     
      tasks[group].each do |title, duration, start, finish, predecessor, complete, status, comment|
        if finish
          if finish < today
            fill_color red
          elsif finish + 1 <= today 
            fill_color yellow
          elsif
            fill_color green
          end
        else
          fill_color white
        end
        fill_and_stroke_rounded_rectangle [0,cursor], 10, 10, 1
        fill_color '000000'
        indent 13 do
          text "#{title} #{status} #{if complete.to_f > 0.001 then "(#{complete.to_f * 100.0}%) " end}due #{finish}"
          if comment && comment.to_s.length > 0
            indent 20 do 
              text comment
            end
          end
        end
        move_down 10
      end

      first = false
    end

=begin
    tasks["Fabrication"].each do |title, duration, start, finish, predecessor, complete, status, comment|
      text "Title #{title}"
      text "Duration #{duration}"
      text "Start #{start}"
      text "Finish #{finish}"
      text "Predecessor #{predecessor}"
      text "Complete #{complete}"
      text "Status #{status}"
      text "Comment #{comment}"
      move_down 10
    end
  end
=end
    puts "report #{fname} complete"
  end
end


  if __FILE__ == $0
    build_report(ARGV.first || "task_list.pdf")
  end



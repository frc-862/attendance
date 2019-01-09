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

def build_proto_report(fname)
  # select first task without a predecessor or a fulfilled predecessor by date
  # if all tasks have a predecessor 

  ss = SSheet.new("2019 Build Season")

  if File.exists?(fname)
    if File.mtime(fname) > ss.modified_at
      ## skip if up to date
      return
    end
  end

  tasks = {}
  tasks["Team Cargo"] = nil

  completed = {}
  ss.length.times do |i|
    assigned = ss.display_cell(i, "Assigned To")
    status = ss.cell(i, "Status")
    next if completed[i+1] = (status == "Complete")

    next if assigned.to_s.strip.empty?
    next unless assigned.to_s.strip.match(/^Team/)

    next if tasks[assigned]

    predecessor = ss.cell(i, "Predecessors")
    if predecessor.nil?
      predecessor = ss.parent_cell(i, "Predecessors")
    end

    tasks[assigned] = [ ss.cell(i,0), ss.cell(i, "Duration"), 
                        (Date.parse(ss.cell(i, "Start")) rescue nil), 
                        (Date.parse(ss.cell(i, "Finish")) rescue nil), 
                        predecessor, ss.cell(i, "% Complete"), 
                        status, ss.cell(i, "Comments")]
  end

  #pp completed
  #pp tasks
  #pp ss.column_hash


  Prawn::Document.generate(fname, page_layout: :landscape, page_size: "LETTER") do
    image "lightning.png", width: 150
    text_box "<b><font size='20'>Prototype Status Overview</font></b>\n" +
      "#{Date.today.strftime("%-d %b %Y")}\n", 
      at: [175, bounds.top - 55], 
      width: bounds.right,
      inline_format: true

    move_down 20
    column = 0

    tasks.each do |group, gtasks|
      title, duration, start, finish, predecessor, complete, status, comment = *gtasks

      stext = ""
      color = "086b03" # Green
      yellow = "a5aa05"
      red = "8e0202"

      if (predecessor && !completed[predecessor.to_i])
        #puts "#{title} BLOCKED: #{predecessor}"
        stext = "blocked by #{ss.cell(predecessor.to_i - 1, 0)}"
      else
        stext = "#{status} #{complete.to_f * 100}% complete"
      end

      if finish == Date.today or finish == (Date.today + 1)
        color = yellow
      elsif finish && finish < Date.today
        color = red
      end

      text_box "<b><font size='14'>#{group}</font></b>\n" +
        "Current Task: #{gtasks.first}\n" +
        "Status: <color rgb='#{color}'>#{stext}</color>\n" +
        "due #{finish.strftime("%-d-%b")}\n#{comment}",
        at: [0 + column * bounds.right / 2, cursor],
        width: bounds.right / 2,
        inline_format: true

      column = (column + 1) % 2
      if column == 0
        move_down 105
      end

    end

  end
end

if __FILE__ == $0
  build_proto_report(ARGV.first || "proto_status.pdf")
end


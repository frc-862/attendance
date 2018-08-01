require 'rubygems'
require 'bundler'

Bundler.require

require_relative "scripts/attendance_log.rb"

NAME_FILE = "names.txt"

class Attendance < Sinatra::Base
  helpers Sinatra::Cookies
  enable :sessions
  register Sinatra::Flash

  configure :development do
    register Sinatra::Reloader
  end

  def self.check_log_file
    last_time = Time.now
    @@log.foreach do |date, time, cmd, ip, body|
      last_time = time if last_time < time 
    end

    if last_time > Time.now
      system(%Q|sudo date --set="#{Time.now}"|)
    end

    today = last_time.to_date
    @@log.foreach do |date, time, cmd, ip, body|
      next unless date == today

      fname, lname, pin = *body.split(/\s+/)
      name = "#{fname} #{lname}"

      if cmd == "IN"
        @@checked[name] = time
      elsif cmd == "OUT"
        @@checked[name] = nil
      elsif cmd == "REG"
        @@names[name] = pin
      end
    end

    last_time
  end 

  def self.read_names
    @@names = {}
    check_log_file

    IO.read(NAME_FILE).each_line.map do |line| 
      next if line.match(/^\s*$/)
      next if line.match(/^\s*#/)

      if line.match(/^\s*(\S+)\s+(\S+)\s+(\S+)/)
        @@names["#{$1} #{$2}"] = $3
      end
    end
  end

  configure do 
    @@log = AttendanceLog.new
    @@names ||= nil 
    @@checked ||= {}

    read_names if @@names.nil?
  end

  before do
    @names = @@names
    @checked = @@checked
    @cookies = cookies
  end

  def ip
    env["HTTP_X_FORWARDED_FOR"] || request.ip
  end

  def append(op, *values)
    @@log.append(op, ip, *values)
  end

  #get '/cookies/:key/:value' do
    #cookies[params[:key]] = params[:value]
  #end

  get '/cookies/:key' do
    cookies[params[:key]]
  end

  get '/cookies' do
    cookies.inspect
  end

  get '/' do
    redirect "/checkin"
  end

  post '/' do
    if params[:register]
      redirect "/register"    
    else
      redirect "/checkin"    
    end  
  end

  get "/logout" do
    cookies.clear
    redirect "/checkin"
  end

  post "/logout" do
    cookies.clear
    redirect "/checkin"
  end

  get "/checkin" do
    if @@names[cookies[:easy_checkin]] 
      if @@checked[cookies[:easy_checkin]]
        redirect "/checkout"
      else
        haml :easy_checkin
      end
    else
      haml :checkin
    end
  end

  post '/checkin' do
    if params[:register]
      redirect "/register"
    elsif params[:name]
      if cookies[:easy_checkin] == params[:name] || @@names[params[:name]] == params[:student_id]
        @@checked[params[:name]] = Time.now
        append("IN", params[:name])
        cookies[:easy_checkin] = params[:name]
        response.set_cookie 'easy_checkin', {:value=> params[:name], :max_age => "31536000"}
        redirect "/checkout"    
      else
        flash[:error] = "Sorry your student id does not match your name." 
        redirect "/checkin"
      end
    else
      params.inspect

      #redirect "/checkin"    
    end
  end

  get "/checkout" do
    if @@names[cookies[:easy_checkin]] 
      if @@checked[cookies[:easy_checkin]]
        @checkin = @@checked[cookies[:easy_checkin]]
        haml :easy_checkout
      else
        redirect "/checkin"
      end
    else
      haml :checkout
    end
  end

  get "/logout" do
    cookies.clear
    redirect "/checkin"    
  end

  post '/checkout' do
    if params[:name] && @@names[params[:name]] == params[:student_id]
      @@checked[params[:name]] = nil
      append("OUT", params[:name])
      redirect "/checkin"    
    else
      redirect "/checkout"    
    end
  end

  get "/register" do
    haml :register
  end

  post "/register" do
    name = params.values_at(:first_name, :last_name).join(" ")
    if @@names[name]
      flash[:error] = "Sorry you cannot register #{name}, it is already registered."
      redirect "/register"
    else
      @@names[name] = params[:student_id]
      append("REG", params.values_at(:first_name, :last_name, :student_id))
      redirect "/checkin"
    end
  end

  get "/time" do
    haml :time    
  end

  post "/time" do
    time = Time.parse(params[:time])
    if (time - Time.now).abs > 300
      system(%Q|sudo date --set="#{time}"|)
    end
    Time.now.rfc2822
  end

  get "/checked-in" do
    haml :checked_in
  end

  get "/close-down" do
    haml :close_down
  end

  post "/close-down" do
    if params[:pin] == "862465"
      @@checked.each do |name, date|
        @@checked[name] = nil
        append("OUT", name)
      end
    else
      flash[:error] = "Invalid PIN"
    end
    redirect "/checked-in"
  end
end


require 'rubygems'
require 'bundler'
require 'time'
require 'date'

Bundler.require

require_relative "scripts/attendance_log.rb"
require_relative "scripts/generate_status.rb"
require_relative "scripts/generate_proto_status.rb"

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
      # next unless date == today
      fname, lname, pin = *body.split(/\s+/)
      name = "#{fname} #{lname}"

      if cmd == "IN"
        @@checked[name] = time
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
    #@@closed = true
    @@closed = false

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

  get '/checked' do
    @@checked.inspect
  end

  before do
    if request.path_info != "/closed" && request.path_info != "/open" && 
		request.path_info != "/status" && request.path_info != "/proto_status"
       redirect "/closed" if @@closed 
    end
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

  get "/open" do
    haml :open
  end

  get "/status" do
    redirect "/checked_in"
  end

  post "/open" do
    if params[:pin] == "862465"
      @@closed = false
      redirect "/checked-in"
    else
      redirect "/open"
    end
  end

  get "/closed" do
    haml :closed
  end

  get "/logout" do
    cookies.clear
    cookies[:easy_checkin] = nil
    response.set_cookie 'easy_checkin', nil

    redirect "/checkin"
  end

  post "/logout" do
    cookies.clear
    cookies[:easy_checkin] = nil
    response.set_cookie 'easy_checkin', nil

    redirect "/checkin"
  end

  get "/easy_checkin" do
    haml :easy_checkin
  end

  get "/checkin" do
    easy = false
    if @@names[cookies[:easy_checkin]] 
      if cookies[:easy_checkin] && @@checked[cookies[:easy_checkin]] && @@checked[cookies[:easy_checkin]].to_date != Date.today
	  easy = true
	  redirect "/easy_checkin"
      end
    end
    haml :checkin unless easy
  end

  post '/checkin' do
    if params[:register]
      redirect "/register"
    elsif params[:logout]
      redirect "/logout"
    elsif params[:loop]
      redirect "/checkin"
    elsif params[:countdown]
      redirect "/checked-in"
    elsif params[:name]
      if (@@names[params[:name]] == params[:student_id]) || (cookies[:easy_checkin] == params[:name])
	  if @@checked[params[:name]] && @@checked[params[:name]].to_date != Date.today
	    @@checked[params[:name]] = Time.now
	    append("IN", params[:name], params[:pos])
	  end
          cookies[:easy_checkin] = params[:name]
          response.set_cookie 'easy_checkin', {:value=> params[:name], :max_age => "31536000"}
	  flash[:error] = "You are now checke in." 
	  redirect "/checked-in"
      else
        flash[:error] = "Sorry your student id does not match your name." 
      end
      redirect "/checkin"    
    end
  end

  get "/register" do
    haml :register
  end

  post "/register" do
    name = params.values_at(:first_name, :last_name).map {|n| n.strip }.join(" ")
    if @@names[name]
      flash[:error] = "Sorry you cannot register #{name}, it is already registered."
      redirect "/register"
    else
      @@names[name] = params[:student_id]
      append("REG", params.values_at(:first_name, :last_name, :student_id, :email))
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
      @@closed = true
      redirect "/open"
    else
      flash[:error] = "Invalid PIN"
      redirect "/checked-in"
    end
  end
end


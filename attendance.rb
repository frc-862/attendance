require 'rubygems'
require 'bundler'

Bundler.require

LOG_FILE = "attendance.log"
NAME_FILE = "names.txt"

def append(op, *value)
  File.open(LOG_FILE, "a") do |out|
    ip = env["HTTP_REMOTE_ADDR"]
    out.puts("#{Time.now} #{op.to_s.ljust(5)} #{ip.to_s.ljust(15)} #{value.join("\t")}")
  end
end

class Attendance < Sinatra::Base
  helpers Sinatra::Cookies
  enable :sessions
  register Sinatra::Flash

  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end
 
  configure do 
    @@names ||= nil 
    if @@names.nil?
      @@names = {}
      IO.read(NAME_FILE).each_line.map do |line| 
        next if line.match(/^\s*$/)
        next if line.match(/^\s*#/)

        if line.match(/^\s*(\S+)\s+(\S+)\s+(\S+)/)
          @@names["#{$1} #{$2}"] = $3
        end
      end
    end

    @@checked ||= {}
  end

  before do
    @names = @@names
    @checked = @@checked
    @cookies = cookies
  end

  get '/cookies/:key/:value' do
    cookies[params[:key]] = params[:value]
  end

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
    if @names[cookies[:easy_checkin]] 
      if @checked[cookies[:easy_checkin]]
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
      if cookies[:easy_checkin] == params[:name] || @names[params[:name]] == params[:student_id]
        @checked[params[:name]] = Time.now
        append("IN", params[:name])
        cookies[:easy_checkin] = params[:name]
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
    if @names[cookies[:easy_checkin]] 
      if @checked[cookies[:easy_checkin]]
        @checkin = @checked[cookies[:easy_checkin]]
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
    if params[:name]
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
    @@names[params.values_at(:first_name, :last_name).join(" ")] = params[:student_id]
    append("REG", params.values_at(:first_name, :last_name, :student_id))
    redirect "/checkin"
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


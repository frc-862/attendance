require 'rubygems'
require 'bundler'

Bundler.require

LOG_FILE = "attendance.log"
NAME_FILE = "names.txt"

def append(op, name)
  File.open(LOG_FILE, "a") do |out|
    out.puts("#{Time.now} #{op.to_s.ljust(5)} #{request.ip.to_s.ljust(15)} #{name}")
  end
end

class Attendance < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end
 
  configure do 
    @@names ||= IO.read(NAME_FILE).each_line.to_a
    @@checked ||= {}
  end

  before do
    @names = @@names
    @checked = @@checked
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

  get "/checkin" do
    haml :checkin
  end

  post '/checkin' do
    if params[:register]
      redirect "/register"
    elsif params[:name]
      @@checked[params[:name]] = Time.now
      append("IN", params[:name])
      redirect "/checkout"    
    else
      redirect "/checkin"    
    end
  end

  get "/checkout" do
    haml :checkout
  end

  post '/checkout' do
    puts "checkout"
    puts params.inspect
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
    @@names << params[:name]  
    @@names.sort!
    File.open(NAME_FILE,"w") do |out|
      out.puts @@names
    end
    append("REG", params[:name])
    redirect "/checkin"
  end

  get '/test' do
    haml :test
  end
  
  #run! if app_file == $0
end


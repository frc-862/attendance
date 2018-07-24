require 'rubygems'
require 'bundler'

Bundler.require

class Attendance < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end
 
  configure do 
    @@names ||= IO.read("names.txt").each_line.to_a
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
    elsif params[:checkin]
      @@checked[params[:name]] = Time.now
      redirect "/checkout"    
    elsif params[:checkout]
      @@checked[params[:name]] = nil
      redirect "/checkin"    
    else
      params.inspect
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
      redirect "/checkout"    
    else
      redirect "/checkin"    
    end
  end

  get "/checkout" do
    haml :checkout
  end

  post '/checkout' do
    if params[:name]
      @@checked[params[:name]] = nil
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
    File.open("names.txt","w") do |out|
      out.puts @@names
    end
    redirect "/checkin"
  end

  get '/test' do
    haml :test
  end
  
  #run! if app_file == $0
end


require 'rubygems'
require 'bundler'

Bundler.require

class Attendance < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end
 
  configure do 
    @@names ||= %W(Patrick Susan Collin Allison Shane Ruby)
  end

  get '/' do
    @names = @@names
    haml :index
  end

  post '/' do
    if params[:register]
      redirect "/register"    
    end  
  end

  get "/register" do
    haml :register
  end

  post "/register" do
    @@names << params[:name]  
    @@names.sort!
    redirect "/"
  end

  get '/test' do
    haml :test
  end
  
  #run! if app_file == $0
end


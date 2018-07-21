require 'rubygems'
require 'bundler'

Bundler.require

class Attendance < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end

  get '/' do
    @names = %W(Patrick Susan Collin Allison Shane Ruby)
    haml :index
  end

  get '/test' do
    haml :test
  end
  
  #run! if app_file == $0
end


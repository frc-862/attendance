require 'rubygems'
require 'bundler'

Bundler.require

class Attendance < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    #also_reload '/path/to/some/file'
  end

  get '/' do
    "SMan was here"
  end

  get '/test' do
    haml :test
  end
  
  run! if app_file == $0
end


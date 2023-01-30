require 'sinatra'
require 'sinatra/content_for'
require 'securerandom'
require 'tilt/erubis'

get '/' do
  redirect '/index'
end

get '/index' do
  erb :index
end
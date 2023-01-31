require 'sinatra'
require 'sinatra/content_for'
require 'securerandom'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

require_relative 'validation_helpers'
require_relative 'messages'

SESSION_SECRET = 'f33e430e5b16df7fa05493b7468296655ab6b6c39a0da3b562c665c3f863ff5f'.freeze

configure do
  enable :sessions
  set :session_secret, SESSION_SECRET
  set :erb, :escape_html => true
end

# Other helpers
def data_path
  path = ENV['RACK_ENV'] == 'test' ? '../test/data' : '../data'

  File.expand_path(path, __FILE__)
end

def data_directory_content
  Dir[File.join(data_path, '*')].map { |file_path| File.basename(file_path) }
end

helpers do
  def load_content(file_path, editable: false)
    return File.read(file_path) if editable

    if file_path.match?(/\w+.md/) then load_md(file_path)
    else
      load_text(file_path)
    end
  end
  
  def load_text(file_path)
    content = File.readlines(file_path).map { |line| line }.join
    "<textarea rows=\"20\" cols=\"100\" readonly>#{content}</textarea>"
  end

  def load_md(file_path)
    markdown_parser = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

    File.readlines(file_path).map do |line|
      "#{markdown_parser.render(line)}<br>"
    end.join
  end
end

# Sign-in page:
get '/users/signin' do
  erb :sign_in
end

post '/users/signin' do
  session[:username] = params[:username]

  if valid_user_credentials?(params[:username], params[:password])
    session[:logged_in] = true
    session[:success] = SUCCESS_USER_SIGNED_IN
    redirect '/'
  else
    session[:error] = ERROR_INVALID_CREDENTIALS
    status 422
    erb :sign_in
  end
end

# Index page:
get '/' do
  redirect('/users/signin') unless user_logged_in?

  @file_list = data_directory_content
  erb :index
end

post '/users/signout' do
  session.delete :username
  session.delete :logged_in
  session[:success] = SUCCESS_USER_SIGNED_OUT
  redirect '/'
end

# File contents page:
get %r{\/([\w]+\.\w+)} do |file_name|
  require_logged_in_user

  file_path = "#{data_path}/#{file_name}"
  require_valid_reference(file_name, file_path)

  @file_name = File.basename(file_path)
  @file_content = load_content(file_path)

  erb :file_content
end

# Edit file page:
get '/:file_name/edit' do |file_name|
  require_logged_in_user

  file_path = "#{data_path}/#{file_name}"
  require_valid_reference(file_name, file_path)

  @file_name = File.basename(file_path)
  @file_content = load_content(file_path, editable: true)

  erb :edit_file
end

# Sends the new content for the file:
post '/:file_name/edit' do |file_name|
  require_logged_in_user

  file_path = "#{data_path}/#{file_name}"
  require_valid_reference(file_name, file_path)

  File.write(file_path, params[:file_content])
  session[:success] = "#{file_name}#{SUCCESS_FILE_UPDATED}"
  redirect '/'
end

# Create a new document page:
get '/new' do
  require_logged_in_user

  erb :new_document
end

post '/new' do
  require_logged_in_user

  file_name = params[:document_name]
  validity = check_validity(file_name)

  if validity == :valid
    File.new("#{data_path}/#{file_name}", "w")
    session[:success] = "#{file_name}#{SUCCESS_FILE_CREATED}"
    
    redirect '/'
  else
    session[:error] = validity == :invalid ? ERROR_NAME_INVALID : ERROR_EXISTING_FILE

    status 422
    erb :new_document
  end
end

post '/:file_name/delete' do |file_name|
  require_logged_in_user

  file_path = "#{data_path}/#{file_name}"
  require_valid_reference(file_name, file_path)

  File.delete(file_path)
  session[:success] = "#{file_name}#{SUCCESS_FILE_DELETED}"

  redirect '/'
end

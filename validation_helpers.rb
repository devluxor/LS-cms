CREDENTIALS_TEST = '../test/users.yml'
CREDENTIALS = '../users.yml'

def valid_user_credentials?(username, password)
  credentials = load_user_credentials

  return false unless credentials[username]

  hashed_password = BCrypt::Password.new(credentials[username])
  hashed_password == password
end

def load_user_credentials
  credentials_path = ENV["RACK_ENV"] == "test" ? CREDENTIALS_TEST : CREDENTIALS

  YAML.load_file(File.expand_path(credentials_path, __FILE__))
end

def require_logged_in_user
  unless user_logged_in?
    session[:error] = ERROR_USER_NOT_LOGGED_IN
    redirect '/'
  end
end

def user_logged_in?
  session[:logged_in]
end

def require_valid_reference(file_name, file_path)
  unless File.exist? file_path
    session[:error] = "#{file_name}#{ERROR_FILE_NOT_FOUND}"
    redirect '/'
  end
end

def check_validity(file_name)
  if !valid_name? file_name then :invalid
  elsif !unique_name? file_name then :existing
  else
    :valid
  end
end

def valid_name?(file_name)
  file_name.match?(/\w+.txt/) || file_name.match?(/\w+.md/)
end

def unique_name?(file_name)
  !Dir[File.join(data_path, '*')].map { |file_path| File.basename(file_path) }.include? file_name
end
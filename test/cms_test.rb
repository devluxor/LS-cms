require 'minitest/autorun'
require 'rack/test'
require 'securerandom'
require 'fileutils'

require_relative '../cms'
require_relative '../messages'

ENV['RACK_ENV'] = 'test'

RANDOM_TEST_FILE_NAME = SecureRandom.hex(10)
RANDOM_TEST_FILE_CONTENT = SecureRandom.hex(10)
RANDOM_TEST_FILE_NEW_CONTENT = SecureRandom.hex(10)

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def create_test_file(name, content = "")
    File.open(File.join(data_path, name), "w") { |file| file.write(content) }
  end
  
  def setup
    FileUtils.mkdir_p(data_path)    
    create_test_file("#{RANDOM_TEST_FILE_NAME}.txt", RANDOM_TEST_FILE_CONTENT)
    @test_file_path = "#{data_path}/#{RANDOM_TEST_FILE_NAME}.txt"

    post "/users/signin", username: DEFAULT_USER, password: DEFAULT_PASSWORD
  end

  def teardown
    FileUtils.rm_rf(data_path)
    post "/users/signin", username: DEFAULT_USER, password: DEFAULT_PASSWORD
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
  end

  def test_file_found
    file_path = Dir[File.join(data_path, '*')].first
    file_name = File.basename file_path

    get "/#{file_name}"
    file_content_by_word = File.read(file_path).split(' ')
    response_body = last_response.body
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert file_content_by_word.all? { |word| response_body.include? word }
  end

  def test_file_not_found
    inexistent_file = "#{SecureRandom.hex(5)}.#{SecureRandom.hex(5)}"

    get "/#{inexistent_file}"
    assert_equal 302, last_response.status

    assert_equal "#{inexistent_file} couldn't be found.", session[:error]
  end

  def test_file_editable
    file_name = File.basename(@test_file_path)

    get "/#{file_name}/edit"
    assert_equal 200, last_response.status
    assert_equal RANDOM_TEST_FILE_CONTENT, File.read(@test_file_path).strip

    post "/#{file_name}/edit", file_content: RANDOM_TEST_FILE_NEW_CONTENT
    assert_equal 302, last_response.status
    assert_equal "#{file_name} has been updated.", session[:success]
    
    get "/#{file_name}"
    assert_includes last_response.body, RANDOM_TEST_FILE_NEW_CONTENT
    assert_equal RANDOM_TEST_FILE_NEW_CONTENT, File.read(@test_file_path).strip
  end

  def test_new_document_input
    get '/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_file_created
    file_name = "#{SecureRandom.hex(10)}.txt"
    post '/new', document_name: file_name
    assert_equal 302, last_response.status
    assert_equal "#{file_name} has been created.", session[:success]

    get '/'
    assert_includes last_response.body, file_name
  end

  def test_new_document_invalid_name
    post '/new', document_name: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A valid name is required.'
  end

  def test_file_deleted
    file_name = "#{RANDOM_TEST_FILE_NAME}.txt"
    post '/new', document_name: file_name

    post "#{file_name}/delete"
    assert_equal 302, last_response.status
    assert_equal "#{file_name} has been deleted.", session[:success]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<input type=\"submit\""
  end

  def test_signin
    post "/users/signin", username: DEFAULT_USER, password: DEFAULT_PASSWORD
    assert_equal 302, last_response.status

    assert_equal SUCCESS_USER_SIGNED_IN, session[:success]
    assert_equal DEFAULT_USER, session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as #{DEFAULT_USER}"
  end

  def test_signin_with_bad_credentials
    post "/users/signout"

    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:logged_in]
    assert_includes last_response.body, ERROR_INVALID_CREDENTIALS
  end

  def test_signout
    post "/users/signout"
    assert_equal "You have been signed out.", session[:success]

    get last_response["Location"]
    assert_nil session[:username]
    refute session[:logged_in]
    assert_includes session["success"], SUCCESS_USER_SIGNED_OUT
  end
end
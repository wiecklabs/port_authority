require "pathname"
require Pathname(__FILE__).dirname.parent + "test_helper"

class SessionControllerTest < Test::Unit::TestCase
  
  include Harbor::Test

  USER_EMAIL = "sample@example.com"
  USER_PASSWORD = "example"
  SOME_RANDOM_AUTHKEY = "A-RANDOM-AUTH-KEY"

  def setup
    User.auto_migrate!
    @user = User.create!(:email => USER_EMAIL, :password => USER_PASSWORD, :password_confirmation => USER_PASSWORD)
    
    logger = Logging.logger((Pathname(__FILE__).dirname.parent.parent + "log" + "app.log").to_s)
    logger.level = ENV["LOG_LEVEL"] || :debug
    logger.clear_appenders
    PortAuthority::logger = logger
    
    @services = Harbor::Container.new
    @services.register "logger", logger
    @services.register "request", Harbor::Test::Request
    @services.register "response", Harbor::Test::Response
    @services.register "mailer", Harbor::Test::Mailer
    @services.register "session", {}    
    @services.register PortAuthority::Session, PortAuthority::Session
    @session_controller = @services.get(PortAuthority::Session)
  end

  def test_successful_login_without_remember_me_clears_auth_key
    @session_controller.request.cookies[PortAuthority.auth_key_cookie_name] = SOME_RANDOM_AUTHKEY
    @session_controller.create(USER_EMAIL, USER_PASSWORD, nil)

    assert_cookie_deleted(@session_controller.response, PortAuthority.auth_key_cookie_name)
  end

  def test_successful_login_with_remember_me_sets_auth_key
    @session_controller.request.cookies[PortAuthority.auth_key_cookie_name] = SOME_RANDOM_AUTHKEY
    @session_controller.create(USER_EMAIL, USER_PASSWORD, true)

    assert_cookie_set(@session_controller.response, PortAuthority.auth_key_cookie_name, @user.auth_key)
  end

end
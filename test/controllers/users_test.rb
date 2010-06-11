require "pathname"
require Pathname(__FILE__).dirname.parent + "test_helper"

class UserControllerTest < Test::Unit::TestCase

  include Harbor::Test

  USER_EMAIL = "sample@example.com"
  USER_PASSWORD = "example"
  SOME_RANDOM_AUTHKEY = "A-RANDOM-AUTH-KEY"

  def setup
    User.auto_migrate!
    @user = User.create!(:email => USER_EMAIL, :password => USER_PASSWORD, :password_confirmation => USER_PASSWORD)
    
    # PermissionSet::permissions.each do |name, permissions|
    #   permission_set = RolePermissionSet.new(:role => role, :name => name)
    #   permission_set.add *permissions
    #   permission_set.save
    #   permission_set.propagate_permissions!
    # end

    @services = Harbor::Container.new
    @services.register "request", Harbor::Test::Request
    @services.register "response", Harbor::Test::Response
    @services.register "mailer", Harbor::Test::Mailer
    @services.register "session", {}
    @services.register PortAuthority::Users, PortAuthority::Users
    @users_controller = @services.get(PortAuthority::Users)
  end
  
  def test_successful_batch_export
  end
  
  def test_successful_user_export
  end
end
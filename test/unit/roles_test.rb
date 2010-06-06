require File.expand_path(File.dirname(File.dirname(__FILE__))) + "/test_helper"

class RoleTest < Test::Unit::TestCase
  
  def setup
    User.auto_migrate!
    User.all.destroy!
    
    Role.auto_migrate!
    Role.all.destroy!
    
    RoleUser.auto_migrate!
    RoleUser.all.destroy!
    
    UserPermissionSet.auto_migrate!
    UserPermissionSet.all.destroy!
    
    RolePermissionSet.auto_migrate!
    RolePermissionSet.all.destroy!
    
    @guest_role = Role.create(:name => 'Guest')
    PortAuthority.guest_role = @guest_role

    user_role = Role.create(:name => PortAuthority::default_user_role)
    
    @user = User.create!(:email => 'sample@example.com', :password => 'example', :password_confirmation => 'example', :roles => [user_role, @guest_role])
  end
  
  def test_deleting_roles_deletes_role_users
    role_id = @guest_role.id
    @guest_role.destroy
    
    assert_equal(nil, RoleUser.first(:user_id => @user.id, :role_id => role_id))
  end
  
end
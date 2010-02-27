require File.expand_path(File.dirname(File.dirname(__FILE__))) + "/test_helper"

class SessionPermissionsTest < Test::Unit::TestCase
  
  class Session < Harbor::Test::Session
    
    attr_accessor :permissions_loaded, :permissions_loaded_from_guest_role, :permissions_loaded_from_user
    
    private
    
    alias original_load_permissions load_permissions
    def load_permissions
      @permissions_loaded = true
      original_load_permissions
    end

    alias original_load_permissions_from_guest_role load_permissions_from_guest_role
    def load_permissions_from_guest_role
      @permissions_loaded_from_guest_role = true
      original_load_permissions_from_guest_role
    end

    alias original_load_permissions_from_user load_permissions_from_user
    def load_permissions_from_user
      @permissions_loaded_from_user = true
      original_load_permissions_from_user
    end
    
  end
  
  PermissionSet.permissions.merge!({
    "Photos" => ["list", "show", "update", "create"],
    "Money" => ["print"]
  })
  
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

    guest_photos = @guest_role.permission_sets.create(:role_id => @guest_role.id, :name => "Photos")
    guest_photos.update_mask("list" => 1, "show" => 1, "update" => 0, "create" => 0)
    guest_photos.save
    
    user_photos = user_role.permission_sets.create(:role_id => user_role.id, :name => "Photos")
    user_photos.update_mask("list" => 1, "show" => 1, "update" => 1, "create" => 1)
    user_photos.save
    
    @user = User.create!(:email => 'sample@example.com', :password => 'example', :password_confirmation => 'example', :roles => [user_role])
    user_photos.propagate_permissions!
  end
  
  def test_guest_permissions_without_cache
    guest_session = Session.new({:user_id => nil})
    assert_equal(3, guest_session.permissions['Photos'].mask)
    assert_equal(0, guest_session.permissions['Money'].mask)
    assert(guest_session['permissions'] =~ /Guest\[#{Regexp.escape(@guest_role.updated_at.to_s)}\]\:.*?Photos=3/)
  end
  
  def test_guest_authorized_without_cache
    guest_session = Session.new({:user_id => nil})
    
    assert(guest_session.authorized?("Photos", "list"))
    assert(guest_session.authorized?("Photos", "show"))
    assert(!guest_session.authorized?("Photos", "update"))
    assert(!guest_session.authorized?("Photos", "create"))
  end
  
  def test_guest_permissions_with_stale_cache
    permissions = serialize_permissions('Guest', DateTime.now - 1, 'Photos' => 3, 'Money' => 0)

    guest_session = Session.new({:user_id => nil, 'permissions' => permissions})
    assert_equal(3, guest_session.permissions['Photos'].mask)
    assert(guest_session.permissions_loaded)
    assert(guest_session.permissions_loaded_from_guest_role)
    assert_equal(0, guest_session.permissions['Money'].mask)
  end

  def test_guest_permissions_with_user_cache
    permissions = serialize_permissions('User', DateTime.now + 1, 'Photos' => 3, 'Money' => 0)

    guest_session = Session.new({:user_id => nil, 'permissions' => permissions})
    assert_equal(3, guest_session.permissions['Photos'].mask)
    assert(guest_session.permissions_loaded)
    assert(guest_session.permissions_loaded_from_guest_role)
    assert_equal(0, guest_session.permissions['Money'].mask)
  end

  def test_guest_permissions_with_fresh_cache
    permissions = serialize_permissions('Guest', @guest_role.updated_at + 1, 'Photos=3;Money=0')

    guest_session = Session.new({:user_id => nil, 'permissions' => permissions})
    assert_equal(3, guest_session.permissions['Photos'].mask)
    assert(guest_session.permissions_loaded)
    assert(!guest_session.permissions_loaded_from_guest_role)
    assert_equal(0, guest_session.permissions['Money'].mask)
  end
  
  def test_user_permissions_without_cache
    user_session = Session.new({:user_id => @user.id})
    assert_equal(nil, user_session['permissions'])
    assert_equal(15, user_session.permissions['Photos'].mask)
    assert_equal(0, user_session.permissions['Money'].mask)
    assert(user_session['permissions'] =~ /User\[#{Regexp.escape(@user.updated_at.to_s)}\]\:.*?Photos=15/)
  end
  
  def test_user_authorized_without_cache
    guest_session = Session.new({:user_id => @user.id})
    
    assert(guest_session.authorized?("Photos", "list"))
    assert(guest_session.authorized?("Photos", "show"))
    assert(guest_session.authorized?("Photos", "update"))
    assert(guest_session.authorized?("Photos", "create"))
  end
  
  def test_user_permissions_with_stale_cache
    permissions = serialize_permissions('User', DateTime.now - 1, 'Photos=15;Money=0')

    user_session = Session.new({:user_id => @user.id, 'permissions' => permissions})
    assert_equal(15, user_session.permissions['Photos'].mask)
    assert(user_session.permissions_loaded)
    assert(user_session.permissions_loaded_from_user)
    assert_equal(0, user_session.permissions['Money'].mask)
  end

  def test_user_permissions_with_guest_cache
    permissions = serialize_permissions('Guest', DateTime.now + 1, 'Photos=15;Money=0')
  
    user_session = Session.new({:user_id => @user.id, 'permissions' => permissions})
    assert_equal(15, user_session.permissions['Photos'].mask)
    assert(user_session.permissions_loaded)
    assert(user_session.permissions_loaded_from_user)
    assert_equal(0, user_session.permissions['Money'].mask)
  end

  def test_user_permissions_with_fresh_cache
    permissions = serialize_permissions('User', @user.updated_at + 1, 'Photos=15;Money=0')
  
    user_session = Session.new({:user_id => @user.id, 'permissions' => permissions})
    assert_equal(15, user_session.permissions['Photos'].mask)
    assert(user_session.permissions_loaded)
    assert(!user_session.permissions_loaded_from_user)
    assert_equal(0, user_session.permissions['Money'].mask)
  end
  
  private
  
  def serialize_permissions(type, date_time, mask_string)
    "#{type}[#{date_time}]:#{mask_string}"
  end
  
end
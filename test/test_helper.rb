require "rubygems"
require "pathname"
require "test/unit"
require (Pathname(__FILE__).dirname.parent + "lib/port_authority").expand_path
require "harbor/test/test"

ENV['ENVIRONMENT'] = "test"
DataMapper.setup :default, "postgres://#{ENV["USER"]}@127.0.0.1/port_authority_test"

module TestHelper
  include Harbor::Test

  def initialize_test_environment
    @app_log = StringIO.new
    $services.get("logger").clear_appenders
    $services.get("logger").add_appenders Logging::Appenders::IO.new('app', @app_log)    
    @request_log = StringIO.new
    Logging::Logger['request'].clear_appenders
    Logging::Logger['request'].add_appenders Logging::Appenders::IO.new('request', @request_log)
    @error_log = StringIO.new
    Logging::Logger['error'].clear_appenders
    Logging::Logger['error'].add_appenders Logging::Appenders::IO.new('error', @error_log)
    
    @guest_role = create_role('Guest')
    @user_role = create_role('User')
    @user = create_user("user@wieck.com", "User", "Wieck", @user_role)
    permit_all_for_role(@user_role)
  end

  def destroy_test_environment
    Role.all.destroy!
    RolePermissionSet.all.destroy!
    User.all.destroy!
    UserPermissionSet.all.destroy!
  end

  def create_role(name, description = '')
    Role.create!(:name => name, :description => description)
  end
  
  def permit_all_for_role(role)
    PermissionSet::permissions.each do |name, permissions|
      permission_set = RolePermissionSet.new(:role => role, :name => name)
      permission_set.add *permissions
      permission_set.save
      permission_set.propagate_permissions!
    end
  end

  def create_user(email, first_name, last_name, role = nil, attributes = {})
    user_attributes = attributes.update({
      :email => email,
      :password => 'test',
      :first_name => first_name,
      :last_name => last_name,
      :active => true
    })

    attributes[:login] = email if PortAuthority.use_logins?
    attributes[:roles] = [role] if role
    User.create!(attributes)
  end
end

class Test::Unit::TestCase
  include TestHelper
  
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    defined = instance_method(test_name) rescue false
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        flunk "No implementation provided for #{name}"
      end
    end
  end
end

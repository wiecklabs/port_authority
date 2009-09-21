# configuration options:
#
# Enable "login" field for users instead of using email
# address to login.
#   PortAuthority.use_login!
#
# Enable encrypted passwords:
#   PortAuthority.use_crypted_passwords!
#
# To enable lockouts after N failed logins:
#   PortAuthority.use_lockouts!
#
# To adjust number of attempts before lockout:
#   PortAuthority::lockout_attempts = 5 # default is 3
#
# CSV Export fields can be adjusted by altering User::CSV_IGNORE
#   User::CSV_IGNORE.delete(:password) # to include passwords in the export
#

require "pathname"
require "rubygems"

gem "fastercsv"
require "fastercsv"

gem "json"
require "json"

gem "harbor", ">= 0.12.8"
require "harbor"
require "harbor/mailer"

gem "ui", ">= 0.6.1"
require "ui"

gem "dm-core"
require "dm-core"

gem "dm-is-searchable"
require "dm-is-searchable"

gem "dm-validations"
require "dm-validations"

gem "dm-timestamps"
require "dm-timestamps"

gem "dm-aggregates"
require "dm-aggregates"

gem "dm-types"
require "dm-types"

gem "tmail"
require "tmail/address"

require Pathname(__FILE__).dirname + "port_authority" + "application"

Harbor::View::path.unshift(Pathname(__FILE__).dirname + "port_authority" + "views")
Harbor::View.layouts.map("admin/*", "layouts/admin")
Harbor::View.layouts.map("account/new", "layouts/login")
Harbor::View.layouts.map("session/unauthorized", "layouts/exception")
Harbor::View.layouts.map("*", "layouts/application")

class PortAuthority

  autoload :Config, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "config").to_s
  autoload :Admin, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "admin").to_s
  autoload :Roles, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "roles").to_s
  autoload :Session, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "session").to_s
  autoload :Users, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "users").to_s
  autoload :Account, (Pathname(__FILE__).dirname + "port_authority" + "controllers" + "account").to_s

  class ConfigurationError < StandardError
  end

  @@is_searchable = false
  def self.is_searchable!
    @@is_searchable = true
    Account.is_searchable! if Account.respond_to?(:is_searchable!)
    Role.is_searchable!
    User.is_searchable!
  end
  
  def self.is_searchable?
    @@is_searchable
  end

  @@default_user_sort = [:email.asc]
  def self.default_user_sort
    @@default_user_sort
  end
  
  def self.default_user_sort=(value)
    @@default_user_sort = value
  end

  @@public_path = Pathname(__FILE__).dirname.parent + "public"
  def self.public_path
    @@public_path
  end
  
  def self.public_path=(value)
    @@public_path = value
  end

  def self.private_path
    Pathname(@@private_path)
  rescue NameError
    raise(ConfigurationError.new("PortAuthority::private_path not set"))
  end

  def self.private_path=(value)
    @@private_path = value
  end

  def self.asset_path
    Pathname(__FILE__).dirname.parent + "assets"
  end

  # Used to enable/disable site-generated emails which would go to end users,
  # say, while in production but pre-launch.
  @@send_notifications = true
  def self.send_notifications=(val)
    @@send_notifications = val
  end

  def self.send_notifications?
    @@send_notifications
  end

  @@default_user_role = "User"
  def self.default_user_role=(value)
    @@default_user_role = value
  end

  def self.default_user_role
    @@default_user_role
  end

  def self.login_type
    PortAuthority::use_logins? ? :login : :email
  end

  @@use_logins = false
  def self.use_logins!
    User.use_logins!
    @@use_logins = true
    @@login_failed_message = "Bad #{PortAuthority::login_type} or password"
    @@use_logins
  end

  def self.use_logins?
    @@use_logins
  end

  @@redirect_failed_logins_to_referrer = false
  def self.redirect_failed_logins_to_referrer!
    @@redirect_failed_logins_to_referrer = true
  end

  def self.redirect_failed_logins_to_referrer?
    @@redirect_failed_logins_to_referrer
  end

  @@activation_email_subject = "Please verify your email address"
  def self.activation_email_subject=(value)
    @@activation_email_subject = value
  end

  def self.activation_email_subject
    @@activation_email_subject
  end

  @@account_activated_email_subject = "A user has activated their account"
  def self.account_activated_email_subject=(value)
    @@account_activated_email_subject = value
  end

  def self.account_activated_email_subject
    @@account_activated_email_subject
  end

  @@user_approved_email_subject = "An admin has approved your account"
  def self.user_approved_email_subject=(value)
    @@user_approved_email_subject = value
  end

  def self.user_approved_email_subject
    @@user_approved_email_subject
  end

  @@user_denied_email_subject = "An admin has denied your account"
  def self.user_denied_email_subject=(value)
    @@user_denied_email_subject = value
  end

  def self.user_denied_email_subject
    @@user_denied_email_subject
  end

  @@password_reset_email_subject = "An admin has reset your password"
  def self.password_reset_email_subject=(value)
    @@password_reset_email_subject = value
  end

  def self.password_reset_email_subject
    @@password_reset_email_subject
  end

  @@forgot_password_email_subject = "Your new password"
  def self.forgot_password_email_subject=(value)
    @@forgot_password_email_subject = value
  end

  def self.forgot_password_email_subject
    @@forgot_password_email_subject
  end

  @@login_failed_message = "Bad #{PortAuthority::login_type} or password"
  def self.login_failed_message=(value)
    @@login_failed_message = value
  end

  def self.login_failed_message
    @@login_failed_message
  end

  @@use_crypted_passwords = false
  def self.use_crypted_passwords!
    User.use_crypted_passwords!
    @@use_crypted_passwords = true
  end

  def self.use_crypted_passwords?
    @@use_crypted_passwords
  end

  @@allow_blank_passwords = false
  def self.allow_blank_passwords!
    @@allow_blank_passwords = true
  end

  def self.allow_blank_passwords?
    @@allow_blank_passwords
  end

  @@use_lockouts = false
  def self.use_lockouts!
    User.use_lockouts!
    @@use_lockouts = true
  end

  def self.use_lockouts?
    @@use_lockouts
  end

  @@lockout_attempts = 3
  def self.lockout_attempts=(value)
    @@lockout_attempts = value
  end

  def self.lockout_attempts
    @@lockout_attempts
  end

  @@use_approvals = false
  def self.use_approvals!
    User.use_approvals!
    Users.use_approvals!
    @@use_approvals = true
  end

  def self.use_approvals?
    @@use_approvals
  end

  @@no_reply_email_address = "do-not-reply@example.com"
  def self.no_reply_email_address
    @@no_reply_email_address
  end
  
  def self.no_reply_email_address=(value)
    @@no_reply_email_address = value
  end

  def self.admin_email_addresses
    begin
      @@admin_email_addresses
    rescue NameError
      @@admin_email_addresses = ["#{ENV["USER"]}@#{`hostname`.chomp}"]
      warn "PortAuthority::admin_email_addresses not set, defaulting to #{@@admin_email_addresses.inspect}"
      retry
    end
  end

  def self.admin_email_addresses=(value)
    @@admin_email_addresses = value
  end

  @@guest_role = nil
  def self.guest_role
    @@guest_role ||= Role.first(:name.like => '%guest%') or Role.first(:name.like => '%Guest%') 
  end

  def self.guest_role=(value)
    @@guest_role = value
  end
  
  @@ftp_hostname = "localhost"
  def self.ftp_hostname
    @@ftp_hostname
  end
  
  def self.ftp_hostname=(value)
    @@ftp_hostname = value
  end
  
  @@allow_forgot_password = true
  def self.allow_forgot_password?
    @@allow_forgot_password
  end
  
  def self.allow_forgot_password=(value)
    @@allow_forgot_password = value
  end
  
  # Allow multiple roles
  # Determines if a user can belong to more than one role
  # Eventually, this will likely be false by default
  @@allow_multiple_roles = true
  def self.allow_multiple_roles?
    @@allow_multiple_roles
  end
  
  def self.allow_multiple_roles=(value)
    @@allow_multiple_roles = value
  end
  
  # Allow user specific permissions
  # Determines if a user can have custom permission set (outside those defined by their role(s))
  # Eventually, this will likely be false by default
  @@allow_user_specific_permissions = true
  def self.allow_user_specific_permissions?
    @@allow_user_specific_permissions
  end
  
  def self.allow_user_specific_permissions=(value)
    @@allow_user_specific_permissions = value
  end

  @@allow_signup = true
  def self.allow_signup?
    @@allow_signup
  end
  
  def self.allow_signup=(value)
    @@allow_signup = value
  end

  def self.refresh_user_permissions(role_name)
    role = Role.first(:name => role_name)

    role.users.each do |user|
      user.permission_sets.destroy!
      role.permission_sets.each { |set| set.propagate_permissions! }
    end
  end

  def self.refresh_admin_permissions!
    admin = Role.first(:name => "Admin")
    admin.permission_sets.destroy!

    PermissionSet::permissions.each do |name, permissions|
      role = RolePermissionSet.new(:role => admin_role, :name => name)
      role.add *permissions
      role.save
      role.propagate_permissions!
    end

    admin.users.each do |user|
      user.permission_sets.destroy!
      role.permission_sets.each { |set| set.propagate_permissions! }
    end
  end

  def call(env)
    repository(:default) do
      super(env)
    end
  end
end

require Pathname(__FILE__).dirname + "port_authority" + "authentication"
require Pathname(__FILE__).dirname + "port_authority" + "authorization"
require Pathname(__FILE__).dirname + "port_authority" + "vcard"

require Pathname(__FILE__).dirname + "port_authority" + "models" + "permission_set"
require Pathname(__FILE__).dirname + "port_authority" + "models" + "user"
require Pathname(__FILE__).dirname + "port_authority" + "models" + "user" + "search"
require Pathname(__FILE__).dirname + "port_authority" + "models" + "role"

UI::Asset::register("stylesheets/port_authority.css", PortAuthority::asset_path + "stylesheets/port_authority.css")
UI::Asset.register("images/check.png", PortAuthority.asset_path + "images/check.png")
UI::Asset.register("images/delete.png", PortAuthority.asset_path + "images/delete.png")
UI::Asset.register("images/vcard.png", PortAuthority.asset_path + "images/vcard.png")
UI::Asset.register("images/delete.gif", PortAuthority.asset_path + "images/delete.gif")
UI::Asset.register("images/transparent.gif", PortAuthority.asset_path + "images/transparent.gif")

PermissionSet::permissions["Admin"] = [
  "index",
  "config"
]

PermissionSet::permissions["Users"] = [
  "create: Create a user",
  "show",
  "update",
  "destroy: Delete a user",
  "override: Override validation",
  "list"
]

PermissionSet::permissions["Roles"] = [
  "show",
  "create",
  "update",
  "destroy"
]

class Harbor::Application
  def self.config
    class_variables.sort.map { |var| [var.sub("@@", ""), class_variable_get(var)] }
  end
end

module Harbor
  class Session
    include PortAuthority::Authentication
  end

  class ViewContext
    def me
      @me ||= request.session.user
    end

    def authenticated?
      session.authenticated?
    end

    def authorized?(name, *permissions)
      session.authorized?(name, *permissions)
    end

    private
    def session
      request.session
    end
  end
end

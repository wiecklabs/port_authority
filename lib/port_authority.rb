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

gem "harbor", ">= 0.15.1"
require "harbor"
require "harbor/mailer"
require "harbor/logging"

gem "ui", ">= 0.6.1"
require "ui"

gem "dm-core", "= 0.9.11"
require "dm-core"

gem "dm-is-searchable", "= 0.9.11"
require "dm-is-searchable"

gem "dm-validations", "= 0.9.11"
require "dm-validations"

gem "dm-timestamps", "= 0.9.11"
require "dm-timestamps"

gem "dm-aggregates", "= 0.9.11"
require "dm-aggregates"

gem "dm-types", "= 0.9.11"
require "dm-types"

gem "tmail"
require "tmail/address"

gem "sanitize"
require "sanitize"

Harbor::View::path.unshift(Pathname(__FILE__).dirname + "port_authority" + "views")
Harbor::View.layouts.map("admin/*", "layouts/admin")
Harbor::View.layouts.map("account/new", "layouts/login")
Harbor::View.layouts.map("account/forgot_password", "layouts/login")
Harbor::View.layouts.map("session/index", "layouts/login")
Harbor::View.layouts.map("session/unauthorized", "layouts/exception")
Harbor::View.layouts.map("*", "layouts/application")

class PortAuthority < Harbor::Application

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

  @@logger = nil
  def self.logger
    @@logger
  end
  
  def self.logger=(value)
    @@logger = value
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

  @@account_activated_email_subject = "A guest has just registered for an account."
  def self.account_activated_email_subject=(value)
    @@account_activated_email_subject = value
  end

  def self.account_activated_email_subject
    @@account_activated_email_subject
  end

  @@user_approved_email_subject = "Your account has been approved"
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

  @@forgot_password_email_subject = "Lost Password Recovery Request"
  def self.forgot_password_email_subject=(value)
    @@forgot_password_email_subject = value
  end

  def self.forgot_password_email_subject
    @@forgot_password_email_subject
  end

  @@password_reset_email_subject = "An admin has reset your password"
  def self.password_reset_email_subject=(value)
    @@password_reset_email_subject = value
  end

  def self.password_reset_email_subject
    @@password_reset_email_subject
  end
  
  @@force_password_update_message = "Please make the following updates to your profile information before continuing:<ol><li>Please choose a new password and enter it into both the \"Password\" and \"Confirm Password\" fields below.</li><li>Please fill in all required fields, which are indicated by the asterisk(*).</li></ol>When you're finished, click the 'Submit' button to update your profile and return to the site."
  def self.force_password_update_message
    @@force_password_update_message
  end
  
  def self.force_password_update_message=(message)
    @@force_password_update_message = message
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
  
  @@denial_emails_enabled = false
  def self.denial_emails_enabled?
    @@denial_emails_enabled
  end
  
  def self.enable_denial_emails!
    @@denial_emails_enabled = true
    PortAuthority::Users.register_event(:user_denied) do |user, request|
      mailer = Mailer.new
      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::user_denied_email_subject
      mailer.html = Harbor::View.new("mailers/denial.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/denial.txt.erb", :user => user)

      mail_server = $services.get("mail_server")
      mail_server.deliver(mailer)
    end
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

  def self.fake!
    gem "faker"
    require "faker"

    admin_role = Role.create!(:name => "Admin", :description => "Site administrators")
    user_role  = Role.create!(:name => "User", :description => "General users")
    guest_role = Role.create!(:name => "Guest", :description => "Guests")

    admin_user = {
      :first_name => "Admin",
      :last_name => "Admin",
      :email => "admin@example.com",
      :password => "test",
      :active => true,
      :roles => [admin_role]
    }

    admin_user[:login] = "admin" if PortAuthority::use_logins?

    User.create!(admin_user)
    puts "Created an admin user. Login with '#{PortAuthority::use_logins? ? admin_user[:login] : admin_user[:email]}' and '#{admin_user[:password]}' "

    PermissionSet::permissions.each do |name, permissions|
      role = RolePermissionSet.new(:role => admin_role, :name => name)
      role.add *permissions
      role.save
      role.propagate_permissions!
    end

    if !ENV["ENVIRONMENT"] || ENV["ENVIRONMENT"] == "development"
      10.times do |i|
        user = {
          :first_name => Faker::Name::first_name,
          :last_name  => Faker::Name::last_name,
          :email      => Faker::Internet::email,
          :organization => Faker::Company::name,
          :password => "test",
          :active => true
        }

        user[:login] = "#{user[:first_name].downcase}#{rand(5)}" if PortAuthority::use_logins?

        User.create!(user)
      end
    end
    puts "#{User.count} created."
  end

  
  def self.routes(services = self.services)
    raise ArgumentError.new("+services+ must be a Harbor::Container") unless services.is_a?(Harbor::Container)

    Harbor::Router.new do
      using services, PortAuthority::Admin do
        get("/admin") { |admin| admin.index }
      end

      # Session Routes
      using services, PortAuthority::Session do
        get("/login")           { |session, params| session.index(params["message"]) }
        get("/session")         { |session, params| session.index(params["message"]) }
        post("/session")        { |session, params| session.create(params["login"], params["password"]) }
        get("/session/delete")  { |session| session.delete }
        get("/logout")          { |session| session.delete }
      end

      # User Routes
      using services, PortAuthority::Users do
        get("/admin/users/random_password") { |users| users.random_password }

        get("/admin/users") do |users, params|
          options = { :active => true }
          options.merge!(:denied_at => nil, :awaiting_approval => false) if PortAuthority::use_approvals?

          users.index(params.fetch("page", 1), params.fetch("page_size", 100), options, params["query"])
        end

        get("/admin/users/inactive") do |users, params|
          options = { :active => false }
          options.merge!(:denied_at => nil, :awaiting_approval => false) if PortAuthority::use_approvals?

          users.index(params.fetch("page", 1), params.fetch("page_size", 100), options, params["query"])
        end

        if PortAuthority::use_approvals?
          get("/admin/users/awaiting") do |users, params|
            options = {
              :conditions => ["(denied_at IS ? AND (awaiting_approval = ? AND activated_at IS NOT ?))", nil, true, nil]
            }
            users.index(params.fetch("page", 1), params.fetch("page_size", 100), options, params["query"])
          end

          get("/admin/users/pending") do |users, request|
            options = {
              :conditions => ["(denied_at IS ? AND (awaiting_approval = ? AND activated_at IS ?))", nil, true, nil]
            }
            users.index(request.fetch("page", 1), request.fetch("page_size", 100), options, request["query"])
          end

          get("/admin/users/denied") do |users, request|
            options = {
              :conditions => ["denied_at IS NOT ?", nil]
            }
            users.index(request.fetch("page", 1), request.fetch("page_size", 100), options, request["query"])
          end
        end

        get("/admin/users/new")      { |users, params| users.new(params["user"]) }
        
        get("/admin/roles/:role_id/users") { |users, params| users.index(params.fetch("page", 1), params.fetch("page_size", 100), {:role_id => params['role_id'].to_i}, params["query"]) }

        get("/admin/users/:id")         { |users, params| users.show(params["id"]) }
        get("/admin/users/:id/edit")    { |users, params| users.edit(params["id"]) }
        get("/admin/users/:id/delete")  { |users, params| users.delete(params["id"]) }
        post("/admin/users")            { |users, params| users.create(params["user"], params["override"]) }
        put("/admin/users/:id")         { |users, params| users.update(params["id"], params["user"], params["override"]) }
        delete("/admin/users/:id")      { |users, params| users.delete(params["id"]) }

        get("/admin/users.:format")      { |users, params| users.export(params["format"]) }
        get("/admin/users/:id.:format")  { |users, params| users.export(params["format"], params["id"]) }

        if PortAuthority::use_approvals?
          get("/admin/users/:id/approve") { |users, params| users.approve(params["id"]) }
          get("/admin/users/:id/deny")    { |users, params| users.deny(params["id"]) }
        end

        get("/admin/users/:id/reset_password")    { |users, params| users.reset_password(params["id"]) }
        get("/users/:id/change_password")   { |users, params| users.response.render("admin/users/change_password", :id => params["id"]) }
        post("/users/:id/change_password")  { |users, params| users.change_password(params["id"], params["user"]) }
      end

      # Role Routes
      using services, PortAuthority::Roles do
        get("/admin/roles")            { |roles, params| roles.index(params["query"]) }
        get("/admin/roles/new")        { |roles, params| roles.new(params["role"]) }
        get("/admin/roles/:id")        { |roles, params| roles.edit(params["id"]) }
        get("/admin/roles/:id/delete") { |roles, params| roles.delete(params["id"]) }

        post("/admin/roles")           { |roles, params| roles.create(params["role"], params["permissions"]) }
        put("/admin/roles/:id")        { |roles, params| roles.update(params["id"], params["role"], params["permissions"]) }
        delete("/admin/roles/:id")     { |roles, params| roles.delete(params["id"]) }
      end

      using services, PortAuthority::Account do
        get("/activate")            { |account, params| account.activate(params["key"]) }

        get("/registration")        { |account, params| account.new({}) }
        get("/account/new")         { |account, params| account.new(params["user"]) }
        get("/account")             { |account| account.edit }
        post("/account")            { |account, params| account.create(params["user"]) }
        put("/account")             { |account, params| account.update(params["user"]) }

        get("/account/password")              { |account| account.forgot_password }
        post("/account/password")             { |account, params| account.forgot_password(params["email"]) }
        get("/account/reset_password/:token") { |account, params| account.reset_password(params["token"]) }
        post("/account/reset_password")       { |account, params| account.reset_password(params["token"], params["user"]) }
        
        get ("/account/update_password") { |account, params| account.force_update_password }
        put ("/account/update_password") { |account, params| account.update_password(params["password"], params["password_confirmation"]) }

        get("/account/vcard")       { |account| account.vcard }
        post("/account/vcard")      { |account, params| account.vcard(params["vcard"]) }
      end

      using services, PortAuthority::Config do
        get(%r{^/\.config$}) { |config| config.index }
      end

      # Default Route
      using services, PortAuthority::Admin do
        get("/") { |admin| admin.index }
      end
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
require Pathname(__FILE__).dirname + "port_authority" + "version"

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
      @me ||= request ? request.session.user : nil
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

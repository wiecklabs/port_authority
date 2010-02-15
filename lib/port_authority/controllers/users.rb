class PortAuthority::Users

  include PortAuthority::Authorization
  include Harbor::Events

  attr_accessor :request, :response, :mailer, :logger

  protect "Users", "list"
  def index(page, page_size, options = {}, query = nil)
    return search(page, page_size, options, query)
  end

  protect "Users", "create"
  def random_password
    response.content_type = "text/plain"
    response.puts User.random_password
  end

  protect "Users", "show"
  def show(id)
    response.render "admin/users/show", :id => id
  end

  protect "Users", "create"
  def new(params)
    user = User.new(params || {})
    unless PortAuthority::allow_multiple_roles?
      # If "allow_multiple_roles" is turned off, a drop down list is rendered to select the role.
      # This sets the default selection to the configured default user role
      user.roles.clear
      user.roles << Role.first(:name => PortAuthority::default_user_role)
    end
    response.render "admin/users/new", :user => user
  end

  protect "Users", "update"
  def edit(id)
    response.render("admin/users/edit", :user => User.get(id))
  end

  protect "Users", "update"
  def update(id, params, override = false)
    user = User.get(id)

    if PortAuthority::allow_multiple_roles?
      roles = request.params["roles"]
    else
      # This is a bit of a hack, but seemed to be the easiest way to support "single-role" selection in the UI
      # Need to build a hash (that looks just like the form's role fields when using "multiple roles")
      # Note that only the selected role will be set to "1"
      roles = Hash.new
      Role.all.each do |role|
        roles[role.id] = 0
      end
      roles[params["role"].to_i] = 1 unless params["role"].empty?
      params.reject! { |k, v| k == "role" }
    end

    # If the password fields are blank, it means they aren't being changed. Use a remove password checkbox to blank them.
    user.attributes = params.reject { |k,v| %w(password password_confirmation role roles).include?(k) && v.blank? }
    user.password, user.password_confirmation = nil if request.params["remove_password"]

    if user.valid? || (override && request.session.authorized?("Users", "override"))
      user.save!

      User.update_roles(user, roles)

      raise_event(:user_updated, user, request)

      raise_event(:user_roles_changed, user, request)

      if PortAuthority::allow_user_specific_permissions?
        update_permissions(user, request.params["permissions"])
      end

      response.message("success", "User successfully updated.")
      response.redirect("/admin/users/#{user.id}/edit")
    else
      # Set the roles on the user so the form will render the previously selected role
      user.roles.clear
      Role.all(:id => roles.keys.select { |id| roles[id] == 1 }).each do |role|
        user.roles << role
      end

      raise_event(:user_save_failed, user, request)

      response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
      response.render "admin/users/edit", :user => user
    end
  end

  protect "Users", "create"
  def create(params, override = false, options = {})
    user = User.new
    raise_event(:start_user_create, user, request, options)

    if PortAuthority::allow_multiple_roles?
      roles = request.params["roles"].clone || Hash.new
    else
      # This is a bit of a hack, but seemed to be the easiest way to support "single-role" selection in the UI
      # Need to build a hash (that looks just like the form's role fields when using "multiple roles")
      # Note that only the selected role will be set to "1"
      roles = Hash.new
      Role.all.each do |role|
        roles[role.id.to_s] = 0
      end
      roles[params["role"].to_s] = 1 unless params["role"].empty?
    end

    # Force the default role on the user if there is one and no roles were selected
    unless PortAuthority::default_user_role.nil?
      if roles.keys.select { |id| roles[id] == 1 }.size == 0
        if role = Role.first(:name => PortAuthority::default_user_role)
          roles[role.id.to_s] = 1
        end
      end
    end
    
    params.reject! { |k,v| %w(role roles).include?(k) }
    user.attributes = params

    user.awaiting_approval = false if PortAuthority::use_approvals?
    user.active = true
    
    if user.valid? || (override && request.session.authorized?("Users", "override"))
      user.save!

      User.update_roles(user, roles)

      if PortAuthority::allow_user_specific_permissions?
        update_permissions(user, request.params["permissions"])
      end

      # If we don't do this after we process the user-specific permission on User Create
      # we end up with a user without any access..
      user.reload

      user.roles.each do |role|
        role.permission_sets.each do |role_permission_set|
          user_set = user.permission_sets.first_or_create(:name => role_permission_set.name, :user_id => user.id)
          user_set.mask = user_set.mask | role_permission_set.mask
          user_set.save!
        end
      end

      user.reload

      raise_event(:user_created, user, request, response, options)
      response.message("success", "User successfully created.")
      response.redirect("/admin/users/#{user.id}/edit")
    else
      # Set the roles on the user so the form will render the previously selected role
      user.roles.clear
      Role.all(:id => roles.keys.select { |id| roles[id] == 1 }).each do |role|
        user.roles << role
      end

      response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
      raise_event(:user_save_failed, user, request, response, options)
      response.render "admin/users/new", :user => user if response.size == 0
    end

  end

  protect "Users", "show"
  def export(format, id = nil)
    users = id ? [User.get(id)] : User.all(:order => [:last_name.asc])
    filename = id ? users.first.to_s.gsub(/[^\w-]/, "_") : "Contacts"

    case format
    when "vcf" then response.content_type = "text/x-vcard"
    when "csv" then response.content_type = "text/csv"
    else
      return response.status = 404
    end

    response.headers["Content-Disposition"] = "attachment; filename=#{filename}.#{format}"

    case format
    when "vcf"
      users.each do |user|
        response.puts Harbor::View.new("admin/users/show.#{format}.erb", :user => user)
        response.puts ""
      end
    when "csv"
      properties = User.properties.map { |p| p.name } - User::CSV_IGNORE
      csv_string = FasterCSV.generate do |csv|
        csv << properties
        users.each do |user|
          csv << User.properties.collect { |p| p.get(user) || "" if properties.include?(p.name) }.compact
        end
      end
      response.puts csv_string
    end
  end

  protect "Users", "destroy"
  def delete(id)
    user = User.get(id)

    case request.request_method
    when "GET"
      context = { :user => user }
      context[:layout] = nil if request.xhr?
      response.render "admin/users/delete", context
    when "DELETE"
      if request.session.user == user
        raise StandardError.new("User<#{user.id}> tried to delete themselves")
      else
        user.permission_sets.each { |set| set.destroy }
        user.destroy
        ##
        # HACK: Until dm-validations is integrated into dm-core, we need
        # this in order to save an invalid record with a Paranoid field.
        # 
        #   user.destroy # => user.deleted_at = Time.now; user.save
        #
        user.save!
        raise_event(:user_deleted, user, request)
      end
      response.message("success", "User successfully deleted.")
      response.redirect("/admin/users")
    end
  end

  protect "Users", "update"
  def reset_password(id)
    user = User.get(id)

    #assigns a human-readable password
    user.password = User.random_password
    user.save!

    mailer.to = user.email
    mailer.from = PortAuthority::no_reply_email_address
    mailer.subject = PortAuthority::password_reset_email_subject
    mailer.text = Harbor::View.new("mailers/reset_password.txt.erb", :user => user)
    mailer.send!

    response.message("success", "A password change notification has been sent to the email registered with this account.")
    response.render("admin/users/edit", :user => user)
  end

  def self.use_approvals!
    protect "Users", "update"
    def approve(id)
      user = User.get(id)
      if user.approve!
        user.reset_permission_set_from_roles # updating permissions
        response.message("success", "Account was successfully approved.")

        mailer.to = user.email
        mailer.from = PortAuthority::no_reply_email_address
        mailer.subject = PortAuthority::user_approved_email_subject
        mailer.html = Harbor::View.new("mailers/approval.html.erb", :user => user)
        mailer.text = Harbor::View.new("mailers/approval.txt.erb", :user => user)
        mailer.send!

        raise_event(:user_created, user, request)
      else
        response.message("error", "Account could not be updated!")
      end
      response.render("admin/users/edit", :user => user.reload)
    end

    protect "Users", "update"
    def deny(id)
      user = User.get(id)
      user.deny!
      raise_event(:user_denied, user, request, mailer)
      response.message("error", "Account Denied for #{user.email}")
      response.redirect("/admin/users/awaiting")
    end
  end

  private

  def search(page, page_size, options, query)
    if role_id_option = options.delete(:role_id)
      options[User.roles.role_id] = role_id_option
    end

    search = User::Search.new(page, page_size, options, query)

    if request.xhr?
      response.render "admin/users/_list", :search => search, :layout => nil
    else
      response.render "admin/users/index", :search => search
    end
  end

  def update_permissions(user, permission_sets)
    return unless permission_sets.respond_to?(:each)

    permission_sets.each do |name, permissions|
      set = user.permission_sets.first_or_create(:name => name, :user_id => user.id)
      set.update_mask(permissions)
      set.save
    end
    true
  end

end

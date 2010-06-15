class PortAuthority::Account

  include PortAuthority::Authorization
  include Harbor::Events

  attr_accessor :request, :response, :mail_server, :logger

  protect
  def edit
    @response.render "account/edit", :user => @request.session.user, :back => referrer
  end

  protect
  def update(params)
    user = @request.session.user
    
    if user.force_password_update?
      @updated_password = false
      if !params["password"].blank? && !params["password_confirmation"].blank?
        if user.respond_to?(:crypted_password)
          @updated_password = true if user.crypted_password != user.encrypt_password(params["password"])
        else
          @updated_password = true if user.password != params["password"]
        end
      end
    end

    clean_params = {}
    params.reject { |k,v| %w(password password_confirmation).include?(k) && v.blank? }.each do |k, v|
      clean_params[k] = HTMLEntities.new.decode(Sanitize.clean(v, Sanitize::Config::RESTRICTED))
    end

    user.attributes = clean_params 

    if user.save
      raise_event(:user_updated, user, request)
      mailer = Harbor::Mailer.new

      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = "Account Updated"
      mailer.text = Harbor::View.new("mailers/account_changed.txt.erb", :user => user)
      mailer.html = Harbor::View.new("mailers/account_changed", :user => user)

      mail_server.deliver(mailer)

      if user.force_password_update?
        if @updated_password
          @request.session[:force_password_update] = false
          user.force_password_update = false
          user.save
          @response.message("error force_password", nil)
          @response.message("success", "Your account was updated successfully.  You are now logged in.")
          return @response.redirect("/")
        end
      else
        @response.message("success", "Your account was updated successfully")
      end

      @response.redirect("/account")
    else
      @response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
      @response.render("account/edit", :user => user)
    end
  end

  protect
  def vcard(upload = nil)
    if upload
      user = @request.session.user
      vcard = Vcard.parse(upload[:tempfile].read).first
      user.attributes = vcard.reject { |k, v| [:email, :country].include?(k) }
      @response.render "account/edit", :user => user
    else
      @response.render "account/vcard", :xhr => @request.xhr?
    end
  end

  def new(user_params)
    return response.render("session/unauthorized") unless PortAuthority::allow_signup?

    user = User.new(user_params || {})

    @response.render "account/new", :user => user
  end

  def create(user_params)
    clean_params = {}

    user_params.each do |k, v|
      clean_params[k] = HTMLEntities.new.decode(Sanitize.clean(v, Sanitize::Config::RESTRICTED))
    end

    user = User.new(clean_params)

    user.active = false

    if user.save(:register)
      raise_event :user_created, user, request
      raise_event :user_updated, user, request
      mailer = Harbor::Mailer.new
      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::activation_email_subject
      mailer.html = Harbor::View.new("mailers/signup_activation.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/signup_activation.txt.erb", :user => user)
  
      mail_server.deliver(mailer)
      message = PortAuthority::account_creation_message % user.email
  
      response.message("success", message)
      response.redirect!("/")
    else
      response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
    end
    
    response.render "account/new", :user => user
  end

  def activate(key)
    user = User.first(:auth_key => key)

    if user
      if PortAuthority::use_approvals? && user.activated_at.blank?
        user.activated_at = DateTime.now
        user.awaiting_approval = true
        user.save
        
        if PortAuthority::use_approvals?
          # hitting this property to make it load so the email will include it when marshalled to the mail queue
          user.usage_statement
        end
        mailers = PortAuthority.admin_email_addresses.collect do |email|
          mailer = Harbor::Mailer.new
          mailer.from = PortAuthority::no_reply_email_address
          mailer.subject = PortAuthority::account_activated_email_subject
          mailer.text = Harbor::View.new("mailers/account_request.txt.erb", :user => user)
          mailer.to = email
          mailer
        end

        mail_server.deliver(mailers)

        @response.message("success", "Your email address has been successfully verified. You will receive a response after an administrator reviews your account.")
      else
        @response.message("success", "Your account is still pending approval. You will receive a response after an administrator reviews your account.")
      end

    else
      @response.message("error",  "No account associated with the provided authentication key could be found.")
    end
    request.session.save
    @response.redirect("/")
  end

  def forgot_password(email_address = nil)
    if email_address.blank?
      @response.render "account/forgot_password", :back => referrer
    else
      user = User.first(:email => email_address)

      # If the user doesn't exist, redirect to /account/password
      if user.nil?
        @response.message("error", "We do not have an account registered for that email.")
        return @response.redirect("/account/password")
      end

      # If the user is inactive and hasn't been approved, let them know.
      unless user.active? || (PortAuthority::use_approvals? && user.approved?)
        message = <<-EOS
        Our records show your account has not been activated yet, an activation email has been
        sent to the email address registered on the account.
        EOS

        @response.message("error", message)
        return @response.redirect("/account/password")
      end

      # Ensure users have a token (Although there is a default value for this, 
      # it was added later and auto_upgrade doesn't do the work for you)
      if user.reset_password_token.blank?
        user.reset_password_token!
        user.save!
      end

      mailer = Harbor::Mailer.new
      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::forgot_password_email_subject
      mailer.html = Harbor::View.new("mailers/forgot_password.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/forgot_password.txt.erb", :user => user)

      mail_server.deliver(mailer)

      message = <<-EOS
      Your request to reset your password has been sent to the email registered with your account.  Please check your email.
      EOS

      @response.message("success", message)
      @response.redirect("/account/password")
    end
  end

  def reset_password(token, password = nil, password_confirmation = nil)
    user = User.first(:reset_password_token => token)

    if token.nil? || user.nil?
      @response.message("error", "Invalid reset password link.")
      return @response.redirect("/account/password")
    end

    user.password = password
    user.password_confirmation = password_confirmation
    user.valid?
    if user.errors[:password]
      @response.message("error", user.errors[:password].join("\n")) if user.password
      @response.render "account/reset_password", :token => token, :user => user
    else
      user.reset_password_token!
      user.save!
      @response.message("success", "Your password has been successfully updated!")
      @response.redirect("/session")
    end
  end

  private

  def referrer
    if @request.params["referrer"]
      @request.params["referrer"]
    elsif @request.referrer =~ /\/account\/?/
      "/admin"
    else
      @request.referrer
    end
  end
end

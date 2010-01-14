class PortAuthority::Account

  include PortAuthority::Authorization

  attr_accessor :request, :response, :mailer, :logger

  protect
  def edit
    @response.render "account/edit", :user => @request.session.user, :back => referrer
  end

  protect
  def update(params)
    user = @request.session.user
    
    user.attributes = params.reject { |k,v| %w(password password_confirmation).include?(k) && v.blank? }

    if user.save
      self.mailer.to = user.email
      self.mailer.from = PortAuthority::no_reply_email_address
      self.mailer.subject = "Account Updated"
      self.mailer.text = Harbor::View.new("mailers/account_changed.txt.erb", :user => user)
      self.mailer.html = Harbor::View.new("mailers/account_changed", :user => user)
      self.mailer.send!

      @response.message("success", "Your account was updated successfully")

      @response.redirect("/account")
    else
      @response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
      @response.render("account/edit", :user => user)
    end
  end
  
  def force_update_password
    @response.render("account/update_password", :user => request.session.user)
  end
  
  def update_password(password, confirmation)
    user = @request.session.user
    
    if user.force_password_update?
      @updated_password = false
      if !password.blank? && !confirmation.blank?
        if user.respond_to?(:crypted_password)
          @updated_password = true if user.crypted_password != user.encrypt_password(password)
        else
          @updated_password = true if user.password != password
        end
      end

      if @updated_password
        unless password == confirmation
         @response.message("error", "Password and Password confirmation must match.")
         return @response.redirect("/account/update_password")
        end 
        user.password = password
        user.password_confirmation= confirmation
        @request.session[:force_password_update] = false
        user.force_password_update = false
        if user.valid?
          user.save
          @response.message("success", "Your account was updated successfully.  You are now logged in.")
          return @response.redirect("/")
        else
          user.save
          @response.message("success", "Your password was updated successfully, however there are errors on your account.  Please review your profile.")
          return @response.redirect("/account")
        end
    
      else
        @response.message("error", "Please update your password and verify your profile information before continuing.")
        @response.render("account/update_password", :user => user)
      end
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
    user = User.new(user_params || {})
    user.active = false

    if user.save(:register)
      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::activation_email_subject
      mailer.html = Harbor::View.new("mailers/signup_activation.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/signup_activation.txt.erb", :user => user)
      mailer.send!
  
      if PortAuthority::use_approvals?
        message = "An activation email has been sent to #{user.email}, your account will not be up for approval until the directions in that email are followed."
      else
        message = "An activation email has been sent to #{user.email}. Follow the directions there to activate your account."
      end
  
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
      if PortAuthority::use_approvals?
        user.awaiting_approval = true

        mailer.from = PortAuthority::no_reply_email_address
        mailer.subject = PortAuthority::account_activated_email_subject
        if PortAuthority::use_approvals?
          # hitting this property to make it load so the email will include it when marshalled to the mail queue
          user.usage_statement
        end
        mailer.text = Harbor::View.new("mailers/account_request.txt.erb", :user => user)
        PortAuthority.admin_email_addresses.each do |email|
          mailer.to = email
          mailer.send!
        end
        message = "Your account has been successfully activated. You will receive an email when an admin approves your account."
      else
        user.active = true
        request.session[:user_id] = user.id
        message = "Your account has been activated and you are now logged in."
      end

      user.save

      @response.message("success", message)

    else
      @response.message("error",  "No account associated with the provided authentication key could be found.")
    end

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
        user.save
      end

      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::forgot_password_email_subject
      mailer.html = Harbor::View.new("mailers/forgot_password.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/forgot_password.txt.erb", :user => user)
      mailer.send!

      message = <<-EOS
      Your request to reset your password has been sent to the email registered with your account.  Please check your email.
      EOS

      @response.message("success", message)
      @response.redirect("/account/password")
    end
  end

  def reset_password(token = nil, user_params = nil)
    user = User.first(:reset_password_token => token)

    if token.nil? || user.nil?
      @response.message("error", "Invalid reset password link.")
      return @response.redirect("/account/password")
    end

    if user_params.blank?
      @response.render "account/reset_password", :token => token, :user => user
    else
      user.update_attributes(user_params)
      user.reset_password_token!

      if user.save
        @response.message("success", "Your password has been successfully updated!")
        @response.redirect("/session")
      else
        @response.errors << UI::ErrorMessages::DataMapperErrors.new(user)
        @response.render "account/reset_password", :token => token, :user => user
      end
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

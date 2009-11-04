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
      @response.render ("account/edit", :user => user)
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
      response.redirect("/")
    else
      response.render "account/new", :user => user
    end
  end

  def activate(key)
    user = User.first(:auth_key => key)

    if user
      if PortAuthority::use_approvals?
        user.awaiting_approval = true

        mailer.from = PortAuthority::no_reply_email_address
        mailer.subject = PortAuthority::account_activated_email_subject
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

      user.password = User.random_password
      user.save!

      mailer.to = user.email
      mailer.from = PortAuthority::no_reply_email_address
      mailer.subject = PortAuthority::forgot_password_email_subject
      mailer.html = Harbor::View.new("mailers/password.html.erb", :user => user)
      mailer.text = Harbor::View.new("mailers/password.txt.erb", :user => user)
      mailer.send!

      message = <<-EOS
      Your password has been sent to the email registered with your account.  Please check your email.
      EOS

      @response.message("success", message)
      @response.redirect("/account/password")
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

class PortAuthority::Session

  include Harbor::Events

  attr_accessor :request, :response, :mailer, :logger

  def index(message)
    @users = User.all(:active => true) if @request.environment == "development"
    @response.message("success", message) if message
    @response.render("session/index", :users => @users, :referrer => referrer)
  end

  def create(login, password, remember_me)
    raise_event(:user_logging_in, :request => request, :response => response)

    if (status = @request.session.authenticate(login, password)).success?

      if remember_me.blank?
        @response.delete_cookie("harbor.auth_key")
      else
        remember_me_cookie = {:value => @request.session.user.auth_key}
        remember_me_cookie[:expires] = Time.now + PortAuthority::remember_me_expires_in if PortAuthority::remember_me_expires_in
        @response.set_cookie("harbor.auth_key", remember_me_cookie)
      end

      raise_event(:user_logged_in, :user => request.session.user, :request => request, :response => response)
      @response.redirect(referrer)
    else
      @users = User.all(:active => true) if @request.environment == "development"
      @request.params["status"] = status

      if PortAuthority::redirect_failed_logins_to_referrer?
        @response.redirect(referrer, :error => status)
      else
        @response.render "session/index", :error => status, :users => @users, :referrer => referrer
      end
    end
  end

  def delete
    raise_event2(:user_logging_out, PortAuthority::Events::UserLoggingOutEvent.new(request.session.user, request, response))

    @request.session.abandon!
    @response.delete_cookie('harbor.auth_key')

    raise_event2(:user_logged_out, PortAuthority::Events::UserLoggedOutEvent.new(request.session.user, request, response))

    @response.redirect("/session")
  end

  private

  def referrer
    if @request.params["referrer"]
      @request.params["referrer"]
    elsif @request.referrer !~ /\/(session|(account\/(password|reset_password)))/
      @request.referrer
    else
       "/"
    end
  end
end

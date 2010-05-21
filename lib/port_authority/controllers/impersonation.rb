class PortAuthority::Impersonation
  include PortAuthority::Authorization

  attr_accessor :request, :response, :mailer, :logger
  
  protect "Impersonation", "activate"
  def activate(user_id)
    user = User.get(user_id)
    response.abort!(404) unless user

    response.set_cookie('harbor.original.session', request.session.save)
    request.cookies.clear

    request.unload_session
    request.session[:user_id] = user.id
    request.session[:impersonating] = true
    request.session[:return_to] = request.referrer
    
    response.redirect "/"
  end

  def deactivate
    response.abort!(404) unless request.session.impersonating?
    return_to = request.session.return_to

    request.unload_session
    response.set_cookie('harbor.session', request.session('harbor.original.session').save)
    response.delete_cookie('harbor.original.session')
    
    response.redirect return_to.blank? ? "/" : return_to
  end

end
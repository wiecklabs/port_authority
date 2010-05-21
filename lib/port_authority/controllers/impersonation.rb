class PortAuthority::Impersonation
  include PortAuthority::Authorization

  attr_accessor :request, :response, :mailer, :logger
  
  protect "Impersonation", "activate"
  def activate(user_id)
    user = User.get(user_id)
    response.abort!(404) unless user

    Harbor::Session.options[:original_key] = Harbor::Session.options[:key]
    Harbor::Session.options[:key] = 'harbor.impersonation.session'

    request.unload_session
    request.session[:user_id] = user.id
    
    response.redirect "/"
  end

  def deactivate
    response.abort!(404) unless Harbor::Session.options[:key] =~ /harbor.impersonation.session/

    request.session.abandon!
    response.delete_cookie('harbor.impersonation.session')

    Harbor::Session.options[:key] = Harbor::Session.options[:original_key]

    request.unload_session
    
    response.redirect "/"
  end

end
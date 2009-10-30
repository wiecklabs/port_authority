class PortAuthority::Config
  include PortAuthority::Authorization

  attr_accessor :request, :response, :logger

  protect "Admin", "config"
  def index
    response.render "admin/config", :layout => nil
  end
end
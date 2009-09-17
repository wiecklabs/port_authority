class PortAuthority::Admin
  include PortAuthority::Authorization

  attr_accessor :request, :response

  protect "Admin", "index"
  def index
    @response.render "admin/index"
  end
end
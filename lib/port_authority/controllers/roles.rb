class PortAuthority::Roles

  include PortAuthority::Authorization

  attr_accessor :request, :response, :logger

  protect "Roles", "show"
  def index(query = nil)
    return search(query) if query
    @response.render("admin/roles/index", :roles => Role.all(:order => [:name.asc]))
  end

  protect "Roles", "create"
  def new(params)
    @response.render("admin/roles/new", :role => Role.new(params || {}))
  end

  protect "Roles", "update"
  def edit(id)
    @response.render("admin/roles/edit", :role => Role.get(id))
  end

  protect "Roles", "update"
  def update(id, params, permissions)
    role = Role.get(id)
    role.update_attributes(params)

    if role.valid? && update_permissions(role, permissions, @request.params["propagate_permissions"])
      @response.message("success", "Role was successfully updated.")
      @response.redirect("/admin/roles")
    else
      @response.render("admin/roles/edit", :role => role)
    end
  end

  protect "Roles", "create"
  def create(params, permissions)
    role = Role.new(params || {})

    if role.save && update_permissions(role, permissions)
      @response.redirect("/admin/roles")
    else
      @response.render("admin/roles/new", :role => role)
    end
  end

  protect "Roles", "destroy"
  def delete(id)
    role = Role.get(id)
    
    if role.name == PortAuthority::default_user_role
      @response.message("error", "Deleting the default role is not permitted.")
      return @response.render("admin/roles/index", :roles => Role.all(:order => [:name.asc]))
    end
    
    case @request.request_method
    when "GET"
      context = { :role => role }
      context[:layout] = nil if @request.xhr?
      @response.render("admin/roles/delete", context)
    when "DELETE"
      role.permission_sets.each { |set| set.destroy }
      role.destroy
      @response.redirect("/admin/roles")
    end
  end

  private

  def search(query)
    if query.blank?
      roles = Role.all(:order => [:name.asc])
    else
      clean = query.split(" ").collect { |q| "+*:#{q}*" }.join(" ")
      results = repository(:search).search("+_type:Role #{clean}")
      roles = Role.all(:id => results[Role], :order => [:name.asc])
    end
    @response.render("admin/roles/_list", :roles => roles, :layout => nil)
  end

  def update_permissions(role, permission_sets, propagate_permissions = false)
    permission_sets.each do |name, permissions|
      set = role.permission_sets.first_or_create(:role_id => role.id, :name => name)
      set.propagate_permissions = propagate_permissions != "0"
      set.update_mask(permissions)
      set.save
    end
    true
  end

end

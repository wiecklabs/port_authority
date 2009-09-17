class PortAuthority < Harbor::Application
  def self.routes(services = self.services)
    raise ArgumentError.new("+services+ must be a Harbor::Container") unless services.is_a?(Harbor::Container)

    Harbor::Router.new do
      using services, PortAuthority::Admin do
        get("/admin") { |admin| admin.index }
      end

      # User Routes
      using services, PortAuthority::Users do
        get("/admin/users/random_password") { |users| users.random_password }

        get("/admin/users")          { |users, params| users.index(params.fetch("page", 1), params.fetch("page_size", 100), {:active => true}, params["query"]) }
        get("/admin/users/inactive") { |users, params| users.index(params.fetch("page", 1), params.fetch("page_size", 100), {:active => false}, params["query"]) }
        get("/admin/users/awaiting") { |users, params| users.index(params.fetch("page", 1), params.fetch("page_size", 100), {:awaiting_approval => true}, params["query"]) }
        get("/admin/users/new")      { |users, params| users.new(params["user"]) }
        
        get("/admin/roles/:role_id/users") { |users, params| users.index(params.fetch("page", 1), params.fetch("page_size", 100), {:role_id => params['role_id'].to_i}, params["query"]) }
      end

      # Session Routes
      using services, PortAuthority::Session do
        get("/session")         { |session, params| session.index(params["message"]) }
        post("/session")        { |session, params| session.create(params["login"], params["password"]) }
        get("/session/delete")  { |session| session.delete }
      end

      using services, PortAuthority::Users do
        get("/admin/users/:id")         { |users, params| users.show(params["id"]) }
        get("/admin/users/:id/edit")    { |users, params| users.edit(params["id"]) }
        get("/admin/users/:id/delete")  { |users, params| users.delete(params["id"]) }
        post("/admin/users")            { |users, params| users.create(params["user"], params["override"]) }
        put("/admin/users/:id")         { |users, params| users.update(params["id"], params["user"], params["override"]) }
        delete("/admin/users/:id")      { |users, params| users.delete(params["id"]) }

        get("/admin/users.:format")      { |users, params| users.export(params["format"]) }
        get("/admin/users/:id.:format")  { |users, params| users.export(params["format"], params["id"]) }

        get("/admin/users/:id/approve") { |users, params| users.approve(params["id"]) }
        get("/admin/users/:id/deny")    { |users, params| users.deny(params["id"]) }

        get("/admin/users/:id/reset_password")    { |users, params| users.reset_password(params["id"]) }
        get("/users/:id/change_password")   { |users, params| users.response.render("admin/users/change_password", :id => params["id"]) }
        post("/users/:id/change_password")  { |users, params| users.change_password(params["id"], params["user"]) }
      end

      # Role Routes
      using services, PortAuthority::Roles do
        get("/admin/roles")            { |roles, params| roles.index(params["query"]) }
        get("/admin/roles/new")        { |roles, params| roles.new(params["role"]) }
        get("/admin/roles/:id")        { |roles, params| roles.edit(params["id"]) }
        get("/admin/roles/:id/delete") { |roles, params| roles.delete(params["id"]) }

        post("/admin/roles")           { |roles, params| roles.create(params["role"], params["permissions"]) }
        put("/admin/roles/:id")        { |roles, params| roles.update(params["id"], params["role"], params["permissions"]) }
        delete("/admin/roles/:id")     { |roles, params| roles.delete(params["id"]) }
      end

      using services, PortAuthority::Account do
        get("/activate")            { |account, params| account.activate(params["key"]) }

        get("/registration")        { |account, params| account.new({}) }
        get("/account/new")         { |account, params| account.new(params["user"]) }
        get("/account")             { |account| account.edit }
        post("/account")            { |account, params| account.create(params["user"]) }
        put("/account")             { |account, params| account.update(params["user"]) }
        get("/account/password")    { |account| account.forgot_password }
        post("/account/password")   { |account, params| account.forgot_password(params["email"]) }

        get("/account/vcard")       { |account| account.vcard }
        post("/account/vcard")      { |account, params| account.vcard(params["vcard"]) }
      end

      using services, PortAuthority::Config do
        get(%r{^/\.config$}) { |config| config.index }
      end

      # Default Route
      using services, PortAuthority::Admin do
        get("/") { |admin| admin.index }
      end
    end
  end
end
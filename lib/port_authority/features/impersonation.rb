class PortAuthority
  module Features

    class Impersonation < Harbor::Contrib::Feature

      def self.permissions
        {"Impersonation" => ["activate"]}
      end

      def self.enable(builder=nil)
        if enabled = super()
          PermissionSet::permissions.merge!(permissions)
          require "port_authority/controllers/impersonation"

          if builder.is_a?(Rack::Builder)
            builder.use(ImpersonationUI)
          else
            warn("PortAuthority::Features::Impersonation UI not enabled.")
            return false
          end
        end

        enabled
      end
      
      def self.routes(services)
        Harbor::Router.new do
          using services, PortAuthority::Impersonation do
            get("/impersonation/activate")   { |impersonation, params| impersonation.activate(params["id"]) }
            get("/impersonation/deactivate") { |impersonation| impersonation.deactivate }
          end
        end
      end

    end

    class ImpersonationUI
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        return [status, headers, body] unless env && env["rack.request.cookie_hash"] && env["rack.request.cookie_hash"]["harbor.original.session"]
        return [status, headers, body] unless (headers["Content-Type"] =~ /html/) && body.is_a?(String)
        
        impersonation_ui = Harbor::View.new("features/impersonation/ui")

        body.gsub!("</body>", impersonation_ui.to_s + "</body>")
        headers["Content-Length"] = body.length.to_s

        [status, headers, body]
      end
    end

  end
end

class Harbor::Session
  def impersonator
    @impersonator ||= self[:impersonator_id] && User.get(self[:impersonator_id])
  end

  def impersonating?
    @impersonating ||= self[:impersonating]
  end

  def return_to
    @return_to ||= self[:return_to]
  end
end
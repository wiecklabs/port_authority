class PortAuthority
  module Authorization
    def self.included(base)

      base.class_eval do
        def self.method_added(method)
          resolve_hooks!(method)
        end
      end

      base.send(:include, Harbor::Hooks)
      base.extend ClassMethods
    end

    module ClassMethods

      def protect(permission_category = nil, *permissions, &block)
        if permission_category.nil? && permissions.size > 0
          raise ArgumentError.new("protect expects no arguments, or a permission_category + permissions, you supplied a nil permission_category and the following permissions: #{permissions}")
        end

        queue_hook(
          lambda do |controller|
            request, response = controller.request, controller.response

            if request.session[:force_password_update]  
              
              if (request.env["PATH_INFO"] =~ /.*?\/account\/?/).nil?
                response.message("error", "You must update your password before continuing.") 
                throw :halt, response.redirect("/account/") 
              end
            end
            # No arguments were supplied to protect, just check for authentiation
            break if permission_category.nil? && request.session.authenticated?

            # Verify that the guest or user is authorized, or if the block returns true
            break if request.session.authorized?(permission_category, *permissions) || (block && block.call(controller))

            # Neither of the checks passed, redirect the user appropriately based on session authentication status
            if request.session.authenticated?
              if controller.respond_to?(:logger)
                controller.logger.warn "Authenticated User #{request.session.user.inspect} was denied access to #{permission_category}/[#{permissions.join(' or ')}]"
              end

              throw :halt, response.render("session/unauthorized")
            else
              throw :halt, response.redirect("/session?referrer=#{Rack::Utils.escape(request.env["REQUEST_URI"])}")
            end
          end
        )
      end

      # Deny access to the next-method-defined if the block returns TRUE
      def deny(&block)
        queue_hook(
          lambda do |controller|
            if block.call(controller)
              # Neither of the checks passed, redirect the user appropriately based on session authentication status
              if request.session.authenticated?
                throw :halt, response.render("session/unauthorized")
              else
                throw :halt, response.redirect("/session?referrer=#{Rack::Utils.escape(request.env["REQUEST_URI"])}")
              end
            else
              # No action taken
            end
          end
        )
      end

      protected

      def queue_hook(hook)
        @queue ||= []
        @queue << hook
      end

      def resolve_hooks!(method)
        return unless @queue

        while hook = @queue.shift
          before(method, &hook)
        end
      end

    end
  end
end

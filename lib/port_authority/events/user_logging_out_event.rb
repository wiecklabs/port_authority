class PortAuthority

  module Events

    class UserLoggingOutEvent

      attr_accessor :user, :request, :response

      def initialize(user, request, response)
        @user = user
        @request = request
        @response = response
      end

    end

  end

end

class PortAuthority

  module Events

    class UserLoggedOutEvent

      attr_accessor :user, :request, :response

      def initialize(user, request, response)
        @user = user
        @request = request
        @response = response
      end

    end

  end

end

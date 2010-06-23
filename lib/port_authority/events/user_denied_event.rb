class PortAuthority

  module Events

    class UserDeniedEvent

      attr_accessor :user, :mail_server

      def initialize(user, mail_server)
        @user = user
        @mail_server = mail_server
      end

    end

  end

end

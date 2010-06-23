class PortAuthority

  module Events

    module Handlers

      class UserDeniedEventHandler

        def initialize(event)
          @user = event.user
          @mail_server = event.mail_server
        end

        def call
          mailer = Harbor::Mailer.new
          mailer.to = @user.email
          mailer.from = PortAuthority::no_reply_email_address
          mailer.subject = PortAuthority::user_denied_email_subject
          mailer.html = Harbor::View.new("mailers/denial.html.erb", :user => @user)
          mailer.text = Harbor::View.new("mailers/denial.txt.erb", :user => @user)

          @mail_server.deliver(mailer)
        end

      end

    end

  end

end

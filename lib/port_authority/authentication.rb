class PortAuthority
  module Authentication

    def user
      @user ||= self[:user_id] && User.get(self[:user_id])
    end

    def guest
      @guest ||= PortAuthority::guest_role
    end

    def authenticated?
      !!user
    end
    
    def guest?
      !authenticated?
    end

    def authenticate(login, password)
      login.nil? ? login : login.strip!

      user = if PortAuthority::login_type == :email
        if User.repository.adapter.class.name =~ /postgres/i
          User.first(:conditions => ["email ILIKE ?", login])
        else
          User.first(:email.like => login.to_s.downcase)
        end
      else
        User.first(PortAuthority::login_type => login)
      end
      status = nil

      return AuthenticationRequest.new(false, PortAuthority::login_failed_message) unless user && user.send(PortAuthority::login_type) == login

      status = AuthenticationRequest.new(false, "User not active") unless user.active?

      # status = AuthenticationRequest.new(false, "Account not active") if PortAuthority::accounts_enabled? && user.account && !user.account.active?

      unless (PortAuthority::use_crypted_passwords? ? user.crypted_password == user.encrypt(password) : user.password == password)
        status = AuthenticationRequest.new(false, PortAuthority::login_failed_message)
      end

      if status && user && PortAuthority::use_lockouts?
        user.failed_logins += 1
        user.save!
        status
      end

      status = AuthenticationRequest.new(false, "Account is pending approval") if PortAuthority::use_approvals? && !user.approved?

      status = AuthenticationRequest.new(false, "Account locked out") if PortAuthority::use_lockouts? && user.locked?

      if status
        status
      else
        user.failed_logins = 0 if PortAuthority::use_lockouts?
        user.last_login = DateTime.now
        user.save!
        self[:user_id] = user.id
        @user = user
        AuthenticationRequest.new(true, "Login success")
      end
    end

    def authorized?(name, *permissions)
      return true if guest_permitted?(name, *permissions)
      return false unless authenticated?
      set = user.permission_sets.first(:name => name)
      set ? permissions.any? { |permission| set.include?(permission) } : false
    end

    def guest_permitted?(name, *permissions)
      return false unless guest
      set = guest.permission_sets.first(:name => name)
      set ? permissions.any? { |permission| set.include?(permission) } : false
    end

    def abandon!
      @user = nil
      self.destroy
      self
    end

    private

    class AuthenticationRequest
      def initialize(success, failure_reason = nil)
        @success = success
        @failure_reason = failure_reason
      end

      def success?
        @success
      end

      def to_s
        @failure_reason
      end
    end
  end
end

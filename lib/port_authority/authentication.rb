class PortAuthority
  module Authentication
    
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

    def authorized?(group, *permission_names)
      permission_names.any? { |name| permissions[group].include?(name) }
    end
    
    def permissions
      @permissions ||= load_permissions
    end

    def abandon!
      @user = nil
      self.destroy
      self
    end

    private
    
    ##
    # Returns self-generating hash w/ Key=PermissionSetName, Value=PermissionSet.  Calling this method will
    # set session['permissions'] if the current value is non-existant or stale
    ##
    def load_permissions
      permission_data = self['permissions'].to_s

      if permission_data =~ /(Guest|User)\[([0-9\-:T]{25})\]/
        permission_cache_source = $1
        permission_cache_last_updated = DateTime.parse($2)
      else
        return update_permission_cache(guest? ? load_permissions_from_guest_role : load_permissions_from_user)
      end

      loader = Hash.new do |h, k|
        h[k] = if permission_data =~ /#{Regexp.escape(k)}\=(\d{1,10})?/
          SessionPermissionSet.new(k, $1.to_i)
        else
          SessionPermissionSet.new(k, 0)
        end
      end

      if guest?
        if permission_cache_source != 'Guest' || (guest.updated_at > permission_cache_last_updated) 
          update_permission_cache(load_permissions_from_guest_role)
        else
          loader
        end
      else
        if permission_cache_source != 'User' || (user.updated_at > permission_cache_last_updated) 
          update_permission_cache(load_permissions_from_user)
        else
          loader
        end
      end
    end

    ##
    # Returns a self-generating hash that will always return either a RolePermissionSet or a
    # SessionPermissionSet
    ##
    def load_permissions_from_guest_role
      Hash.new do |h, k|
        h[k] = PortAuthority::guest_role.permission_sets.detect { |set| set.name == k } || SessionPermissionSet.new(k, 0)
      end
    end

    ##
    # Returns a self-generating hash that will always return a SessionPermissionSet
    ##
    def load_permissions_from_user
      guest_permissions = load_permissions_from_guest_role

      Hash.new do |h, k|
        guest_permission_set = PortAuthority::guest_role.permission_sets.detect { |set| set.name == k }
        guest_mask = guest_permission_set ? guest_permission_set.mask : 0

        user_permission_set = user.permission_sets.detect { |set| set.name == k }
        user_mask = user_permission_set ? user_permission_set.mask : 0

        h[k] = SessionPermissionSet.new(k, guest_mask | user_mask)
      end
    end

    ## Serializes Guest Permissions (always) + User Permissions (if available) into
    #  a string in the format:
    #
    #  (Guest|User)[LastUpdatedTimestamp]:PermissionSetName=mask,PermissionSetName=mask
    #
    #  into session['permissions'], returns the value passed in as source_permissions
    def update_permission_cache(source_permissions)
      if guest?
        permission_cache_source = 'Guest'
        permission_cache_last_updated = guest.updated_at
      else
        permission_cache_source = 'User'
        permission_cache_last_updated = user.updated_at
      end

      self['permissions'] = "#{permission_cache_source}[#{permission_cache_last_updated}]:" + PermissionSet::permissions.map { |name, keys| "#{name}=#{source_permissions[name].mask}" }.join(',')

      source_permissions
    end
    
  end
end

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
      @user ||= begin
        if self[:user_id]
          @user = User.get(self[:user_id])
        elsif auth_key = @request.cookies['harbor.auth_key']
          # authentication via remember-me functionality
          @user = User.first(:auth_key => auth_key)
        end
      end
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
      PortAuthority.logger.info{"Login attempt with #{PortAuthority::login_type.to_s}:#{login.inspect} and password:#{password.inspect}"} if PortAuthority.logger
      login = login.nil? ? login : login.downcase.strip
      user = User.first(:conditions => ["LOWER(#{PortAuthority::login_type}) = ?", login])
      
      status = nil

      PortAuthority.logger.info{"Claimed identity: #{user.inspect}"} if PortAuthority.logger
      return AuthenticationRequest.new(false, PortAuthority::login_failed_message) unless user && user.send(PortAuthority::login_type).downcase == login.downcase

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
        PortAuthority.logger.info{"\tLogin failed: #{status.inspect}"} if PortAuthority.logger
        status
      else
        user.failed_logins = 0 if PortAuthority::use_lockouts?
        user.last_login = DateTime.now
        user.save!
        self[:user_id] = user.id
        self[:force_password_update] = user.force_password_update
        @user = user
        PortAuthority.logger.info{"\tLogin success"} if PortAuthority.logger
        AuthenticationRequest.new(true, "Login success")
      end
    end

    def authorized?(group, *permission_names)
      permission_names.any? { |name| permissions[group].include?(name) }
    end
    
    def permissions
      @permissions ||= load_permissions
    end

    ##
    # flushes and reloads the permissions cache for use when automatically authenticating requests
    ##
    def flush_permissions!
      @permissions = load_permissions
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

      if permission_data =~ /(Guest|User)\[([0-9\-:T]{25})\]\:(.*)/
        permission_cache_source = $1
        permission_cache_last_updated = DateTime.parse($2)
        permission_string = $3
      else
        return update_permission_cache(guest? ? load_permissions_from_guest_role : load_permissions_from_user)
      end
      
      cached_permission_map = Hash[*permission_string.split(';').map { |permission| key, value = permission.split('='); [key, SessionPermissionSet.new(key, value.to_i)] }.flatten]
      loader = lambda { |group_name| cached_permission_map[group_name] || SessionPermissionSet.new(group_name, 0) }

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
      guest_permission_sets = PortAuthority::guest_role.permission_sets.entries

      Hash.new do |h, k|
        h[k] = guest_permission_sets.detect { |set| set.name == k } || SessionPermissionSet.new(k, 0)
      end
    end

    ##
    # Returns a self-generating hash that will always return a SessionPermissionSet
    ##
    def load_permissions_from_user
      user_permission_sets = user.permission_sets.entries

      Hash.new do |h, k|
        h[k] = user_permission_sets.detect { |set| set.name == k } || SessionPermissionSet.new(k, 0)
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

      self['permissions'] = "#{permission_cache_source}[#{permission_cache_last_updated}]:" + PermissionSet::permissions.map { |name, keys| "#{name}=#{source_permissions[name].mask}" }.join(';')

      source_permissions
    end
    
  end
end

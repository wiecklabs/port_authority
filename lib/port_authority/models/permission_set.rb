module PermissionSet

  def self.permissions
    @permissions ||= {}
  end

  ##
  # This method (over-ridden by a subclass' property declaration) should return
  # the group name of the permission set.
  # 
  ## EXAMPLE
  # 
  # PermissionSet.permissions.merge! "Users" => ["create", "show"], "Orders" => ["create", "show"]
  # 
  # PermissionSet.new(:name => "Users")
  # PermissionSet.new(:name => "Orders")
  # 
  def name
    raise NotImplementedError.new("PermissionSet#name must be implemented.")
  end

  ##
  # This method (over-ridden by a subclass' property declaration) should return
  # an integer which is a mask of the permissions for the object.
  # 
  def mask
    raise NotImplementedError.new("PermissionSet#mask must be implemented.")
  end

  ##
  # Checks the #name and #mask against PermissionSet::permissions
  # to determine if there is a positive match.
  # 
  def include?(permission)
    index = mask_for_permission(permission)
    self.mask & index == index
  end

  ##
  # Adds the masks of the permissions it receives to the PermissionSet's mask.
  # 
  def add(*permissions)
    @old_mask ||= self.mask
    permissions.each { |permission| self.mask |= mask_for_permission(permission) }
  end
  alias :<< :add

  ##
  # Removes the masks of the permissions it receives from the PermissionSet's mask.
  #
  def remove(*permissions)
    @old_mask ||= self.mask
    permissions.each { |permission| self.mask &= ~mask_for_permission(permission) }
  end

  ##
  # Accepts a permissions hash like,
  #   { "create" => "1", "edit" => "0" }
  # 
  def update_mask(permissions = {})
    @old_mask ||= self.mask
    permissions.each do |permission, value|
      value.to_i == 0 ? remove(permission) : add(permission)
    end
  end

  private

  ##
  # Returns a permission's mask value based on the PermissionSet::permissions hash.
  # 
  def mask_for_permission(permission)
    group = PermissionSet::permissions[self.name]
    raise "Requested permission group \"#{self.name}\" not found in PermissionSet::permissions hash." if group.nil?

    index = group.index(group.detect { |value, index| value =~ /^#{permission}(:|$)/ })

    # If the permission doesn't exist in the global permissions hash, then
    # there is a bug, and it shouldn't fail silently by returning false.
    raise "Requested permission \"#{permission}\" not found in PermissionSet::permissions hash for \"#{self.name}\" group." if index.nil?

    # Turn the index into a mask value
    1 << index
  end
end

class UserPermissionSet
  include DataMapper::Resource
  include PermissionSet

  property :user_id, Integer, :key => true
  property :name, String, :key => true
  property :mask, Integer, :default => 0

  belongs_to :user
end

class RolePermissionSet
  include DataMapper::Resource
  include PermissionSet

  property :role_id, Integer, :key => true
  property :name, String, :key => true
  property :mask, Integer, :default => 0

  belongs_to :role

  after :save do
    # Propagation is disabled, or mask hasn't changed.
    return @old_mask = nil if !@propagate_permissions || @old_mask.nil? || @old_mask == self.mask

    propagate_permissions!
  end

  def propagate_permissions=(value)
    @propagate_permissions = value
  end

  def propagate_permissions!
    @old_mask ||= 0

    users = User.all(User.role_users.role_id => self.role_id)

    users.each do |user|

      role_permissions = RolePermissionSet.all(:name => self.name, :role_id.in => user.roles.map { |r| r.id }) - [self]

      # Calculate a user's total mask inherited from it's roles
      total_role_mask = role_permissions.inject(0) { |mask, set| mask | set.mask } | @old_mask

      # And calculate the mask for a user excluding this role
      exclusive_role_mask = role_permissions.inject(0) { |mask, set| mask | set.mask }

      user_permission_set = user.permission_sets.first_or_create(:name => self.name, :user_id => user.id)

      # Get the user's mask independent of roles.
      user_mask = user_permission_set.mask

      # If the user has no other roles, and no custom permissions, update directly.
      if exclusive_role_mask == 0 && user_mask == @old_mask
        user_permission_set.mask = self.mask
        user_permission_set.save
        next
      end

      # We now update the user's mask by removing the old permission
      # and applying the new mask, as well as the mask from the user's
      # other roles.

      if @old_mask > self.mask
        # Deleting a permission...
        bit = @old_mask - self.mask

        # Subtract the bit, and add the other roles back
        new_mask = user_mask &~ bit | exclusive_role_mask
      else
        # Adding a permission
        bit = self.mask - @old_mask
        new_mask = user_mask | bit
      end

      user_permission_set.mask = new_mask
      user_permission_set.save

    end

    @old_mask = nil
  end
end

class SessionPermissionSet
  include PermissionSet

  attr_reader :name, :mask

  def initialize(name, mask)
    @name, @mask = name, mask
  end
end
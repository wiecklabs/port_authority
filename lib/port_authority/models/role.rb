class Role
  include DataMapper::Resource

  def self.is_searchable!
    is :searchable
  end

  property :id, Serial
  property :name, String
  property :description, Text

  has n, :permission_sets, :class_name => "RolePermissionSet"
  has n, :users, :through => Resource

end
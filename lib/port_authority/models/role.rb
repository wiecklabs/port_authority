class Role
  include DataMapper::Resource

  def self.is_searchable!
    is :searchable
  end

  property :id, Serial
  property :name, String
  property :description, Text
  property :updated_at, DateTime

  has n, :permission_sets, :model => "RolePermissionSet"
  has n, :users, :through => Resource
  
  after :destroy do
    RoleUser.all(:role_id => self.id).each { |ru| ru.destroy }
  end
  
end
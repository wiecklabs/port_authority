class Configuration
  include DataMapper::Resource
  
  property :id, Serial
  property :port_name, String
  property :category, String
  property :name, String
  property :value, String
  
end
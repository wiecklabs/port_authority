module Configurable
  
  @@configs = ConfigurationSet.new
  
  def method_missing(method_name, *args)
    if config = @@configs.get(method_name)
      config.value
    else
      raise NoMethodError, "undefined method \'#{method_name}\' for #{self}"
    end
  end
  
  def config(config_name, default_value, category=nil)
    @@configs.add(self, config_name, default_value, category)
  end
  

end
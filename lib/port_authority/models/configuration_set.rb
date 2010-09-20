class ConfigurationSet
  
  def initialize
    @configs = {}
  end
  
  def add(klass, config_name, default_value, category)
    @configs[config_name] = if config = Configuration.first(:port_name => klass, :name => config_name)
      config
    else
      Configuration.create(:port_name => klass, :name => config_name, :value => default_value, :category => category)
    end
  end
  
  def get(config_name)
    @configs[config_name]
  end
  
  def has_config?(config_name)
    @configs.has_key?(config_name)
  end
  
  def reload_configs
    @configs.each do |config_name, config|
      @configs[config_name] = config.reload
    end
  end
  
end
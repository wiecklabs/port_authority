require Pathname(__FILE__).dirname + "test_helper"
require "capybara"
require "capybara/dsl"

Capybara.default_driver = :selenium

load Pathname(__FILE__).dirname + "../config.ru"
DataMapper.setup :default, "sqlite3::memory:"
DataMapper.auto_migrate!

Capybara.app = PortAuthority.new($services)

module AcceptanceTestHelper
  include Capybara

  def login_as(user)
    visit '/login'
    fill_in 'login', :with => user.email
    fill_in 'password', :with => user.password
    click_button 'Log In'
  end
  
  def refresh
    visit(current_url)
  end
end
require "pathname"
require Pathname(__FILE__).dirname + "../acceptance_helper"

class UsersAdminAcceptanceTest < Test::Unit::TestCase
  include AcceptanceTestHelper

  def setup
    initialize_test_environment
    login_as @user
  end

  def teardown
    destroy_test_environment
  end

  test "successful_batch_export" do
    visit "/admin/users"
    click_link "export"
    click_link "vcard_link"
    click_link "export"
    click_link "csv_link"
  end
  
  test "successful_user_export" do
    visit "/admin/users"
    click_link "user_#{@user.id}_vcf"
  end
end
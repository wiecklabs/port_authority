require "pathname"
require Pathname(__FILE__).dirname + "../acceptance_helper"

class AccountsAcceptanceTest < Test::Unit::TestCase
  include AcceptanceTestHelper
  
  def setup
    initialize_test_environment
  end
  
  def teardown
    destroy_test_environment
  end
  
  test "forgot_password_email_is_case_insensitive" do
    visit "/account/password"
    fill_in "user_email", :with => @user.email.upcase
    click_button "Submit"
    assert page.body.has_content? "Your request to reset your password has been sent to the email registered with your account. Please check your email."
  end
  
end
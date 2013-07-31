require 'test_helper'

class UtilControllerTest < ActionController::TestCase
  test "should get new_messages_count" do
    get :new_messages_count
    assert_response :success
  end

end

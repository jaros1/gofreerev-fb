require 'test_helper'

class CommentTest < ActiveSupport::TestCase

  test "comment_gift_for_not_friend" do
    puts User.count
    g = users(:charlie)

    assert false
  end
end

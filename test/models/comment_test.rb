require 'test_helper'

class CommentTest < ActiveSupport::TestCase

  def assert_notifications (options)
    # get params
    gift = options[:gift]
    user = options[:user]
    comment = options[:comment]
    notifications = options[:notifications]
    method = options[:method]
    # before test
    notifications_before = Notification.count
    # create any optional transactions
    yield if block_given?
    # create gift
    c = Comment.new
    c.user_id = user.user_id
    c.gift_id = gift.gift_id
    c.comment = comment
    assert c.save, "#{method}: could not send notification: " + c.errors.full_messages.join('. ')
    # test number of notifications
    notifications_after = Notification.count
    expected_no_notifications = notifications.size
    found_no_notifications = notifications_after-notifications_before
    assert (expected_no_notifications == found_no_notifications), "#{method}: Expected #{expected_no_notifications} new notifications. Found #{found_no_notifications} new notifications"
    # test notifications
    expected_notifications = notifications.sort { |a, b| a[:to_user_id] <=> b[:to_user_id] }
    found_notifications = Notification.last(expected_no_notifications).collect do |n|
      {:to_user_id => n.to_user_id,
       :noti_key => n.noti_key,
       :no_users => n.noti_options[:no_users],
       :usernames => [n.noti_options[:username1],
                      n.noti_options[:username2],
                      n.noti_options[:username3]].find_all { |un| un }.sort
      }
    end.sort do |a, b|
      a[:to_user_id] <=> b[:to_user_id]
    end
    0.upto(expected_no_notifications-1) do |i|
      %w(:to_user_id, :noti_key, :no_users).each do |name|
        assert (expected_notifications[i][name] == found_notifications[i][name]),
               "#{method}. Notification #{i+1}. Field #{name}. " +
                   "Expected #{expected_notifications[i][name]}. " +
                   "Found #{found_notifications[i][name]}"
      end # each name
      assert (expected_notifications[i][:usernames].size == found_notifications[i][:usernames].size),
             "#{method}. Notification #{i+1}. Field usernames. " +
                 "Expected #{expected_notifications[i][:usernames].size} user names. " +
                 "Found #{found_notifications[i][:usernames].size} user names."
      # todo: how to assert translation
    end # each i
  end # assert_new_notifications

  test "charlie_comments_own_gift" do
    charlie = users(:charlie)
    gift = gifts(:charlie_gift_a)
    assert_notifications :gift => gift,
                             :user => charlie,
                             :comment => "don't send any notifications",
                             :method => __method__,
                             :notifications => []
  end # charlie_comments_own_gift

  def one_user_comments_charlies_gift
    charlie = users(:charlie)
    gift = gifts(:charlie_gift_a)
    u1 = users(:sandra)
    # should send one notification to charlie
    assert_notifications :gift => gift,
                             :user => u1,
                             :comment => 'send notification to charlie',
                             :method => __method__,
                             :notifications => [{:to_user_id => charlie.user_id,
                                                 :noti_key => 'new_comment_giver_1_v1',
                                                 :no_users => 1,
                                                 :usernames => ["Sandra Q"]
                                                }]
  end # one_user_comments_charlies_gift

  test "one_user_comments_charlies_gift" do
    one_user_comments_charlies_gift
  end # one_user_comments_charlies_gift

  def two_users_comment_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    gift = gifts(:charlie_gift_a)
    # two notifications when u2/karen comments charlies gift
    # 1) notification to gift owner charlie
    # 2) notification to other users (sandra) that have commented charlies gift
    assert_notifications(:gift => gift,
                         :user => u2,
                         :comment => 'send notification to charlie and sandra',
                         :method => __method__,
                         :notifications => [ # notification to gift owner charlie
                                             {:to_user_id => charlie.user_id,
                                             :noti_key => 'new_comment_giver_2_v1',
                                             :no_users => 2,
                                             :usernames => ["Karen S", "Sandra Q"]
                                            },
                                             # notification to other users that has commented charlies gift
                                            {:to_user_id => u1.user_id,
                                             :noti_key => 'new_comment_giver_other_1_v1',
                                             :no_users => 1,
                                             :usernames => ["Karen S"]
                                            }]) do
      # setup context for this test - u1/sandra comments charlies gift
      one_user_comments_charlies_gift
    end
  end # two_users_comment_charlies_gift

  test "two_users_comment_charlies_gift" do
    two_users_comment_charlies_gift
  end # two_users_comment_charlies_gift

  def three_users_comment_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    u3 = users(:david)
    gift = gifts(:charlie_gift_a)
    # three notifications when u3/david comments charlies gift
    # 1) notification to gift owner charlie
    # 2) notification to u1/sandra that also has commented charlies gift
    # 3) notification to u2/karen that also has commented charlies gift
    assert_notifications(:gift => gift,
                         :user => u3,
                         :comment => 'send notification to charlie, sandra and karen',
                         :method => __method__,
                         :notifications => [
                             # notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # notification to u1/sandra that also has commented charlies gift
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Karen S"]
                             },
                             # notification to u2/karen that also has commented charlies gift
                             {:to_user_id => u2.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             }]) do
      # setup context for this test - two other users (sandra and karen) have already commented this gift
      two_users_comment_charlies_gift
    end
  end # three_users_comment_charlies_gift

  test "three_users_comment_charlies_gift" do
    three_users_comment_charlies_gift
  end # three_users_comment_charlies_gift

  test "four_users_comment_charlies_gift" do
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    u3 = users(:david)
    u4 = users(:dick)
    gift = gifts(:charlie_gift_a)
    # four notifications when u4/dick comments charlies gift

    old_no_noti = Notification.count
    # sandra comments charlies gift => one notification to charlie
    c1 = Comment.new
    c1.user_id = u1.user_id
    c1.comment = 'send notification to charlie'
    c1.gift_id = gift.gift_id
    assert c1.save
    new_no_noti = Notification.count
    assert (old_no_noti + 1 == new_no_noti)
    n = Notification.last
    assert (n.to_user_id == charlie.user_id)
    assert (n.noti_key == 'new_comment_giver_1_v1')
    assert (n.noti_options[:no_users] == 1)
    # karen comments charlies gift => one changed notification to charlie and one notification to sandra
    c2 = Comment.new
    c2.user_id = u2.user_id
    c2.comment = 'send notification to charlie and sandra'
    c2.gift_id = gift.gift_id
    assert c2.save
    new_no_noti = Notification.count
    assert (old_no_noti + 2 == new_no_noti), "expected 2 notification, found #{new_no_noti-old_no_noti} notification(s)"
    n1, n2 = Notification.last(2)
    assert (n1.to_user_id == charlie.user_id)
    assert (n1.noti_key == 'new_comment_giver_2_v1')
    assert (n1.noti_options[:no_users] == 2)
    assert (n2.to_user_id == u1.user_id)
    assert (n2.noti_key == 'new_comment_giver_other_1_v1')
    assert (n2.noti_options[:no_users] == 1)
    # david comments charlies gift => one changed notification charlie, obe changed notification to sandra and one notification to karen
    c3 = Comment.new
    c3.user_id = u3.user_id
    c3.comment = 'send notification to charlie, sandra and karen'
    c3.gift_id = gift.gift_id
    assert c3.save
    new_no_noti = Notification.count
    assert (old_no_noti + 3 == new_no_noti), "expected 3 notification, found #{new_no_noti-old_no_noti} notification(s)"
    ns = Notification.last(3)
    n1_charlie = ns.find_all { |n| n.to_user_id == charlie.user_id }.first
    n2_sandra = ns.find_all { |n| n.to_user_id == u1.user_id }.first
    n3_karen = ns.find_all { |n| n.to_user_id == u2.user_id }.first
    # 3 user names in notification to charlie (sandra, karen and david)
    assert (n1_charlie != nil)
    assert (n1_charlie.noti_key == 'new_comment_giver_3_v1')
    assert (n1_charlie.noti_options[:no_users] == 3), "excepted 3 user names in notification to charlie, found #{n1.noti_options[:no_users]}"
    assert (["David M", "Karen S", "Sandra Q"] == [n1_charlie.noti_options[:username1], n1_charlie.noti_options[:username2], n1_charlie.noti_options[:username3]].sort)
    # 2 user names in notification to sandra (karen and david)
    assert (n2_sandra != nil)
    assert (n2_sandra.noti_key == 'new_comment_giver_other_2_v1')
    assert (n2_sandra.noti_options[:no_users] == 2)
    assert (["David M", "Karen S"] == [n2_sandra.noti_options[:username1], n2_sandra.noti_options[:username2]].sort)
    assert (n3_karen != nil)
    # 1 user name in notification to karen (david)
    assert (n3_karen != nil)
    assert (n3_karen.noti_key == 'new_comment_giver_other_1_v1')
    assert (n3_karen.noti_options[:no_users] == 1)
    assert ("David M" == n3_karen.noti_options[:username1])
    # dick comments charlies gift => one changed notification charlie, one changed notification to sandra, one changed notification to karen and one notification to david
    c4 = Comment.new
    c4.user_id = u4.user_id
    c4.comment = 'send notification to charlie, sandra, karen and dick'
    c4.gift_id = gift.gift_id
    assert c4.save
    new_no_noti = Notification.count
    assert (old_no_noti + 4 == new_no_noti), "expected 4 notification, found #{new_no_noti-old_no_noti} notification(s)"
    ns = Notification.last(4)
    n1_charlie = ns.find_all { |n| n.to_user_id == charlie.user_id }.first
    n2_sandra = ns.find_all { |n| n.to_user_id == u1.user_id }.first
    n3_karen = ns.find_all { |n| n.to_user_id == u2.user_id }.first
    n4_david = ns.find_all { |n| n.to_user_id == u3.user_id }.first
    # 4 users in notification to charlie (only names for sandra, karen and david)
    assert (n1_charlie != nil)
    assert (n1_charlie.noti_key == 'new_comment_giver_n_v1')
    assert (n1_charlie.noti_options[:no_users] == 4), "excepted 4 users in notification to charlie, found #{n1.noti_options[:no_users]}"
    assert (["David M", "Karen S", "Sandra Q"] == [n1_charlie.noti_options[:username1], n1_charlie.noti_options[:username2], n1_charlie.noti_options[:username3]].sort)
    # 3 user names in notification to sandra (karen, david and dick)
    assert (n2_sandra != nil)
    assert (n2_sandra.noti_key == 'new_comment_giver_other_3_v1')
    assert (n2_sandra.noti_options[:no_users] == 3)
    assert (["David M", "Dick B", "Karen S"] == [n2_sandra.noti_options[:username1], n2_sandra.noti_options[:username2], n2_sandra.noti_options[:username3]].sort)
    # 2 user name in notification to karen (david and dick)
    assert (n3_karen != nil)
    assert (n3_karen.noti_key == 'new_comment_giver_other_2_v1')
    assert (n3_karen.noti_options[:no_users] == 2)
    assert (["David M", "Dick B"] == [n3_karen.noti_options[:username1], n3_karen.noti_options[:username2]].sort)
    # 1 user name in notification to david (dick)
    assert (n4_david != nil)
    assert (n4_david.noti_key == 'new_comment_giver_other_1_v1')
    assert (n4_david.noti_options[:no_users] == 1)
    assert ("Dick B" == n4_david.noti_options[:username1])
  end # four_users_comment_charlies_gift

end

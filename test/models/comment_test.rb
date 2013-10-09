require 'test_helper'

class CommentTest < ActiveSupport::TestCase

  def dump_notifications(no_notifications)
    ns = Notification.last(no_notifications)
    ns.collect { |n| "#{n.noti_key} to #{n.to_user.short_user_name}" }.join(', ')
  end

  def assert_notifications (options)
    # get params
    gift = options[:gift]
    user = options[:user]
    comment = options[:comment]
    new_deal_yn = options[:new_deal_yn]
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
    c.new_deal_yn = new_deal_yn
    assert c.save, "#{method}: could not send notification: " + c.errors.full_messages.join('. ')
    # test number of notifications
    notifications_after = Notification.count
    expected_no_notifications = notifications.size
    found_no_notifications = notifications_after-notifications_before
    assert (expected_no_notifications == found_no_notifications), "#{method}: Expected #{expected_no_notifications} new notifications. Found #{found_no_notifications} new notifications. #{dump_notifications(found_no_notifications)}"
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
      # todo: how to assert translation?
    end # each i
  end # assert_new_notifications


  #
  # test notifications for new comments
  #

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
    # 1) notification to gift owner charlie - 4 users have commented charlies gift
    # 2) notification to u1/sandra. 3 other users have also commented charlies gift
    # 3) notification to u2/karen. 2 other users have also commented charlies gift
    # 4) notificatiob to u3/david. 1 other user has also commented charlies gift
    assert_notifications(:gift => gift,
                         :user => u4,
                         :comment => 'send notification to charlie, sandra, karen and david',
                         :method => __method__,
                         :notifications => [
                             # notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_n_v1',
                              :no_users => 4,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # notification to u1/sandra that also has commented charlies gift
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_comment_giver_other_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Dick B", "Karen S"]
                             },
                             # notification to u2/karen that also has commented charlies gift
                             {:to_user_id => u2.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # notification to u3/david that also has commented charlies gift
                             {:to_user_id => u3.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             }]) do
      # setup context for this test - two other users (sandra and karen) have already commented this gift
      three_users_comment_charlies_gift
    end
  end # three_users_comment_charlies_gift


  #
  # test notifications for new proposals
  #

  def one_proposal_for_charlies_gift
    charlie = users(:charlie)
    gift = gifts(:charlie_gift_a)
    u1 = users(:sandra)
    # should send one notification to charlie
    assert_notifications :gift => gift,
                         :user => u1,
                         :comment => 'send notification to charlie',
                         :new_deal_yn => 'Y',
                         :method => __method__,
                         :notifications => [{:to_user_id => charlie.user_id,
                                             :noti_key => 'new_proposal_giver_1_v1',
                                             :no_users => 1,
                                             :usernames => ["Sandra Q"]
                                            }]
  end # one_proposal_for_charlies_gift_a

  test "one_proposal_for_charlies_gift" do
    one_proposal_for_charlies_gift
  end # one_user_comments_charlies_gift

  def one_proposal_for_charlies_gift_b
    charlie = users(:charlie)
    gift = gifts(:charlie_gift_a)
    u1 = users(:sandra)
    # two proposals from u1/sandra - should send one notification to charlie
    assert_notifications :gift => gift,
                         :user => u1,
                         :comment => 'send notification to charlie',
                         :new_deal_yn => 'Y',
                         :method => __method__,
                         :notifications => [{:to_user_id => charlie.user_id,
                                             :noti_key => 'new_proposal_giver_1_v1',
                                             :no_users => 1,
                                             :usernames => ["Sandra Q"]
                                            }]       do
      one_proposal_for_charlies_gift
    end
  end # one_proposal_for_charlies_gift_b

  test "one_proposal_for_charlies_gift_b" do
    one_proposal_for_charlies_gift_b
  end # one_user_comments_charlies_gift_b

  def two_proposals_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    gift = gifts(:charlie_gift_a)
    # two notifications when u2/karen comments charlies gift
    # 1) notification to gift owner charlie
    # 2) notification to one other user (sandra) that also has a proposal for charlies gift
    assert_notifications(:gift => gift,
                         :user => u2,
                         :comment => 'send notification to charlie and sandra',
                         :new_deal_yn => 'Y',
                         :method => __method__,
                         :notifications => [ # notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["Karen S", "Sandra Q"]
                             },
                             # notification to other users that has commented charlies gift
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test - u1/sandra proposal for charlies gift
      one_proposal_for_charlies_gift
    end
  end # two_proposals_for_charlies_gift

  test "two_proposals_for_charlies_gift" do
    two_proposals_for_charlies_gift
  end # two_proposals_for_charlies_gift


  #
  # test mix of new comments and new proposals
  #


  def one_comment_and_one_proposal_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    gift = gifts(:charlie_gift_a)
    # three notifications when u2/karen create a proposal for charlies gift
    # 1) new comment to charlie (u1/sandra from context setup)
    # 2) new proposal to charlie (u2/karen)
    # 3) notification to sandra that karen has a proposal for charlies gift
    assert_notifications(:gift => gift,
                         :user => u2,
                         :comment => 'send notification to charlie and sandra',
                         :new_deal_yn => 'Y',
                         :method => __method__,
                         :notifications => [
                             # notification to gift owner charlie - u1/sandra has commented charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]},
                             # notification to gift owner charlie - u2/karen has a proposal for charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]},
                             # notification to u1/sandra that u2/karen has a proposal for charlies gift
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test - u1/sandra has commented charlies gift
      one_user_comments_charlies_gift
    end
  end # one_comment_and_one_proposal_for_charlies_gift

  test "one_comment_and_one_proposal_for_charlies_gift" do
    one_comment_and_one_proposal_for_charlies_gift
  end # one_comment_and_one_proposal_for_charlies_gift

  def one_proposal_and_one_comment_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra)
    u2 = users(:karen)
    gift = gifts(:charlie_gift_a)
    # two notifications when u2/karen create a proposal for charlies gift
    # 1) new comment notification to gift owner charlie (u1/sandra from context setup)
    # 2) new proposal notification to gift owner charlie (u2/karen)
    # 3) notification to one other user (sandra) has commented charlies gift
    # found: new_comment_giver_1_v1 to Charlie S, new_proposal_giver_1_v1 to Charlie S, new_proposal_giver_other_1_v1 to Sandra Q
    assert_notifications(:gift => gift,
                         :user => u2,
                         :comment => 'send notification to charlie and sandra',
                         :method => __method__,
                         :notifications => [
                             # notification to gift owner charlie - comment from u1/sandra
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             },
                             # notification to gift owner charlie - proposal from u2/karen
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # notification to u1/sandra that u2/karen has a proposal for charlies gift
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test - u1/sandra has made a proposal for charlies gift
      one_proposal_for_charlies_gift
    end
  end # one_proposal_and_one_comment_for_charlies_gift

  test "one_proposal_and_one_comment_for_charlies_gift" do
    one_proposal_and_one_comment_for_charlies_gift
  end # one_proposal_and_one_comment_for_charlies_gift

  def two_proposals_and_one_comment_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra) # proposal
    u2 = users(:karen)  # proposal
    u3 = users(:david)  # comment
    gift = gifts(:charlie_gift_a)
    # five notifications:
    # 1) notification to charlie - from setup - two users with proposals
    # 2) notification to charlie - one user with comment
    # 3) notification to u1/sandra - from setup - one other user u2/karen with proposal
    # 4) notification to u1/sandra - one other user u3/david with comment
    # 5) notification to u2/karen - one user u3/david with comment
    assert_notifications(:gift => gift,
                         :user => u3,
                         :comment => 'send notification to charlie, sandra and karen',
                         :new_deal_yn => nil,
                         :method => __method__,
                         :notifications => [
                             # 1) notification to charlie - from setup - two users with proposals
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["Karen S", "Sandra Q"]
                             },
                             # 2) notification to charlie - one user with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             },
                             # 3) notification to u1/sandra - from setup - one other user u2/karen with proposal
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 4) notification to u1/sandra - one other user u3/david with comment
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             },
                             # 5) notification to u2/karen - one user u3/david with comment
                             {:to_user_id => u2.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             }  ]) do
      # setup context for this test - u1/sandra and u2/karen proposals for charlies gift
      two_proposals_for_charlies_gift
    end
  end # two_proposals_and_one_comment_for_charlies_gift

  test "two_proposals_and_one_comment_for_charlies_gift" do
    two_proposals_and_one_comment_for_charlies_gift
  end # two_proposals_and_one_comment_for_charlies_gift

  def two_proposals_and_two_comments_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra) # proposal
    u2 = users(:karen)  # proposal
    u3 = users(:david)  # comment
    u4 = users(:dick)   # comment
    gift = gifts(:charlie_gift_a)
    # sex notifications:
    # 1) notification to charlie - from setup - two users with proposals
    # 2) notification to charlie - two users with proposals
    # 3) notification to u1/sandra - from setup - one other user u2/karen with proposal
    # 4) notification to u1/sandra - two other users u3/david and u4/dick with comments
    # 5) notification to u2/karen - two users u3/david and u4/dick with comments
    # 6) notification to u3/david - one user with comment
    assert_notifications(:gift => gift,
                         :user => u4,
                         :comment => 'send notification to charlie, sandra, karen and david',
                         :new_deal_yn => nil,
                         :method => __method__,
                         :notifications => [
                             # 1) notification to charlie - from setup - two users with proposals
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["Karen S", "Sandra Q"]
                             },
                             # 2) notification to charlie - two users with comments
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 3) notification to u1/sandra - from setup - one other user u2/karen with proposal
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 4) notification to u1/sandra - two other users u3/david and u4/dick with comments
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 5) 5) notification to u2/karen - two users u3/david and u4/dick with comments
                             {:to_user_id => u2.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 6) notification to u3/david - one user with comment
                             {:to_user_id => u3.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             } ]) do
      # setup context for this test
      two_proposals_and_one_comment_for_charlies_gift
    end
  end # two_proposals_and_two_comments_for_charlies_gift

  test "two_proposals_and_two_comments_for_charlies_gift" do
    two_proposals_and_two_comments_for_charlies_gift
  end # two_proposals_and_two_comments_for_charlies_gift


end # CommentTest

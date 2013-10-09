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
    if gift or user or comment or new_deal_yn
      # create comment
      c = Comment.new
      c.user_id = user.user_id
      c.gift_id = gift.gift_id
      c.comment = comment
      c.new_deal_yn = new_deal_yn
      assert c.save, "#{method}: could not send notification: " + c.errors.full_messages.join('. ')
    end
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


  def comment_for_charlies_gift (user, comment)
    c = Comment.new
    c.user_id = user.user_id
    c.gift_id = gifts(:charlie_gift_a).gift_id
    c.comment = comment
    assert c.save
    c
  end # comment_for_charlies_gift

  def proposal_for_charlies_gift (user, comment)
    c = Comment.new
    c.user_id = user.user_id
    c.gift_id = gifts(:charlie_gift_a).gift_id
    c.comment = comment
    c.new_deal_yn = 'Y'
    assert c.save
    c
  end # one_comment_for_charlies_gift


  def charlie
    users(:charlie)
  end
  def u1_sandra
    users(:sandra)
  end
  def u2_karen
    users(:karen)
  end
  def u3_david
    users(:david)
  end
  def u4_dick
    users(:dick)
  end





  #
  # test notifications for new comments
  #

  test "charlie_comments_own_gift" do
    assert_notifications :method => __method__,
                         :notifications => [] do
      # setup - charlie comments his own gift - don't send any notifications
      comment_for_charlies_gift charlie, "don't send any notifications"
    end # assert_notifications
  end # charlie_comments_own_gift

  test "one_user_comments_charlies_gift" do
    charlie = users(:charlie)
    # should send one notification to charlie
    assert_notifications :method => __method__,
                         :notifications => [{:to_user_id => charlie.user_id,
                                             :noti_key => 'new_comment_giver_1_v1',
                                             :no_users => 1,
                                             :usernames => ["Sandra Q"]
                                            }]  do
      # setup - one user u1/sandra comments charlies gift
      comment_for_charlies_gift u1_sandra, 'send notification to charlie'
    end # assert_notifications
  end # one_user_comments_charlies_gift

  test "two_users_comment_charlies_gift" do
    u1 = users(:sandra)
    # assert two notifications when u2/karen comments charlies gift
    # 1) notification to gift owner charlie
    # 2) notification to other users (sandra) that have commented charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["Karen S", "Sandra Q"]
                             },
                             # 2) notification to other users (sandra) that have commented charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test
      # two users u1/sandra and u2/karen comment charlies gift
      comment_for_charlies_gift u1_sandra, 'send notification to charlie'
      comment_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
    end # assert_notifications
  end # two_users_comment_charlies_gift

  test "three_users_comment_charlies_gift" do
    # assert three notifications when u3/david comments charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra that also has commented charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Karen S"]
                             },
                             # 3) notification to u2/karen that also has commented charlies gift
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             }]) do
      # setup context for this test
      # three users - u1/sandra, u2/karen and u3/david comment charlies gift
      comment_for_charlies_gift u1_sandra, 'send notification to charlie'
      comment_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      comment_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
    end # assert_notifications
  end # three_users_comment_charlies_gift


  test "four_users_comment_charlies_gift" do
    # assert four notifications when u4/dick comments charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie. 4 users have commented charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_n_v1',
                              :no_users => 4,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra. 3 other users have also commented charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Dick B", "Karen S"]
                             },
                             # 3) notification to u2/karen. 2 other users have also commented charlies gift
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 4) notification to u3/david. 1 other user has also commented charlies gift
                             {:to_user_id => u3_david.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             }]) do
      # setup context for this test
      # four users u1/sandra, u2/karen, u3/david and u4/dick comment charlies gift
      comment_for_charlies_gift u1_sandra, 'send notification to charlie'
      comment_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      comment_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
      comment_for_charlies_gift u4_dick, 'send notification to charlie, u1/sandra, u2/karen and u3/david'
    end # assert_notifications
  end # four_users_comment_charlies_gift


  #
  # test notifications for new proposals
  #



  test "one_proposal_for_charlies_gift_a" do
    # assert one notification when sandra make a proposal for charlies gift
    assert_notifications :method => __method__,
                         :notifications => [
                             # 1) notification to charlie. One user u1/sandra has commented charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                            }] do
      # setup - one user u1/sandra make a new proposal for charlies gift
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
    end # assert_notification
  end # one_user_comments_charlies_gift_a

  test "one_proposal_for_charlies_gift_b" do
    # assert one notification when sandra make two proposals for charlies gift
    assert_notifications :method => __method__,
                         :notifications => [{:to_user_id => charlie.user_id,
                                             :noti_key => 'new_proposal_giver_1_v1',
                                             :no_users => 1,
                                             :usernames => ["Sandra Q"]
                                            }]       do
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
    end
  end # one_proposal_for_charlies_gift_b



  test "two_proposals_for_charlies_gift" do
    # assert two notifications when u2/karen comments charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["Karen S", "Sandra Q"]
                             },
                             # 2) notification to one other user (sandra) that also has a proposal for charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test - u1/sandra and u2/karen proposals for charlies gift
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
    end
  end # two_proposals_for_charlies_gift

  def three_proposals_for_charlies_gift
    # assert three notifications when u3/david comments charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie - three users with new proposals
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra - two users with proposals (u2/karen and u3/david)
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Karen S"]
                             },
                             # 3) notification to u2/david - one user with proposal (u3/david)
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             }  ]) do
      # setup context for this test
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      proposal_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
    end
  end # three_proposals_for_charlies_gift

  test "three_proposals_for_charlies_gift" do
    three_proposals_for_charlies_gift
  end # three_proposals_for_charlies_gift

  def four_proposals_for_charlies_gift
    charlie = users(:charlie)
    u1 = users(:sandra) # proposal
    u2 = users(:karen)  # proposal
    u3 = users(:david)  # proposal
    u4 = users(:dick)   # proposal
    gift = gifts(:charlie_gift_a)
    # four notifications when u4/dick comments charlies gift
    # 1) notification to gift owner charlie - four users with new proposals
    # 2) notification to u1/sandra - three users with proposals (u2/karen, u3/david and u4/dick)
    # 3) notification to u2/karen - two users with proposal (u3/david and u4/dick)
    # 4) notification to u3/david - one user u4/david with proposal
    assert_notifications(:gift => gift,
                         :user => u4,
                         :comment => 'send notification to charlie, sandra, karen and dick',
                         :new_deal_yn => 'Y',
                         :method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie - four users with new proposals
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_n_v1',
                              :no_users => 4,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra - three users with proposals (u2/karen, u3/david and u4/dick)
                             {:to_user_id => u1.user_id,
                              :noti_key => 'new_proposal_giver_other_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Dick B", "Karen S"]
                             },
                             # 3) notification to u2/karen - two users with proposal (u3/david and u4/dick)
                             {:to_user_id => u2.user_id,
                              :noti_key => 'new_proposal_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 4) notification to u3/david - one user u4/david with proposal
                             {:to_user_id => u3.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             } ]) do
      # setup context for this test
      three_proposals_for_charlies_gift
    end
  end # four_proposals_for_charlies_gift

  test "four_proposals_for_charlies_gift" do
    four_proposals_for_charlies_gift
  end # four_proposals_for_charlies_gift


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
      comment_for_charlies_gift users(:sandra), 'send notification to charlie'
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
      proposal_for_charlies_gift users(:sandra), 'send notification to charlie'
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
      proposal_for_charlies_gift users(:sandra), 'send notification to charlie'
      proposal_for_charlies_gift users(:karen), 'send notification to charlie and u1/sandra'
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

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
    # test notifications. sort notifications by 1) user_id and 2) noti_key before compare
    expected_notifications = notifications.sort do |a, b|
      if a[:to_user_id] == b[:to_user_id]
        a[:noti_key] <=> b[:noti_key]
      else
        a[:to_user_id] <=> b[:to_user_id]
      end
    end # sort
    found_notifications = Notification.last(expected_no_notifications).collect do |n|
      {:to_user_id => n.to_user_id,
       :to_user_short_user_name => n.to_user.short_user_name,
       :noti_key => n.noti_key,
       :no_users => n.noti_options[:no_users],
       :usernames => [n.noti_options[:username1],
                      n.noti_options[:username2],
                      n.noti_options[:username3]].find_all { |un| un }.sort
      }
    end.sort do |a, b|
      if a[:to_user_id] == b[:to_user_id]
        a[:noti_key] <=> b[:noti_key]
      else
        a[:to_user_id] <=> b[:to_user_id]
      end
    end
    0.upto(expected_no_notifications-1) do |i|
      [:to_user_id, :noti_key, :no_users].each do |name|
        # puts"check #{name}: expected #{expected_notifications[i][name]}. Found #{found_notifications[i][name]}"
        assert (expected_notifications[i][name] == found_notifications[i][name]),
               "#{method}. Notification #{i+1} to #{found_notifications[i][:to_user_short_user_name]}. Field #{name}. " +
                   "Expected #{expected_notifications[i][name]}. " +
                   "Found #{found_notifications[i][name]}"
      end # each name
      assert (expected_notifications[i][:usernames].size == found_notifications[i][:usernames].size),
             "#{method}. Notification #{i+1} to #{found_notifications[i][:to_user_short_user_name]}. Field usernames. " +
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

  test "three_proposals_for_charlies_gift" do
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

  test "four_proposals_for_charlies_gift" do
    # assert four notifications when u4/dick comments charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie - four users with new proposals
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_n_v1',
                              :no_users => 4,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra - three users with proposals (u2/karen, u3/david and u4/dick)
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Dick B", "Karen S"]
                             },
                             # 3) notification to u2/karen - two users with proposal (u3/david and u4/dick)
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_proposal_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 4) notification to u3/david - one user u4/david with proposal
                             {:to_user_id => u3_david.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             } ]) do
      # setup context for this test
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      proposal_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
      proposal_for_charlies_gift u4_dick, 'send notification to charlie, u1/sandra, u2/karen and u3/david'
    end # assert_notifications
  end # four_proposals_for_charlies_gift


  #
  # test mix of new comments and new proposals
  #

  test "one_comment_and_one_proposal_for_charlies_gift" do
    # assert three notifications when u2/karen create a proposal for charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to gift owner charlie - u1/sandra has commented charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]},
                             # 2) notification to gift owner charlie - u2/karen has a proposal for charlies gift
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]},
                             # 3) notification to u1/sandra that u2/karen has a proposal for charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test
      comment_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
    end # assert_notifications
  end # one_comment_and_one_proposal_for_charlies_gift

  test "one_proposal_and_one_comment_for_charlies_gift" do
    # assert three notifications when u2/karen create a proposal for charlies gift
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) new proposal notification to charlie (u1/sandra)
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             },
                             # 2) new comment notification to charlie (u2/karen)
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 3) notification to u1/sandra) that u2/karen has commented charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }]) do
      # setup context for this test - u1/sandra has made a proposal for charlies gift
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      comment_for_charlies_gift u2_karen, 'send notifications to charlie and u1/sandra'
    end # assert_notifications
  end # one_proposal_and_one_comment_for_charlies_gift

  test "two_proposals_and_one_comment_for_charlies_gift" do
    # assert five notifications
    assert_notifications(:method => __method__,
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
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 4) notification to u1/sandra - one other user u3/david with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             },
                             # 5) notification to u2/karen - one user u3/david with comment
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             }  ]) do
      # setup context for this test
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      comment_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
    end # assert_notifications
  end # two_proposals_and_one_comment_for_charlies_gift

  test "two_proposals_and_two_comments_for_charlies_gift" do
    # assert sex notifications:
    assert_notifications(:method => __method__,
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
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 4) notification to u1/sandra - two other users u3/david and u4/dick with comments
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 5) notification to u2/karen - two users u3/david and u4/dick with comments
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Dick B"]
                             },
                             # 6) notification to u3/david - one user with comment
                             {:to_user_id => u3_david.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Dick B"]
                             } ]) do
      # setup context for this test
      proposal_for_charlies_gift u1_sandra, 'send notification to charlie'
      proposal_for_charlies_gift u2_karen, 'send notification to charlie and u1/sandra'
      comment_for_charlies_gift u3_david, 'send notification to charlie, u1/sandra and u2/karen'
      comment_for_charlies_gift u4_dick, 'send notification to charlie, u1/sandra, u2/karen and u3/david'
    end # assert_notifications
  end # two_proposals_and_two_comments_for_charlies_gift


  #
  # test delete comments
  #

  test "create_and_delete_one_comment" do
    # assert no notifications
    assert_notifications(:method => __method__,
                         :notifications => [])  do
      # setup context for this test
      c = comment_for_charlies_gift u1_sandra, 'send notification to charlie'
      c.destroy!
    end # assert_notifications
  end # create_and_delete_one_comment

  test "create_and_delete_comments_a" do
    # assert two notifications
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u2/karen with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 2) notification to u1/sandra that u2/karen also has commented charlies gift
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             } ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = comment_for_charlies_gift u2_karen, 'n1: change notification to charlie and n2: send notification to u1/sandra'
      c1.destroy! # sandra deletes c1 - n1: change notification to charlie (ok) and n2: unchanged notification to sandra
    end # assert_notifications
  end # create_and_delete_comments_a

  test "create_and_delete_comments_b" do
    # assert one notification to charlie
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u2/karen with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }
                         ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = comment_for_charlies_gift u2_karen, 'n1: change notification to charlie and n2: send notification to u1/sandra'
      c2.destroy! # n1: change notification to charlie (ok) and n2: delete notification to u1/sandra (missing)
    end # assert_notifications
  end # create_and_delete_comments_b

  test "create_and_delete_comments_c" do
    # assert three notifications
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - two users u1/sandra and u3/david with comments
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Sandra Q"]
                             },
                             # 2) notification to sandra - one user u3/david with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             },
                             # 3) notification to karen - one user u3/david with comment
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             } ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = comment_for_charlies_gift u2_karen, 'n1: change notification to charlie and n2: send notification to u1/sandra'
      c3 = comment_for_charlies_gift u3_david, 'n1: change notification to charlie, n2: change notification to u1/sandra and n3: send notification to u2/karen'
      c2.destroy! # karen deletes her comment - n1: change notification to charlie, n2: change notification to u1/sandra and n3: unchanged notification to u2/karen
    end # assert_notifications
  end # create_and_delete_comments_c


  #
  # Follow / stop follow
  #

  test "comment_and_stop_follow_a" do
    # assert one notification to charlie
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - two users u1/sandra and u3/david with comments
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_2_v1',
                              :no_users => 2,
                              :usernames => ["David M", "Sandra Q"]
                             } ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      # sandra - stop following gift comments
      gl = GiftLike.where("user_id = ? and gift_id = ?", u1_sandra.user_id, gifts(:charlie_gift_a).gift_id).first
      gl.follow = 'N'
      assert gl.save
      c3 = comment_for_charlies_gift u3_david, 'n1: change notification to charlie, n2: change notification to u1/sandra and n3: send notification to u2/karen'
    end # assert_notifications
  end # comment_and_stop_follow_a

  test "comment_and_stop_follow_b" do
    # assert three notifications
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - three users u1/sandra, u2/karen and u3/david with comments
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_3_v1',
                              :no_users => 3,
                              :usernames => ["David M", "Karen S", "Sandra Q"]
                             },
                             # 2) notification to u1/sandra - one other user u2/karen with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 3) notification to u2/karen - one other user u3/david with comment
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             },
                         ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = comment_for_charlies_gift u2_karen, 'n1: change notification to charlie and n2: send notification to u1/sandra'
      # sandra - stop following gift comments
      gl = GiftLike.where("user_id = ? and gift_id = ?", u1_sandra.user_id, gifts(:charlie_gift_a).gift_id).first
      gl.follow = 'N'
      assert gl.save
      c3 = comment_for_charlies_gift u3_david, 'n1: change notification to charlie, n2: change notification to u1/sandra and n3: send notification to u2/karen'
    end # assert_notifications
  end # comment_and_stop_follow_b

  test "comment_and_stop_follow_c" do
    # assert three notifications
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u1/sandra with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             },
                             # 2) notification to u1/sandra - one other user u2/karen with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 3) notification to u2/karen - one other user u3/david with comment
                             {:to_user_id => u2_karen.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["David M"]
                             } ])  do
      # setup context for this test
      c1 = comment_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      # charlie - stop following gift comments
      gl = GiftLike.new
      gl.gift_id = gifts(:charlie_gift_a).gift_id
      gl.user_id = charlie.user_id
      gl.like = 'N'
      gl.show = 'Y'
      gl.follow = 'N'
      assert gl.save
      c2 = comment_for_charlies_gift u2_karen, 'n1: change notification to charlie and n2: send notification to u1/sandra'
      # sandra - stop following gift comments
      gl = GiftLike.where("user_id = ? and gift_id = ?", u1_sandra.user_id, gifts(:charlie_gift_a).gift_id).first
      gl.follow = 'N'
      assert gl.save
      c3 = comment_for_charlies_gift u3_david, 'n1: change notification to charlie, n2: change notification to u1/sandra and n3: send notification to u2/karen'
    end # assert_notifications
  end # comment_and_stop_follow_c

  test "follow_gift" do
    # assert two notifications
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u2/karen with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 2) notification to u1/sandra - one user u2/karen with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             } ])  do
      # setup context for this test
      # u1/sandra follows charlies gift
      gl = GiftLike.new
      gl.gift_id = gifts(:charlie_gift_a).gift_id
      gl.user_id = u1_sandra.user_id
      gl.like = 'N'
      gl.show = 'Y'
      gl.follow = 'Y'
      assert gl.save
      c1 = comment_for_charlies_gift u2_karen, 'notifications to charlie and sandra'
    end # assert_notifications
  end # follow_gift


  #
  # cancel proposal tests
  #

  test "cancel_proposal_a" do
    # assert one notification
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u1/sandra with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             }
                         ])  do
      # setup context for this test
      c1 = proposal_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c1.new_deal_yn = nil
      c1.save!
    end # assert_notifications
  end # cancel_proposal_a

  test "cancel_proposal_b" do
    # assert three notification
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u1/sandra with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             },
                             # 2) notification to charlie - one user u2/karen with proposal
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 3) notification to u1/sandra - one user u2/karen with proposal
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_proposal_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }
                         ])  do
      # setup context for this test
      c1 = proposal_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = proposal_for_charlies_gift u2_karen, 'n1: change notification to charlie, n2: send notification to u1/sandra'
      # u1/sandra cancels new proposal -> 2 notifications to charlie + unchange notification to u1/sandra
      c1.new_deal_yn = nil
      c1.save!
    end # assert_notifications
  end # cancel_proposal_b

  test "cancel_proposal_c" do
    # assert three notification
    assert_notifications(:method => __method__,
                         :notifications => [
                             # 1) notification to charlie - one user u1/sandra with proposal
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_proposal_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Sandra Q"]
                             },
                             # 2) notification to charlie - one user u2/karen with comment
                             {:to_user_id => charlie.user_id,
                              :noti_key => 'new_comment_giver_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             },
                             # 3) notification to u1/sandra - one user u2/karen with comment
                             {:to_user_id => u1_sandra.user_id,
                              :noti_key => 'new_comment_giver_other_1_v1',
                              :no_users => 1,
                              :usernames => ["Karen S"]
                             }
                         ])  do
      # setup context for this test
      c1 = proposal_for_charlies_gift u1_sandra, 'n1: send notification to charlie'
      c2 = proposal_for_charlies_gift u2_karen, 'n1: change notification to charlie, n2: send notification to u1/sandra'
      # u2/karen cancels new proposal -> 2 notifications to charlie + change notification to u1/sandra
      c2.new_deal_yn = nil
      c2.save!
    end # assert_notifications
  end # cancel_proposal_c

end # CommentTest

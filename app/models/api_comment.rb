class ApiComment < ActiveRecord::Base

  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id
  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :comment, :class_name => 'Comment', :primary_key => :comment_id, :foreign_key => :comment_id

  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments

  def table_row_id
    "gift-#{gift.id}-comment-#{id}"
  end # table_row_id


  # helpers used in comments/comment_status partial - show/hide comment links

  # display cancel new deal check box?
  # only for new not accepted/rejected agreement proposals
  def show_cancel_new_deal_link? (users)
    return false unless comment.new_deal_yn == 'Y'
    return false if comment.accepted_yn
    return false unless users.find { |user| user_id == user.user_id }
    return false if gift.direction == 'both'
    true
  end # show_cancel_new_deal_link?

  def show_accept_new_deal_link? (users)
    return false unless comment.new_deal_yn == 'Y'
    return false if comment.accepted_yn
    return false if users.find { |user| user_id == user.user_id }
    return false if gift.direction == 'both'
    gift.api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      return true if [api_gift.user_id_receiver, api_gift.user_id_giver].index(user.user_id)
    end
    false
  end # show_accept_new_deal_link?

  def show_reject_new_deal_link? (users)
    show_accept_new_deal_link?(users)
  end # show_reject_new_deal_link?

  def show_delete_comment_link?(users)
    return false unless users.class == Array and users.length > 0
    return false if users.size == 1 and users.first.dummy_user?
    gift.api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      next unless user
      return true if [api_gift.user_id_receiver, api_gift.user_id_giver].index(user.user_id)
    end
    false
  end # show_delete_comment_link?




end

# encoding: utf-8
module GiftHelper

  # show like/unlike link for gift under gift text and picture
  def link_to_gift_like_unlike (gift)
    if gift.show_like_gift_link?(@users)
      key, path = '.like_gift', util_like_gift_path(:gift_id => gift.id)
    else
      key, path = '.unlike_gift', util_unlike_gift_path(:gift_id => gift.id)
    end
    link_to t(key), path, :id => "gift-#{gift.id}-like-unlike-link", :class => "gift-action-link", :remote => true, :method => :post
  end # link_to_gift_like_unlike

  # show follow/do not follow link for gift under gift text and picture
  # default is to follow gift as giver, receiver or commenter
  def link_to_gift_follow_unfollow (gift)
    if gift.show_follow_gift_link?(@users)
      key, path = '.follow_gift', util_follow_gift_path(:gift_id => gift.id)
    else
      key, path = '.unfollow_gift', util_unfollow_gift_path(:gift_id => gift.id)
    end
    link_to t(key), path, :id => "gift-#{gift.id}-follow-unfollow-link", :class => "gift-action-link", :remote => true, :method => :post
  end # link_to_gift_follow_unfollow

  def link_to_gift_hide (gift)
    link_to t('.hide_gift'), util_hide_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-hide-link", :class => "gift-action-link", :remote => true, :method => :post, :data => { :confirm => t('.confirm_hide_gift') }
  end

  # it could be nice with a popup dialog box with three choices. a) hide and keep balance, b) destroy and update balance, c) cancel
  # but no build in JS function for this
  # must send a/b choice to util/delete_gift. must cancel require on c
  # some maybe useful links:
  # - http://www.pjmccormick.com/nicer-rails-confirm-dialogs-and-not-just-delete-methods
  # - http://stackoverflow.com/questions/7435859/custom-rails-confirm-box-with-rails-confirm-override
  # - http://rors.org/demos/custom-confirm-in-rails
  def link_to_delete_gift (gift)
    # confirm delete texts
    # - confirm_delete_gift_1 if delete gift effects user balance
    # - confirm_delete_gift_2 if delete gift does not effect user balance
    confirm_delete_gift_options = { :price => gift.price, :currency => gift.currency }
    if gift.received_at and gift.price and gift.price != 0.0
      keyno = 1
      confirm_delete_gift_options[:user_name] = gift.user_id_giver == @user.user_id ? gift.receiver.short_user_name : gift.giver.short_user_name
    else
      keyno = 2
    end
    confirm_delete_gift_key = ".confirm_delete_gift_#{keyno}"
    link_to t('.delete_gift'), util_delete_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-delete-link", :class => "gift-action-link", :remote => true, :method => :post, :data => { :confirm => t(confirm_delete_gift_key, confirm_delete_gift_options) }
  end # link_to_delete_gift


  def link_to_cancel_new_deal (comment)
    link_to t('.cancel_new_deal'), util_cancel_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-cancel-link", :class => 'comment-action-link', :remote => true, :method => :post, :data => { :confirm => t('.confirm_cancel_new_deal') }
  end

  def link_to_accept_new_deal (comment)
    link_to t('.accept_new_deal'), util_accept_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-accept-link", :class => 'comment-action-link', :remote => true, :method => :post, :data => { :confirm => t('.confirm_accept_new_deal') }
  end

  def link_to_reject_new_deal (comment)
    link_to t('.reject_new_deal'), util_reject_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-reject-link", :class => 'comment-action-link', :remote => true, :method => :post, :data => { :confirm => t('.confirm_reject_new_deal') }
  end

  def link_to_delete_comment (comment)
    # the giftid param is used as extra information in url for comment-action-link click event
    # cleanup any old ajax error messages before new ajax delete comment request
    # see $(".comment-action-link").bind("click" in my.js
    link_to t('.delete_comment'), comment_path(comment.id, :giftid => comment.gift.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-delete-link", :class => 'comment-action-link', :remote => true, :method => :delete, :data => { :confirm => t('.confirm_delete_comment') }
  end

end

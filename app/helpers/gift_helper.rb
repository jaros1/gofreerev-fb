# encoding: utf-8
module GiftHelper

  # link to request for status_update priv. (facebook)
  def auth_post_gift_url
    unless @user
      puts 'auth_post_gift_url: @user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - request for status_update priv
        oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, 'http://localhost/gifts/')
        state = session[:state] = String.generate_random_string(30)
        url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => state)
        puts "auth_post_gift_url: url2 = #{url}"
        return url
      else
        ''
    end
  end # auth_post_gift_url

  # link to request for status_update priv. (facebook)
  def auth_read_stream_url
    unless @user
      puts 'auth_read_stream_url: @user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - request for status_update priv
        oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, SITE_URL + 'gifts/')
        state = session[:state] = String.generate_random_string(30)
        url = oauth.url_for_oauth_code(:permissions => 'read_stream', :state => state)
        puts "auth_read_stream_url: url2 = #{url}"
        return url
      else
        ''
    end
  end # auth_read_stream_url

  # show like/unlike link for gift under gift text and picture
  def link_to_gift_like_unlike (gift)
    # check like status
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    like = gl.like if gl and %w(Y N).index(gl.like)
    like = 'N' unless like
    if like == 'N'
      link_to my_t('.like_gift'), util_like_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-like-unlike-link", :remote => true, :method => :post
    else
      link_to my_t('.unlike_gift'), util_unlike_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-like-unlike-link", :remote => true, :method => :post
    end
  end # link_to_gift_like_unlike

  # show follow/do not follow link for gift under gift text and picture
  # default is to follow gift as giver, receiver or commenter
  def link_to_gift_follow_unfollow (gift)
    # check like status
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    follow = gl.follow if gl
    if !follow
      if [gift.user_id_giver, gift.user_id_receiver].index(@user.user_id)
        follow = 'Y'
      else
        c = Comment.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
        follow = c ? 'Y' : 'N'
      end
    end
    if follow == 'N'
      link_to my_t('.follow_gift'), util_follow_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-follow-unfollow-link", :remote => true, :method => :post
    else
      link_to my_t('.unfollow_gift'), util_unfollow_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-follow-unfollow-link", :remote => true, :method => :post
    end
  end # link_to_gift_follow_unfollow

  def link_to_gift_hide (gift)
    link_to my_t('.hide_gift'), util_hide_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-hide-link", :remote => true, :method => :post, :data => { :confirm => my_t('.confirm_hide_gift') }
  end

  # it could be nice with a popup dialog box with three choices. a) hide and keep balance, b) destroy and update balance, c) cancel
  # but no build in JS function for this
  # must send a/b choice to util/delete_gift. must cancel require on c
  # some maybe useful links:
  # - http://www.pjmccormick.com/nicer-rails-confirm-dialogs-and-not-just-delete-methods
  # - http://stackoverflow.com/questions/7435859/custom-rails-confirm-box-with-rails-confirm-override
  # - http://rors.org/demos/custom-confirm-in-rails
  def link_to_delete_gift (gift)
    return nil unless [gift.user_id_giver, gift.user_id_receiver].index(@user.user_id)
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
    link_to my_t('.delete_gift'), util_delete_gift_path(:gift_id => gift.id), :id => "gift-#{gift.id}-delete-link", :remote => true, :method => :post, :data => { :confirm => my_t(confirm_delete_gift_key, confirm_delete_gift_options) }
  end # link_to_delete_gift

  def link_to_cancel_new_deal (comment)
    link_to my_t('.cancel_new_deal'), util_cancel_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-cancel-link", :remote => true, :method => :post, :data => { :confirm => my_t('.confirm_cancel_new_deal') }
  end

  def link_to_accept_new_deal (comment)
    link_to my_t('.accept_new_deal'), util_accept_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-accept-link", :remote => true, :method => :post, :data => { :confirm => my_t('.confirm_accept_new_deal') }
  end

  def link_to_reject_new_deal (comment)
    link_to my_t('.reject_new_deal'), util_reject_new_deal_path(:comment_id => comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-reject-link", :remote => true, :method => :post, :data => { :confirm => my_t('.confirm_reject_new_deal') }
  end

  def link_to_delete_comment (comment)
    link_to my_t('.delete_comment'), comment_path(comment.id), :id => "gift-#{comment.gift.id}-comment-#{comment.id}-delete-link", :remote => true, :method => :delete, :data => { :confirm => my_t('.confirm_delete_comment') }
  end

end

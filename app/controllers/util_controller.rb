require 'google/api_client'
require 'linkedin'

class UtilController < ApplicationController

  # update new message count in menu line in page header
  # called from hidden check-new-messages-link link in page header once every 15, 60 or 300 seconds
  # new_message_count is also ajax injecting gifts and comments into gifts pages
  # Parameters: {"request_fullpath"=>"/gifts", "newest_gift_id"=>"275", "newest_status_update_at"=>"417"}
  # - request_fullpath is request path for current page where ajax request was send from
  # - newest_gift_id is newest gift id when page was loaded or newest gift id in last new_messages_count request for this session
  # - newest_status_update_at is newest status_update_at when page was loaded or newest status_update_at in last new_message_count request for this session
  def new_messages_count
    if User.dummy_users?(@users)
      puts2log  "ignoring not logged in user"
      render :nothing => true
      return
    end
    # cleanup - destroy old delete marked gifts
    # gift was marked as deleted in util/delete_gift request
    # gift has been ajax removed from  gifts pages for other sessions in previous util/new_message_count requests
    # now is the time to destroy old delete marked gifts
    userids = @users.collect { |user| user.user_id }
    Gift.where('(api_gifts.user_id_giver in (?) or api_gifts.user_id_receiver in (?)) and deleted_at is not null and deleted_at < ?',
               userids, userids, 10.minutes.ago).includes(:api_gifts).references(:api_gifts).each do |g|
      g.destroy
    end
    # get params
    old_newest_gift_id = params[:newest_gift_id].to_i
    old_newest_status_update_at = params[:newest_status_update_at].to_i
    # return new messages count
    count = User.inbox_new_notifications(@users) || 0
    @new_messages_count = count if count > 0
    # return new comments
    # return new comments and comments with changed status (new deal proposal cancelled or rejected or deleted comment)
    if  params[:request_fullpath] == '/gifts' or params[:request_fullpath] =~ /^\/gifts\/([0-9]+)$/
      # find comments to ajax insert in gifts/index or gifts/show pages
      # puts2log  "find comments to ajax insert in gifts/index or gifts/show pages"
      # two sources for comments to ajax insert into gifts table
      # source 1 - comments selected to be ajax inserted for this user - todo: check where AjaxCommment is initialized
      com_ids = AjaxComment.where("user_id = ?", @user.user_id).collect { |ac| ac.comment_id }
      com_ids.push('x') if com_ids.size == 0
      # puts2log  "com_ids.length = #{com_ids.length}"
      comments1 = Comment.includes(:gift).where('comment_id in (?)',com_ids)
      # source 2 - all visible gifts, but only comments with status_update_at > :newest_status_update_at
      friends = []
      @users.each do |user|
        friends = friends + user.app_friends.collect { |u| u.user_id_receiver }
        friends.push(@user.user_id)
      end
      gifts2 = Gift.where('(api_gifts.user_id_giver in (?) or api_gifts.user_id_receiver in (?)) and ' +
                           'gifts.deleted_at is null and ' +
                           'comments.status_update_at > ?',
                             friends, friends, old_newest_status_update_at).includes(:comments, :api_gifts).references(:api_gifts)
      comments2 = []
      gifts2.each do |gift|
        comments2 = comments2 + gift.comments.find_all { |comment| comment.status_update_at > old_newest_status_update_at}
      end
      @comments = (comments1 + comments2).uniq
      if @comments.size > 0 and params[:request_fullpath] =~ /^\/gifts\/([0-9]+)$/
        # gifts/show/<nnn> page - return only ajax comments for actual gift (id=<nnn>)
        # puts2log  "new comments before gift_id filter = #{@comments.length}"
        @comments = @comments.find_all { |c| c.gift.id.to_s == $1 }
        # puts2log  "new comments after gift_id filter = #{@comments.length}"
      end
      # do not return comment just created by current user (problem with extra flash for new comments)
      @comments = @comments.delete_if do |c|
        (c.user_id == @user.user_id and c.created_at > 30.seconds.ago and c.created_at == c.updated_at)
      end
      # remove comments for hidden gifts - that is gifts user has selected not to see
      if @comments.size > 0
        old_size = @comments.size
        giftids = @comments.collect { |c| c.gift_id }
        hide_giftids = GiftLike.where("user_id = ? and gift_id in (?)", @user.user_id, giftids).find_all { |gl| gl.show == 'N'}.collect { |gl| gl.gift_id }
        # remove comments for hidden gifts
        @comments = @comments.find_all { |c| !hide_giftids.index(c.gift_id) } if hide_giftids.length > 0
        new_size = @comments.size
        # puts2log  "#{old_size-new_size} comments for hidden gifts was removed" if old_size != new_size
      end
      @comments = nil if @comments.size == 0
      # empty AjaxComment buffer - only return ajax comments once
      AjaxComment.destroy_all(:user_id => @user.user_id)
    end
    # return newly created gifts. Input newest_gift_id when user page was loaded or newest gift_id in last new_messages_count request
    # return newly updated (or deleted) gifts. Input newest_status_update_at when user page was loaded or newest_status_update_at in last new_message:count request
    # 0 if not called from gifts/index page
    new_newest_gift_id = Gift.last.id if old_newest_gift_id > 0
    new_newest_status_update_at = Sequence.status_update_at if old_newest_status_update_at > 0
    if old_newest_gift_id > 0 and ( new_newest_gift_id > old_newest_gift_id or new_newest_status_update_at > old_newest_status_update_at )
      # called from gifts/index page and new gifts created since page load or last new_messages_count request
      # return new newest_gift_id value and any new gifts visible to user
      @new_newest_gift_id = new_newest_gift_id
      @new_newest_status_update_at = new_newest_status_update_at
      @api_gifts = User.api_gifts(@users, old_newest_gift_id, old_newest_status_update_at, true) # include delete marked gifts
      @api_gifts = nil if @api_gifts.length == 0
    end
    # remove any ajax comments for gifts in gifts array - that is gifts that will be ajax inserted or replaced in gifts html table
    if @comments and @api_gifts and @comments.size > 0 and @api_gifts.size > 0
      # puts2log  "remove any comments that is included in gifts"
      # puts2log  "old @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
      @comments = @comments.delete_if { |c| @api_gifts.find_all { |g| c.gift_id == g.gift_id }.first }
      @comments = nil if @comments.size == 0
      # puts2log  "new @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    end
    puts2log  "@gifts.size = #{@api_gifts.size}, gifts = " + @api_gifts.collect { |g| g.id }.join(', ') if @api_gifts
    puts2log  "@comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    puts2log  "@new_newest_gift_id = #{@new_newest_gift_id}"
    puts2log  "@new_newest_status_update_at = #{@new_newest_status_update_at}"
    respond_to do |format|
      format.html {}
      format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end
  end # new_messages_count

  # get array of gift ids with invalid picture url
  # temp api url can have changed / picture may have been deleted
  # Parameters: {"gifts"=>{"ids"=>"161"}}
  def missing_api_picture_urls
    render :layout => false
    return unless params.has_key?("api_gifts")
    return unless params[:api_gifts].has_key?(:ids)
    return if  params[:api_gifts][:ids] == ''
    ids = params[:api_gifts][:ids].split(',')
    puts2log  "ids = #{ids}"
    api_gifts = ApiGift.where("id in (?)", ids)

    # set error timestamp
    api_gifts.each do |api_gift|
      puts2log  "url = #{api_gift.api_picture_url}"
      api_gift.api_picture_url_on_error_at = Time.now
      api_gift.save!
    end # each

    # get new picture urls
    # todo: 1 - catch deleted picture / status
    #       Koala::Facebook::ClientError (type: GraphMethodException, code: 100, message: Unsupported get request. [HTTP 400]):
    # todo: 2 - maybe app friend is not allowed to see picture in facebook
    # todo: 3 - max request picture url once every hour
    # todo: 4 - gifts/index - should check for error marked pictured and fix urls that couldn't be fixed in here (see 2)
    access_token = session[:access_token]
    tokens = session[:tokens]
    return unless tokens
    api_gifts.each do |api_gift|
      next if api_gift.picture == 'N' or api_gift.deleted_at_api == 'Y'
      access_token = tokens[api_gift.provider]
      next unless access_token
      # get new picture url from API
      begin
        # todo: most use api_gift, not gift
        api_gift.api_picture_url = api_gift.get_facebook_post(:access_token => access_token, :field => 'full_picture')
      rescue ApiPostNotFoundException => e
        # identical api error response if picture is deleted or if user is not allowed to see picture
        user_id_created_by = api_gift.api_gift_id.split('_').first + '/facebook'
        if @user.user_id != user_id_created_by
          # picture may have or may not have been deleted in facebook.
          # current user may not have permission to read picture on wall
          # keep api_picture_url_on_error_at timestamp and continue
          # the picture url will be checked by picture owner at a later time
          puts2log  "Could not get new picture url. Could be deleted picture. Could be api permission problem. Keep error and let owner check picture url at a later time"
          next
        end # if
            # picture was not found with picture owner login
            # it could be a facebook permission problem (app priv has been removed) but most likely the picture has been deleted
            # keep api_picture_url_on_error_at so that we known about when the picture was been deleted
            # gifts in app is not deleted automatically. Could affect the balance. Could be connected with other gifts.
            # this allow users to cleanup their FB profile without destroying data in app
        puts2log  "Gift has been deleted on #{@user.api_name_without_brackets}. Keep in #{APP_NAME} as the gift could have been used in balance and in connected gifts (todo)"
        api_gift.picture = 'N'
        api_gift.api_picture_url = nil
        api_gift.api_picture_url_updated_at = nil
        api_gift.deleted_at_api = 'Y'
        api_gift.save!
        next
      end # rescue
      # save new picture url from api
      api_gift.api_picture_url_updated_at = Time.now
      api_gift.api_picture_url_on_error_at = nil
      api_gift.save!
    end # each

  end # missing_api_picture_urls


  #
  # gift link ajax methods
  #

  def like_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if gl
      gl.like = 'Y'
    else
      gl = GiftLike.new
      gl.user_id = @user.user_id
      gl.gift_id = gift.gift_id
      gl.like = 'Y'
      gl.show = 'Y'
      gl.follow = nil
    end
    gl.save!
    # change link
    @gift_link_id = "gift-#{gift.id}-like-unlike-link"
    @gift_link_href = util_unlike_gift_path(:gift_id => gift.id)
    @gift_link_text = t('gifts.api_gift.unlike_gift')
  end # like_gift

  def unlike_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if !gl or gl.like != 'Y'
      puts2log  "Non previous like was found for user #{@user.short_user_name} and gift id #{gift_id}"
      return
    end
    gl.like = 'N' ;
    gl.save!
    # change link
    @gift_link_id = "gift-#{gift.id}-like-unlike-link"
    @gift_link_href = util_like_gift_path(:gift_id => gift.id)
    @gift_link_text = t('gifts.api_gift.like_gift')
  end # unlike_gift

  def follow_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if gl
      gl.follow = 'Y'
    else
      gl = GiftLike.new
      gl.user_id = @user.user_id
      gl.gift_id = gift.gift_id
      gl.like = 'N'
      gl.follow = 'Y'
      gl.show = 'Y'
    end
    gl.save!
    # change link
    @gift_link_id = "gift-#{gift.id}-follow-unfollow-link"
    @gift_link_href = util_unfollow_gift_path(:gift_id => gift.id)
    @gift_link_text = t('gifts.api_gift.unfollow_gift')
  end # follow_gift

  def unfollow_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if !gl
      gl = GiftLike.new
      gl.user_id = @user.user_id
      gl.gift_id = gift.gift_id
      gl.like = 'N'
      gl.show = 'Y'
    end
    gl.follow = 'N'
    gl.save!
    # change link
    @gift_link_id = "gift-#{gift.id}-follow-unfollow-link"
    @gift_link_href = util_follow_gift_path(:gift_id => gift.id)
    @gift_link_text = t('gifts.api_gift.follow_gift')
  end # unfollow_gift

  def hide_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if gl
      gl.show = 'N'
    else
      gl = GiftLike.new
      gl.user_id = @user.user_id
      gl.gift_id = gift.gift_id
      gl.like = 'N'
      gl.follow = 'N'
      gl.show = 'N'
    end
    gl.save!
    # hide gift
    @gift_id = gift.id
  end # hide_gift

  def delete_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts2log  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.show_delete_gift_link?(@users)
      puts2log  "user is not allowed to delete gift id #{gift_id} - silently ignore ajax request"
      return
    end
    # delete mark gift. Delete marked gifts will be ajax removed from other sessions within the next 5 minutes and will be physical deleted after 5 minutes
    gift.deleted_at = Time.new
    gift.save!
    if gift.received_at and gift.price and gift.price != 0.0
      # recalculate balance - todo: should only recalculate balance from previous gift and forward
      gift.giver.recalculate_balance if gift.giver
      gift.receiver.recalculate_balance if gift.receiver
    end
    # remove gift from gift from current gifts table
    @gift_id = gift.id
  end # delete_gift

  #
  # comment link ajax methods
  #

  # Parameters: {"comment_id"=>"478"}
  def cancel_new_deal
    comment_id = params[:comment_id]
    comment = Comment.find_by_id(comment_id)
    if !comment
      puts2log  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_cancel_new_deal_link?(@user)
      puts2log  "cancel link no longer active for comment with id #{comment_id} - silently ignore ajax request"
    else
      # cancel agreement proposal
      comment.new_deal_yn = nil
      comment.save!
    end
    # hide link
    @link_id = "gift-#{gift.id}-comment-#{comment.id}-cancel-link"
  end # cancel_new_deal

  def reject_new_deal
    comment_id = params[:comment_id]
    comment = Comment.find_by_id(comment_id)
    if !comment
      puts2log  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_reject_new_deal_link?(@users)
      puts2log  "reject link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # reject agreement proposal
    comment.accepted_yn = 'N'
    comment.save!
    # hide links
    # todo: other comment changes? Maybe an other layout, style, color for accepted gift/comments
    # todo: change gift and comment for other users after reject (new messages count ajax)?
    @link_id = "gift-#{gift.id}-comment-#{comment.id}-reject-link"
    puts2log  "link_id = #{@link_id}"
  end # reject_new_deal

  def accept_new_deal
    comment_id = params[:comment_id]
    comment = Comment.find_by_id(comment_id)
    if !comment
      puts2log  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      puts2log  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_accept_new_deal_link?(@user)
      puts2log  "accept link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # accept agreement proposal - mark proposal as accepted - callbacks sent notifications and updates gift
    # puts2log  "comment.currency = #{comment.currency}"
    comment.accepted_yn = 'Y'
    comment.save!
    if gift.price and gift.price != 0.0
      # create social didivend and recalculate new balance for giver and receiver
      gift.reload
      gift.create_social_dividend
      gift.giver.recalculate_balance
      gift.receiver.recalculate_balance
      # todo: change @user balance in page header
    end

    # use a discount version af new_messages_count to ajax replace accepted deal in gifts/index page for current user
    # that is without @new_messages_count, @comments, only with this accepted gift and without new values for new-newest-gift-id andnew-newest-status-update-at
    # only client insert_update_gifts JS function is called
    # next new_mesage_count request will ajax replace this gift once more, but that is a minor problem
    gift.reload
    @api_gifts = [gift]
    respond_to do |format|
      format.html {}
      format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end
  end # accept_new_deal

  def currencies
    if User.dummy_users?(@users)
      render :nothing => true
    else
      puts2log  "return currencies to client on onfocus event"
    end
  end

  # process tasks from queue
  # that is tasks that could slow request/response cycle or information that is not available on server (client timezone)
  # tasks:
  # - download user profile image from login provider after login (ok)
  # - get permissions from login provider after login (todo: twitter)
  # - get friend lists from login provider after login (ok)
  # - get currency rates for a new date (ok)
  # - upload post and optional picture to login provider (ok)
  def do_tasks
    # save timezone received from javascript
    set_timezone(params[:timezone])
    # cleanup old tasks
    Task.where("created_at < ? and ajax = ?", 2.minute.ago, 'Y').destroy_all
    Task.where("created_at < ? and ajax = ?", 10.minute.ago, 'N').destroy_all
    @errors = []
    Task.where("session_id = ? and ajax = ?", session[:session_id], 'Y').order('priority, id').each do |at|
      at.destroy
      # all tasks must have exception handlers with backtrace.
      # Exception handler for eval will not display backtrace within the called task
      puts2log  ""
      puts2log  "executing task #{at.task}\n"
      res = nil
      begin
        res = eval(at.task)
      rescue Exception => e
        puts2log  "error when processing task #{at.task}"
        puts2log  "Exception: #{e.message.to_s}"
        puts2log  "Backtrace: " + e.backtrace.join("\n")
        res = [ '.ajax_task_exception', { :task => at.task, :exception => e.message.to_s }]
      end
      # puts2log  "task #{at.task}, response = #{res}"
      next unless res
      # check response from task. Must be a valid input to translate
      begin
        key, options = res
        key2 = key
        key2 = 'shared.translate_ajax_errors' + key if key2.to_s.first(1) == '.'
        options = {} unless options
        options[:raise] = I18n::MissingTranslationData
        t key2, options
      rescue I18n::MissingTranslationData => e
        res = [ '.ajax_task_missing_translate_key', { :key => key, :task => at.task, :response => res, :exception => e.message.to_s } ]
      rescue I18n::MissingInterpolationArgument => e
        puts2log  "exception = #{e.message.to_s}"
        puts2log  "response = #{res}"
        argument = $1 if e.message.to_s =~ /:(.+?)\s/
        puts2log  "argument = #{argument}"
        res = [ '.ajax_task_missing_translate_arg', { :key => key, :task => at.task, :argument => argument, :response => res, :exception => e.message.to_s } ]
      rescue Exception => e
        puts2log  "invalid response from task #{at.task}. Must be nil or a valid input to translate. Response: #{res}"
        res = [ '.ajax_task_invalid_response', { :task => at.task, :response => res, :exception => e.message.to_s }]
      end
      # puts2log  "task = #{at.task}, res = #{res}"
      @errors << res
    end
    puts2log "@errors.size = #{@errors.size}"
    if @errors.size == 0
      render :nothing => true
      return
    end
  end # do_tasks

  private
  def get_login_user_and_token (provider)
    login_user = token = nil
    # find user id and token for provider
    login_user = @users.find { |user| user.provider == provider }
    login_user_id = login_user.user_id if login_user
    return [login_user, token, '.post_login_user_id_not_found', {:provider => provider}] unless login_user_id
    login_user = User.find_by_user_id(login_user_id)
    return [login_user, token, '.post_login_unknown_user_id', {:provider => provider, :user_id => login_user_id}] unless login_user
    # get token for api requests
    token = (session[:tokens] || {})[provider]
    return [login_user, token, '.post_login_token_not_found', {:provider => provider}] if token.to_s == ""
    # puts2log  "token = #{token}"
    # ok
    return [login_user, token]
  end


  # helper to get information to be used in post_login_<provider> methods
  # return array with login_user, friends_hash, token, key and options - key and options only if error
  private
  def get_user_friends_and_token(provider)
    puts2log  "provider = #{provider}"
    # get user and token
    friends_hash = nil
    login_user, token, key, options = get_login_user_and_token(provider)
    return [login_user, friends_hash, token, key, options] if key
    login_user_id = login_user.user_id
    # initialize hash with old friends
    old_friends_list = Friend.where('user_id_giver = ?', login_user_id).includes(:friend)
    friends_hash = {}
    (0..(old_friends_list.size-1)).each do |i|
      old_friend = old_friends_list[i]
      old_friend.friend.user_name = old_friend.friend.user_name.force_encoding('UTF-8')
      login_user_id = old_friend.user_id_receiver
      friends_hash[login_user_id] = {:user => old_friend.friend,
                                     :old_name => old_friend.friend.user_name,
                                     :new_name => old_friend.friend.user_name,
                                     :old_name => old_friend.friend.api_profile_url,
                                     :new_name => old_friend.friend.api_profile_url,
                                     :old_api_friend => old_friend.api_friend,
                                     :new_api_friend => 'N',
                                     :new_record => false}
    end
    # ok
    return [login_user, friends_hash, token]
  end # get_user_friends_and_token


  def get_gift_and_deep_link (id, login_user, provider)
    api_gift = deep_link = nil

    # find and check gift and api_gift
    gift = Gift.find_by_id(id)
    return [gift, api_gift, deep_link, '.post_on_api_unknown_gift_id', { :provider => provider, :id => id }] unless gift
    api_gift = ApiGift.find_by_gift_id_and_provider(gift.gift_id, provider)
    return [gift, api_gift, deep_link, '.post_on_api_invalid_gift_id', { :provider => provider, :id => gift.id }] unless api_gift
    return [gift, api_gift, deep_link, '.post_on_api_invalid_gift_id', { :provider => provider, :id => gift.id }] unless [api_gift.user_id_giver, api_gift.user_id_receiver].index(login_user.user_id)
    return [gift, api_gift, deep_link, '.post_on_api_old_gift', { :provider => provider, :id => gift.id }] unless gift.created_at > 5.minute.ago

    # check picture if any - must exists in /images/temp folder before post on API wall
    return [gift, api_gift, deep_link, 'gift_posted_6_html', { :apiname => provider}] if api_gift.picture? and !gift.temp_picture_exists?

    # initialize and check deep link
    deep_link = api_gift.init_deep_link()
    return [gift, api_gift, deep_link, ".gift_posted_7_html", { :apiname => provider, :link => deep_link }] unless api_gift.deep_link_ok?

    # ok
    return [gift, api_gift, deep_link]
  end # get_gift_and_deep_link


  # post login task for facebook - get permissions and friends - using koala gem
  # called from do_tasks - ajax requests after login
  # must return nil or a valid input to translate
  private
  def post_login_facebook
    begin
      # get facebook user, friends and api token
      provider = "facebook"
      login_user, friends_hash, token, key, options = get_user_friends_and_token(provider)
      return [key, options] if key
      login_user_id = login_user.user_id

      # setup facebook api client - get permissions and friends

      # get user information - permissions and friends  - use koala gem for this
      # puts2log  'get user id and name'
      api = Koala::Facebook::API.new(token)
      api_request = 'me?fields=permissions,friends'
      # puts2log  "api_request = #{api_request}"
      api_response = api.get_object api_request
      puts2log  "api_response = #{api_response.to_s}"
      #fetch_user: api_response = {"id"=>"100006397022113", "friends"=>{"data"=>[{"name"=>"David Amfcdabcjbif Martinazzisen", "id"=>"100006341230296"}, {"name"=>"Dick Amfceacglc Bushakson", "id"=>"100006351370003"}, {"name"=>"Karen Amfchcebfhjf Smithescu", "id"=>"100006383526806"}, {"name"=>"Sandra Amfciidbbaee Qinsen", "id"=>"100006399422155"}], "paging"=>{"next"=>"https://graph.facebook.com/100006397022113/friends?access_token=CAAFjZBGzzOkcBAFgvgvY7DmLBrzbKFuOiULN248i3AWlSNWqzzTLLINmRjDSM2djyQriVkcKnVJ80pRz3TiJ1koCNcOPU1ioy40aHHuAZCSXovba3pz74db08a6obnrABFZCgEMwX8cKStw25hwvyqkF1YHiV8d2yV5YoFytaI9hGYyCgk3&limit=5000&offset=5000&__after_id=100006399422155"}}, "permissions"=>{"data"=>[{"installed"=>1, "basic_info"=>1, "status_update"=>1, "photo_upload"=>1, "video_upload"=>1, "email"=>1, "create_note"=>1, "share_item"=>1, "publish_stream"=>1, "publish_actions"=>1, "user_friends"=>1, "bookmarked"=>1}], "paging"=>{"next"=>"https://graph.facebook.com/100006397022113/permissions?access_token=CAAFjZBGzzOkcBAFgvgvY7DmLBrzbKFuOiULN248i3AWlSNWqzzTLLINmRjDSM2djyQriVkcKnVJ80pRz3TiJ1koCNcOPU1ioy40aHHuAZCSXovba3pz74db08a6obnrABFZCgEMwX8cKStw25hwvyqkF1YHiV8d2yV5YoFytaI9hGYyCgk3&limit=5000&offset=5000"}}}

      # 1) update number of friends and permissions
      if api_response['friends']
        login_user.no_api_friends = api_response['friends']['data'].size
      else
        login_user.no_api_friends = 0
      end
      login_user.permissions = api_response['permissions']['data'][0]
      login_user.permissions = {} if login_user.permissions == []
      login_user.save!
      # puts2log  "permissions = #{login_user.permissions}"
      # puts2log  "post_gift_allowed? = #{login_user.post_gift_allowed?}"

      # 2) update friends (insert/delete Friend)
      # compare Friend model data with friends array from API
      # only friends using Gofreerev are relevant
      # friends not using Gofreerev are ignored

      if api_response.has_key?('friends')
        api_friends_list = api_response['friends']['data']
      else
        api_friends_list = [] # no api friends
      end

      api_friends_list.each do |friend|
        friend_user_id = friend["id"] + '/facebook'
        friend["name"] = friend["name"].force_encoding('UTF-8')
        if friends_hash.has_key?(friend_user_id)
          # OK - user already in hash
          nil
        else
          # new facebook friend
          if !(friend_user = User.where("user_id = ?", friend_user_id).first)
            # create unknown user - create user with minimal user information (user id and name)
            friend_user = User.new
            friend_user.user_id = friend_user_id
            friend_user.user_name = friend["name"]
            friend_user.save!
          end
          friends_hash[friend_user_id] = {:user => friend_user, :old_name => friend_user.user_name, :old_api_friend => 'N', :new_record => true}
        end
        friends_hash[friend_user_id][:new_name] = friend["name"]
        friends_hash[friend_user_id][:new_api_friend] = 'Y'
      end # each

      # update facebook friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, true)
      # facebook friend list updated

      # ok
      nil
    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s}"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_facebook


  # post login task for google+ - todo: use for .....
  # using google-api-client
  # called from do_tasks - ajax requests after login
  # must return nil or a valid input to translate
  private
  def post_login_google_oauth2
    begin
      # get google user, friends and api token
      provider = "google_oauth2"
      login_user, friends_hash, token, key, options = get_user_friends_and_token(provider)
      return [key, options] if key
      login_user_id = login_user.user_id

      # get new google api friends
      # puts2log  "token = #{token}"
      client = Google::APIClient.new(
          :application_name => 'Gofreerev',
          :application_version => '0.1'
      )
      # client = Google::APIClient.new
      plus = client.discovered_api('plus')
      client.authorization.client_id = API_ID[provider]
      client.authorization.client_secret = API_SECRET[provider]
      client.authorization.access_token = token
      puts2log "token = #{token}"

      # find people in login user circles
      # https://developers.google.com/api-client-library/ruby/guide/pagination
      request = {:api_method => plus.people.list,
                 :parameters => {'collection' => 'visible', 'userId' => 'me'}}

      # loop for all google+ friends
      loop do

        result = client.execute(request)
        # puts2log  "result = #{result}"
        # puts2log  "result.error_message.class = #{result.error_message.class}"
        # puts2log  "result.error_message = #{result.error_message}"
        #result.error_message = {
        #    "kind": "plus#peopleFeed",
        #    "etag": "\"QR7ccvNi-CeX9lFTHRm3szTVkpo/lZDO4-dFZ0NFLfhR92UMMY8uQCc\"",
        #    "title": "Google+ List of Visible People",
        #    "totalItems": 14,
        #    "items": [
        #    {
        #        "kind": "plus#person",
        #    "etag": "\"QR7ccvNi-CeX9lFTHRm3szTVkpo/2S9G8Bdu4XoaBMyXkF6YMgpD_U0\"",
        #    "objectType": "person",
        #    "id": "114902618678942596705",
        #    "displayName": "Birgitte Pedersen",
        #    "url": "https://plus.google.com/114902618678942596705",
        #    "image": {
        #    "url": "https://lh5.googleusercontent.com/-JssupQoWvMw/AAAAAAAAAAI/AAAAAAAAAJY/3YU5jnmGWDg/photo.jpg?sz=50"
        #}
        #},
        #    {
        #    .....
        # puts2log  "result.data.class = #{result.data.class}"
        # puts2log  "result.data = #{result.data}"
        # puts2log  "result.data.total_items = #{result.data.total_items}"

        # known errors from Google API
        return ['.google_access_not_configured', {:provider => provider}] if result.error_message.to_s == 'Access Not Configured'
        return ['.google_insufficient_permission', {:provider => provider}] if result.error_message.to_s == 'Insufficient Permission'
        # other errors from Google API
        return ['.google_other_errors', {:provider => provider, :error => result.error_message}] if !result.data.total_items

        # copy friends to hash.
        # puts2log  "result.data.items = #{result.data.items}"
        for friend in result.data.items do
          # puts2log  "friend = #{friend} (#{friend.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            nil
          else
            # new google friend
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend.display_name.force_encoding('UTF-8')
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user, :old_name => friend_user.user_name, :old_api_friend => 'N', :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend.display_name.force_encoding('UTF-8')
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
        end # item
        # next page - get more friends if any
        break unless result.next_page_token
        request = result.next_page
      end # loop for all google+ friends

      # update google+ friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, false)
      # google+ friends updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil
    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s}"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_google_oauth2



  # post login task for linkedIn - get connections
  # using linked gem
  # called from do_tasks - ajax requests after login
  # must return nil or a valid input to translate  private
  private
  def post_login_linkedin
    begin

      # get linkedin user, friends and api token
      provider = "linkedin"
      login_user, friends_hash, token, key, options = get_user_friends_and_token(provider)
      return [key, options] if key
      login_user_id = login_user.user_id

      # create client for linkedin api requests
      client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
      client.authorize_from_access token[0], token[1] # token and secret
      # puts2log "token = #{token.join(', ')}"

      # get public profile url for login user
      profile = client.profile :fields=>['public-profile-url']
      public_profile_url = profile.public_profile_url
      puts2log "public_profile_url = #{public_profile_url}"
      # post_login_linkedin: public_profile_url = http://www.linkedin.com/pub/jan-test-account-roslind/87/b08/27a

      # todo: count number of connections retured from linkedin
      # todo: handle nil array returned from linkedin (r_network missing in scope)

      no_linkedin_connections = 0
      begin
        client.connections(:fields => %w(id,first-name,last-name,public-profile-url)).all.each do |connection|
          no_linkedin_connections += 1
          puts2log "connection.public_profile_url = #{connection.public_profile_url}"
          # copy friend to friends_hash
          friend_user_id = "#{connection.id}/#{provider}"
          friend_name = "#{connection.first_name} #{connection.last_name}".force_encoding('UTF-8')
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            nil
          else
            # new google friend
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend_name
              friend_user.api_profile_url = connection.public_profile_url if connection.public_profile_url
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user,
                                            :old_name => friend_user.user_name,
                                            :old_api_profile_url => friend_user.api_profile_url,
                                            :old_api_friend => 'N',
                                            :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend_name
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
          friends_hash[friend_user_id][:new_api_profile_url] = connection.public_profile_url if connection.public_profile_url
        end # connection loop
      rescue LinkedIn::Errors::AccessDeniedError => e
        return ['.linkedin_access_denied', {:provider => provider}] if e.message.to_s =~ /Access to connections denied/
        raise
      end
      puts2log "Found #{no_linkedin_connections} #{provider} connections"

      # update linkedin connections
      Friend.update_friends_from_hash(login_user_id, friends_hash, false)
      # linkedin connections updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil

    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_linkedin


  # post login task for twitter - get friends
  # using twitter gem
  # called from do_tasks - ajax requests after login
  # must return nil or a valid input to translate  private
  private
  def post_login_twitter
    begin

      # get twitter user, friends and api token
      provider = "twitter"
      login_user, friends_hash, token, key, options = get_user_friends_and_token(provider)
      return [key, options] if key
      login_user_id = login_user.user_id
      # puts2log  "token = #{token.join(', ')}"

      # create client for twitter api requests
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = API_ID[provider]
        config.consumer_secret     = API_SECRET[provider]
        config.access_token        = token[0]
        config.access_token_secret = token[1]
      end

      no_twitter_friends = 0
      begin
        client.friends.to_a.each do |friend|
          no_twitter_friends += 1
          puts2log "friend.url = #{friend.url} (#{friend.url.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          friend_name = friend.name.dup.force_encoding('UTF-8')
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            nil
          else
            # new google friend
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend_name
              friend_user.api_profile_url = friend.url.to_s
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user,
                                            :old_name => friend_user.user_name,
                                            :old_api_profile_url => friend_user.api_profile_url,
                                            :old_api_friend => 'N',
                                            :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend_name
          friends_hash[friend_user_id][:new_api_profile_url] = friend.url.to_s
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
        end # connection loop
      # todo: add rescue for missing privs
      end

      # update twitter friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, false)
      # twitter friends updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil

    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_twitter


  # recalculate user balance
  # use after login, at new day, after new deal, after deleted deal etc
  def recalculate_user_balance (id)
    begin
      # check id
      user = User.find_by_id(id)
      return ['.recal_user_bal_unknown_id',{}] unless user
      return ['.recal_user_bal_invalid_id',{}] unless login_user_ids.index(user.user_id)

      # recalculate balance for user or for user combination
      today = Date.parse(Sequence.get_last_exchange_rate_date)
      if user.user_combination
        if User.where('user_combination = ? and (balance_at is null or balance_at <> ?)',
                      user.user_combination, today).first
          # todo. User.recalculate_balance class method not implemented
          res = User.recalculate_balance(user.user_combination)
        end
      else
        res = user.recalculate_balance if !user.balance_at or user.balance_at != today
      end
      ['.recal_user_cal_pending',{}] unless res

      nil

    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # recalculate_user_balance


  # post on facebook wall - with or without picture
  # picture is temporary saved local, but is deleted when the picture has been posted in wall(s)
  # task was inserted in gifts/create
  private
  def post_on_facebook (id)
    begin
      # get login user and api access token
      provider = "facebook"
      login_user, token, key, options = get_login_user_and_token(provider)
      return [key, options] if key

      # get gift, api_gift and deep_link
      gift, api_gift, deep_link, key, options = get_gift_and_deep_link(id, login_user, provider)
      return [key, options] if key

      # gift_posted_on_wall_api_wall. values:
      #  1: "Gift posted in here but not on your %{apiname} wall. #{error}" # unhandled error message
      #  2: "Gift posted in here and on your %{apiname} wall"
      #  3: "Gift posted in here but not on your %{apiname} wall." # missing privileges
      #  4: "Gift posted in here but not on your %{apiname} wall. Duplicate status message on #{apiname} wall."
      #  5: "Gift posted in here but not on your %{apiname} wall. Post on #{apiname} wall not implemented."
      gift_posted_on_wall_api_wall = 1
      error = 'unknown error'

      if login_user.post_gift_allowed?
        # post with or without picture - link is a deep link from facebook wall to gift in gofreerev
        # link will be clickable if public url
        # link will be not clickable if localhost or server behind firewall

        # initialize and check deep link
        deep_link = api_gift.init_deep_link()
        return [".gift_posted_7_html", { :apiname => provider, :link => deep_link }] unless api_gift.deep_link_ok?

        begin
          # post
          api = Koala::Facebook::API.new(token)
          # todo: add method gift.temp_picture_exists?
          if api_gift.picture? and !gift.temp_picture_exists?
            # post with picture but picture was not found.
            # There must be some error handling in gifts/create that is missing
            gift_posted_on_wall_api_wall = 6
          elsif api_gift.picture?
            # status post with picture
            filetype = gift.temp_picture_path.split('.').last
            content_type = "image/#{filetype}"
            api_response = api.put_picture(gift.temp_picture_path,
                                           content_type,
                                           {:message => "#{gift.description} - #{deep_link}"
                                           })
            # api_response = {"id"=>"1396226023933952", "post_id"=>"100006397022113_1396195803936974"} (Hash)
            api_gift.api_gift_id = api_response['post_id']
          else
            # status post without picture
            # gift.description = "#{gift.description} - #{link}" # link only as text
            # gift.description = "<a href='#{link}'>#{gift.description}</a>" # html code as text
            api_response = api.put_connections('me', 'feed',
                                               :message => "#{gift.description} - #{deep_link}"
                                               )
            # api_response = {"id"=>"100006397022113_1396235850599636"}
            api_gift.api_gift_id = api_response['id']
          end
          puts2log  "api_response = #{api_response} (#{api_response.class.name})"
          gift_posted_on_wall_api_wall = 2 # Gift posted in here and on your facebook wall
        rescue Koala::Facebook::ClientError => e
          e.puts_exception("#{__method__}: ")
          if e.fb_error_type == 'OAuthException' && e.fb_error_code == 506
            # delete gift and ignore error OAuthException, code: 506, message: (#506) Duplicate status message [HTTP 400]
            gift_posted_on_wall_api_wall = 4 # Gift posted in here but not on your facebook wall. Duplicate status message on facebook wall.
          elsif e.fb_error_type == 'OAuthException' && e.fb_error_code == 200
            # e.response_body = {"error":{"message":"(#200) The user hasn't authorized the application to perform this action","type":"OAuthException","code":200}}
            # check if permission to post i api wall has been removed
            error = e.to_s
            login_user.get_api_permissions(token)
            if !login_user.post_gift_allowed?
              # permission to post on api wall has been removed.
              # show request_post_gift_priv_link link in gifts/index page
              gift_posted_on_wall_api_wall = 3
              error = nil
            else
              # permission to post on api wall has NOT been removed. Unknown error
              gift_posted_on_wall_api_wall = 1 # unknown error. no translation
              api_gift.clear_deep_link
            end
          else
            # unhandled exceptions
            gift_posted_on_wall_api_wall = 1 # unknown error. no translation
            error = e.to_s
            api_gift.clear_deep_link
          end
        rescue Koala::Facebook::ServerError => e
          e.puts_exception("#{__method__}: ")
          gift_posted_on_wall_api_wall = 1 # unknown error. no translation
          error = e.fb_error_message.to_s
          api_gift.clear_deep_link
        end # rescue
      else
        # post_gift_allowed? false - ajax inject link to grant missing permission
        gift_posted_on_wall_api_wall = 3
      end # if

      if gift_posted_on_wall_api_wall != 2
        # error or warning
        api_gift.picture = 'N'
        api_gift.save!
        options = {:apiname => login_user.api_name_without_brackets, :error => error}
        if gift_posted_on_wall_api_wall == 3
          # url to grant missing status update permission to post on facebook wall
          # looks like permission status_update has been replaced with publish_actions
          # publish_actions is added to permissions hash when granting status_update priv.
          oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
          url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => set_state('status_update'))
          options[:url] = url
          options[:appname] = APP_NAME
        end
        return ".gift_posted_#{gift_posted_on_wall_api_wall}_html", options
      else
        # post ok - gift posted in facebook wall - check read access to gift / get picture url
        # must have read access to post on facebook wall to display picture in gofreerev
        # must have read access to post on facebook wall to add comment with deep link to gift on gofreerev
        field = api_gift.picture? ? 'full_picture' : 'message'
        begin
          res = api_gift.api_picture_url = api_gift.get_facebook_post(:access_token => token, :field => field)
          puts2log  "#{field} = #{res}"
          if api_gift.picture?
            api_gift.api_picture_url = res
            if api_gift.api_picture_url
              # valid picture url received from api
              api_gift.api_picture_url_updated_at = Time.now
              api_gift.api_picture_url_on_error_at = nil
              api_gift.save!
            else
              puts2log  "Did not get a picture url from api. Must be problem with missing access token, picture != Y or deleted_at_api == Y"
              return ['.no_api_picture_url', {:apiname => login_user.api_name_without_brackets}]
            end
          end
        rescue ApiPostNotFoundException => e
          # problem with upload and permissions
          # could not get full_picture url for an uploaded picture
          # or could not get mesaage for an post
          # the problem appeared after changing app visibility from public to friends
          # that is - app is not allowed to get info about the uploaded picture!!
          # there must be more to it - changed visibility to only me and did get picture url
          # changed visibility to friends and did get the picture url
          # just display a warning and continue. Request read_stream permission from user if read_stream priv. is missing
          if api_gift.picture?
            api_gift.picture = 'N'
            api_gift.save!
          end
          if login_user.read_gifts_allowed?
            # check if user has removed read stream priv.
            login_user.get_api_permissions(token)
          end
          if login_user.read_gifts_allowed?
            # error - this should not happen.
            key = api_gift.picture? ? '.fb_pic_post_unknown_problem' : '.fb_msg_post_unknown_problem'
            return [key, {:appname => APP_NAME, :apiname => login_user.api_name_without_brackets}]
          else
            # message with link to grant missing read stream priv.
            oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
            url = oauth.url_for_oauth_code(:permissions => 'read_stream', :state => set_state('read_stream'))
            key = api_gift.picture? ? '.fb_pic_post_missing_permission_html' : '.fb_msg_post_missing_permission_html'
            return [key, {:appname => APP_NAME, :apiname => login_user.api_name_without_brackets, :url => url}]
          end
        end # rescue

        # post ok and no permission problems
        # no errors - return posted message
        return [".gift_posted_#{gift_posted_on_wall_api_wall}_html", :apiname => login_user.api_name_without_brackets, :error => error]
      end

    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_on_facebook

  # post on google+ not implemented. The Google+ API is a read only API
  # private
  # def post_on_google_oauth2 (id)
  # end

  def post_on_linkedin (id)
    begin
      # get login user and api access token
      provider = "linkedin"
      login_user, token, key, options = get_login_user_and_token(provider)
      return [key, options] if key

      # get gift, api_gift and deep_link
      gift, api_gift, deep_link, key, options = get_gift_and_deep_link(id, login_user, provider)
      return [key, options] if key

      # create client for linkedin api requests
      client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
      client.authorize_from_access token[0], token[1] # token and secret
      # puts2log  "token = #{token[0]}"
      # puts2log  "secret = #{token[1]}"

      # todo: add offers/seeks to description
      # todo: add picture
      # todo: add url for gift
      begin

        image_url = "#{SITE_URL}#{gift.temp_picture_url}"
        # http://stackoverflow.com/questions/15183107/rails-linked-post-message
        # http://developer.linkedin.com/documents/share-api#toggleview:id=ruby
        # Node                Parent Node    Value 	Notes
        # comment             share          Text of member's comment.        Post must contain comment and/or (content/title and content/submitted-url).
        #                                                                     Max length is 700 characters.
        # content             share          Parent node for information on shared document
        # title               share/content  Title of shared document         Post must contain comment and/or (content/title and content/submitted-url).
        #                                                                     Max length is 200 characters.
        # submitted-url       share/content  URL for shared content           Post must contain comment and/or (content/title and content/submitted-url).
        # submitted-image-url share/content  URL for image of shared content  Invalid without (content/title and content/submitted-url).
        # description         share/content  Description of shared content    Max length of 256 characters.
        # note that linkedin uses meta property="og:description as default description
        # todo: check layout with and without picture
        # todo: check description length. <= 256 use only description. length <= 700. Use only comment. Length between 700 and 956 use comment and description
        text = "#{format_direction_without_user(api_gift)} #{gift.description}"
        puts2log "picture = #{api_gift.picture?}, text.length = #{text.length}"
        comment = nil
        content = { "submitted-url" => deep_link }
        if api_gift.picture?
          # title (max 200 characters) required for post with image.
          content["submitted-image-url"] = image_url
          # layout rules for post with image on linkedin:
          case
            when text.length <= 200
              content["title"] = text
              content["description"] = ''
            when text.length <= 456
              content["title"] = text.first(200)
              content["description"] = text.from(200)
            else
              raise "linkedin post with picture and text length > 456 is not implemented"
          end
        else
          case
            when text.length <= 700
              comment = text
            else
              raise "linkedin post without picture and text length > 700 is not implemented"
          end
        end
        #comment = nil
        #content = { "submitted-url" => 'http://jan-roslind.dk/testcases/test1.html',
        #            "submitted-image-url" => 'http://jan-roslind.dk/testcases/sacred-economics-linkedin.jpg',
        #            "title" => 'Offers: Fra nytår bliver vagtlægens telefon i Hovedstaden ikke',
        #            "description" => 'længere svaret af en læge, men af en sygeplejerske. Danske Patienter kalder det et eksperiment.' }
        x = client.add_share :content => content, :comment => comment
        puts "x = #{x} (#{x.class})"
      rescue LinkedIn::Errors::AccessDeniedError => e
        puts2log  "LinkedIn::Errors::AccessDeniedError"
        puts2log  "e.message = #{e.message}"
        api_gift.clear_deep_link
        if e.message.to_s =~ /^\(403\)/
          # e.message = (403): Access to posting shares denied
          # linkedin permission problem - post in linkedin wall not allowed as default
          # default linkedin scope is "r_basicprofile r_network" - see config//initializers/omniauth.rb
          # inject link in @errors so that user can authorize with request scope => "r_basicprofile r_network rw_nus"
          # that is - user can permit post on linked wall

          # http://railscarma.com/blog/rails-3/how-to-use-linkedin-api-in-rails-applications/
          scope = 'r_basicprofile r_network rw_nus'
          client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
          request_token = client.request_token({:oauth_callback => API_CALLBACK_URL[provider]}, :scope => scope)
          client.authorize_from_access(request_token.token, request_token.secret)
          url = client.request_token.authorize_url

          # save client - client object is used for authorization when/if user returns from linkedin with write permission to linkedin wall
          # too big for session cookie - to saved in task_data
          save_linkedin_client(client)

          # ajax inject link in gifts/index page
          return ['.gift_posted_3_html', { :appname => APP_NAME, :apiname => provider, :url => url}]

        end
        raise
      end

      # post on linkedin ok
      puts2log  "x = #{x} (#{x.class})"
      puts2log  "x.methods = #{x.methods.sort.join(', ')}"

      # no errors - return posted message
      return [".gift_posted_2_html", :apiname => provider, :error => nil]

    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_on_linkedin

  # check after post_on_<provider>'s' if user have write access to any api wall
  # disable if user does not have granted write permission to any api wall
  # enable if user have granted write permission to one api wall
  # todo: should also change title ......
  def disable_enable_file_upload
    begin
      # reload @users - permissions can have changed in post_in_<provider> tasks
      @users = @users.collect { |user| user.reload }
      # disabled = !@gift_file. See do_tasks.js.erb
      @gift_file = User.post_gift_allowed?(@users)
      puts2log  "@gift_file = #{@gift_file}"
      nil
    rescue Exception => e
      puts2log  "Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # disable_file_upload

  # delete local picture file that was used when posting picture in api wall(s) - see post_on_facebook etc.
  def delete_local_picture (id)
    begin
      puts2log  ""

      # get and check gift
      gift = Gift.find_by_id(id)
      return ['.post_on_api_unknown_gift_id', { :provider => 'API', :id => id }] unless gift
      return ['.post_on_api_old_gift', { :provider => 'API', :id => gift.id }] unless gift.created_at > 5.minute.ago

      # check local picture file
      return ['.no_local_picture', { :provider => 'API', :id => id }] unless gift.temp_picture_filename
      return ['.local_picture_not_found', { :provider => 'API', :id => id }] unless File.exist?(gift.temp_picture_path)

      # delete file
      File.delete(gift.temp_picture_path)
      gift.temp_picture_filename = nil
      gift.save!

      # check picture setting after posting on api walls
      gift.api_gifts.each do |api_gift|
        if api_gift.api_picture_url =~ /^temp/
          # temp url - picture was not uploaded to api wall
          api_gift.api_picture_url = nil
          api_gift.picture = 'N'
          api_gift.save!
        end
      end

      nil

    rescue Exception => e
      puts2log  "#{__method__}: Exception: #{e.message.to_s} (#{e.class})"
      puts2log  "#{__method__}: Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # delete_local_picture
  
  
end # UtilController

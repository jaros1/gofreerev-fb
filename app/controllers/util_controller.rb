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
    if !@users or @users.length == 0
      puts "ignoring not logged in user"
      render :nothing => true
      return
    end
    # cleanup - destroy old delete marked gifts
    # gift was marked as deleted in util/delete_gift request
    # gift has been ajax removed from  gifts pages for other sessions in previous util/new_message_count requests
    # now is the time to destroy old delete marked gifts
    userids = @users.collect { |user| user.user_id }
    Gift.where('("api_gifts".user_id_giver in (?) or "api_gifts".user_id_receiver in (?)) and deleted_at is not null and deleted_at < ?',
               userids, userids, 10.minutes.ago).includes(:api_gifts).references(:api_gifts).each do |g|
      g.destroy
    end
    # get params
    old_newest_gift_id = params[:newest_gift_id].to_i
    old_newest_status_update_at = params[:newest_status_update_at].to_i
    # return new messages count
    count = @user.inbox_new_notifications
    @new_messages_count = count if count > 0
    # return new comments
    # return new comments and comments with changed status (new deal proposal cancelled or rejected or deleted comment)
    if  params[:request_fullpath] == '/gifts' or params[:request_fullpath] =~ /^\/gifts\/([0-9]+)$/
      # find comments to ajax insert in gifts/index or gifts/show pages
      # puts "find comments to ajax insert in gifts/index or gifts/show pages"
      # two sources for comments to ajax insert into gifts table
      # source 1 - comments selected to be ajax inserted for this user - todo: check where AjaxCommment is initialized
      com_ids = AjaxComment.where("user_id = ?", @user.user_id).collect { |ac| ac.comment_id }
      com_ids.push('x') if com_ids.size == 0
      # puts "com_ids.length = #{com_ids.length}"
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
        # puts "new comments before gift_id filter = #{@comments.length}"
        @comments = @comments.find_all { |c| c.gift.id.to_s == $1 }
        # puts "new comments after gift_id filter = #{@comments.length}"
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
        # puts "#{old_size-new_size} comments for hidden gifts was removed" if old_size != new_size
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
      @gifts = User.api_gifts(@users, old_newest_gift_id, old_newest_status_update_at, true) # include delete marked gifts
      @gifts = nil if @gifts.length == 0
    end
    # remove any ajax comments for gifts in gifts array - that is gifts that will be ajax inserted or replaced in gifts html table
    if @comments and @gifts and @comments.size > 0 and @gifts.size > 0
      # puts "remove any comments that is included in gifts"
      # puts "old @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
      @comments = @comments.delete_if { |c| @gifts.find_all { |g| c.gift_id == g.gift_id }.first }
      @comments = nil if @comments.size == 0
      # puts "new @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    end
    puts "@gifts.size = #{@gifts.size}, gifts = " + @gifts.collect { |g| g.id }.join(', ') if @gifts
    puts "@comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    puts "@new_newest_gift_id = #{@new_newest_gift_id}"
    puts "@new_newest_status_update_at = #{@new_newest_status_update_at}"
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
    return unless params.has_key?("gifts")
    return unless params[:api_gifts].has_key?(:ids)
    return if  params[:api_gifts][:ids] == ''
    ids = params[:api_gifts][:ids].split(',')
    puts "ids = #{ids}"
    gifts = Gift.where("id in (?)", ids)

    # set error timestamp
    gifts.each do |gift|
      puts gift.api_picture_url
      gift.api_picture_url_on_error_at = Time.now
      gift.save!
    end # each

    # get new picture urls
    # todo: 1 - catch deleted picture / status
    #       Koala::Facebook::ClientError (type: GraphMethodException, code: 100, message: Unsupported get request. [HTTP 400]):
    # todo: 2 - maybe app friend is not allowed to see picture in facebook
    # todo: 3 - max request picture url once every hour
    # todo: 4 - gifts/index - should check for error marked pictured and fix urls that couldn't be fixed in here (see 2)
    access_token = session[:access_token]
    return unless access_token
    gifts.each do |gift|
      next if gift.picture == 'N' or gift.deleted_at_api == 'Y'
      # get new picture url from API
      begin
        gift.api_picture_url = gift.get_api_picture_url(access_token)
      rescue ApiPostNotFoundException => e
        # identical api error response if picture is deleted or if user is not allowed to see picture
        user_id_created_by = gift.api_gift_id.split('_').first + '/facebook'
        if @user.user_id != user_id_created_by
          # picture may have or may not have been deleted in facebook.
          # current user may not have permission to read picture on wall
          # keep api_picture_url_on_error_at timestamp and continue
          # the picture url will be checked by picture owner at a later time
          puts "Could not get new picture url. Could be deleted picture. Could be api permission problem. Keep error and let owner check picture url at a later time"
          next
        end # if
            # picture was not found with picture owner login
            # it could be a fb permission problem (app priv has been removed) but most likely the picture has been deleted
            # keep api_picture_url_on_error_at so that we known about when the picture was been deleted
            # gifts in app is not deleted automatically. Could affect the balance. Could be connected with other gifts.
            # this allow users to cleanup their FB profile without destroying data in app
        puts "Gift has been deleted on #{@user.api_name_without_brackets}. Keep in #{APP_NAME} as the gift could have been used in balance and in connected gifts (todo)"
        gift.picture = 'N'
        gift.api_picture_url = nil
        gift.api_picture_url_updated_at = nil
        gift.deleted_at_api = 'Y'
        gift.save!
        next
      end # rescue
      # save new picture url from api
      gift.api_picture_url_updated_at = Time.now
      gift.api_picture_url_on_error_at = nil
      gift.save!
    end # each

  end # missing_api_picture_urls


  #
  # gift link ajax methods
  #

  def like_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
    @gift_link_text = t('gifts.gift.unlike_gift')
  end # like_gift

  def unlike_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if !gl or gl.like != 'Y'
      puts "Non previous like was found for user #{@user.short_user_name} and gift id #{gift_id}"
      return
    end
    gl.like = 'N' ;
    gl.save!
    # change link
    @gift_link_id = "gift-#{gift.id}-like-unlike-link"
    @gift_link_href = util_like_gift_path(:gift_id => gift.id)
    @gift_link_text = t('gifts.gift.like_gift')
  end # unlike_gift

  def follow_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
    @gift_link_text = t('gifts.gift.unfollow_gift')
  end # follow_gift

  def unfollow_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
    @gift_link_text = t('gifts.gift.follow_gift')
  end # unfollow_gift

  def hide_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
      puts "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if ![gift.user_id_giver, gift.user_id_receiver].index(@user.user_id)
      puts "#{@user.short_user_name} is not allowed to delete gift id #{gift_id} - silently ignore ajax request"
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
      puts "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_cancel_new_deal_link?(@user)
      puts "cancel link no longer active for comment with id #{comment_id} - silently ignore ajax request"
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
      puts "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_reject_new_deal_link?(@users)
      puts "reject link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # reject agreement proposal
    comment.accepted_yn = 'N'
    comment.save!
    # hide links
    # todo: other comment changes? Maybe an other layout, style, color for accepted gift/comments
    # todo: change gift and comment for other users after reject (new messages count ajax)?
    @link_id = "gift-#{gift.id}-comment-#{comment.id}-reject-link"
    puts "link_id = #{@link_id}"
  end # reject_new_deal

  def accept_new_deal
    comment_id = params[:comment_id]
    comment = Comment.find_by_id(comment_id)
    if !comment
      puts "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for(@users)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_accept_new_deal_link?(@user)
      puts "accept link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # accept agreement proposal - mark proposal as accepted - callbacks sent notifications and updates gift
    # puts "util_controller.accept_new_deal: comment.currency = #{comment.currency}"
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
    # only client ajax_insert_update_gifts JS function is called
    # next new_mesage_count request will ajax replace this gift once more, but that is a minor problem
    gift.reload
    @gifts = [gift]
    respond_to do |format|
      format.html {}
      format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end
  end # accept_new_deal

  def currencies
    puts "return currencies to client on onfocus event"
  end

  # process ajax tasks from session[:ajax_tasks] queue
  # that is tasks that could slow request/response cycle or information that is not available on server (timezone)
  # tasks:
  # - update user timezone from client/javascript after login (ok)
  # - download user profile image from login provider after login (ok)
  # - get permissions from login provider after login (todo)
  # - get friend lists from login provider after login (todo)
  # - get currency rates for a new date (ok)
  # - upload post and optional picture to login provider (todo)
  def do_ajax_tasks
    # delete old ajax tasks
    AjaxTask.where("created_at < ?", 2.minute.ago).destroy_all
    @errors = []
    AjaxTask.where("session_id = ?", session[:session_id]).order('priority desc, id').each do |at|
      at.destroy
      # all ajax tasks should have exception handlers with backtrace. Exception handler for eval will not dump backtrace in at.task
      res = nil
      begin
        res = eval(at.task)
      rescue Exception => e
        puts "error when processing ajax task #{at.task}"
        puts "Exception: #{e.message.to_s}"
        puts "Backtrace: " + e.backtrace.join("\n")
        res = [ '.ajax_task_exception', { :task => at.task, :exception => e.message.to_s }]
      end
      # puts "ajax task #{at.task}, response = #{res}"
      next unless res
      # check response from ajax task. Must be a valid input to translate
      begin
        key, options = res
        key2 = key
        key2 = 'shared.translate_ajax_errors' + key if key2.to_s.first(1) == '.'
        options = {} unless options
        options[:raise] = I18n::MissingTranslationData
        t key2, options
      rescue I18n::MissingTranslationData => e
        res = [ '.ajax_task_missing_translate_key', { :key => key, :task => at.task, :response => res, :exception => e.message.to_s } ]
      rescue Exception => e
        puts "invalid response from ajax task #{at.task}. Must be nil or a valid input to translate. Response: #{res}"
        res = [ '.ajax_task_invalid_response', { :task => at.task, :response => res, :exception => e.message.to_s }]
      end
      # puts "task = #{at.task}, res = #{res}"
      @errors << res
    end
    if @errors.size == 0
      render :nothing => true
      return
    end
  end # do_ajax_tasks

  private
  def get_login_user_and_token (provider)
    login_user = token = nil
    # find user id and token for provider
    login_user_id = (session[:user_ids] || []).find { |user_id2| user_id2.split('/').last == provider }
    return [login_user, token, '.post_login_user_id_not_found', {:provider => provider}] unless login_user_id
    login_user = User.find_by_user_id(login_user_id)
    return [login_user, token, '.post_login_unknown_user_id', {:provider => provider, :user_id => login_user_id}] unless login_user
    # get token for api requests
    token = (session[:tokens] || {})[provider]
    return [login_user, token, '.post_login_token_not_found', {:provider => provider}] if token.to_s == ""
    puts "token = #{token}"
    # ok
    return [login_user, token]
  end


  # helper to get information to be used in post_login_<provider> methods
  # return array with login_user, friends_hash, token, key and options - key and options only if error
  private
  def get_user_friends_and_token(provider)
    puts "post_login_#{provider}"
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
      friends_hash[login_user_id] = {:user => old_friend.friend, :old_name => old_friend.friend.user_name, :new_name => old_friend.friend.user_name, :old_api_friend => old_friend.api_friend, :new_api_friend => 'N', :new_record => false}
    end
    # ok
    return [login_user, friends_hash, token]
  end # get_user_friends_and_token


  # post login ajax task for facebook - get permissions and friends - using koala gem
  # called from do_ajax_tasks - ajax requests after login
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
      # puts 'fetch_user: get user id and name'
      api = Koala::Facebook::API.new(token)
      api_request = 'me?fields=permissions,friends'
      # puts "fetch_user: api_request = #{api_request}"
      api_response = api.get_object api_request
      # puts "fetch_user: api_response = #{api_response.to_s}"
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

      # 3) update balance
      if login_user.user_combination
        if User.where('user_combination = ? and (balance_at is null or balance_at <> ?)',
                      login_user.user_combination, Date.today).first
          # todo. User.recalculate_balance class method not implemented
          User.recalculate_balance(login_user.user_combination)
        end
      else
        login_user.recalculate_balance if login_user.balance_at != Date.today
      end

      # ok
      nil
    rescue Exception => e
      puts "post_login_facebook:"
      puts "Exception: #{e.message.to_s}"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_facebook


  # post login ajax task for google+ - todo: use for .....
  # using google-api-client
  # called from do_ajax_tasks - ajax requests after login
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
      puts "token = #{token}"
      client = Google::APIClient.new(
          :application_name => 'Gofreerev',
          :application_version => '0.1'
      )
      # client = Google::APIClient.new
      plus = client.discovered_api('plus')
      client.authorization.client_id = ENV['GOFREEREV_GP_APP_ID']
      client.authorization.client_secret = ENV['GOFREEREV_GP_APP_SECRET']
      client.authorization.access_token = token

      # find people in login user circles
      # https://developers.google.com/api-client-library/ruby/guide/pagination
      request = {:api_method => plus.people.list,
                 :parameters => {'collection' => 'visible', 'userId' => 'me'}}

      # loop for all google+ friends
      loop do

        result = client.execute(request)
        # puts "result = #{result}"
        # puts "result.error_message.class = #{result.error_message.class}"
        # puts "result.error_message = #{result.error_message}"
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
        # puts "result.data.class = #{result.data.class}"
        # puts "result.data = #{result.data}"
        # puts "result.data.total_items = #{result.data.total_items}"

        # known errors from Google API
        return ['.google_access_not_configured', {:provider => provider}] if result.error_message.to_s == 'Access Not Configured'
        return ['.google_insufficient_permission', {:provider => provider}] if result.error_message.to_s == 'Insufficient Permission'
        # other errors from Google API
        return ['.google_other_errors', {:provider => provider, :error => result.error_message}] if !result.data.total_items

        # copy friends to hash.
        # puts "result.data.items = #{result.data.items}"
        for friend in result.data.items do
          # puts "friend = #{friend} (#{friend.class})"
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
      puts "Exception: #{e.message.to_s}"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_google_oauth2



  # post login ajax task for linkedIn - get connections
  # using linked gem
  # called from do_ajax_tasks - ajax requests after login
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
      client = LinkedIn::Client.new ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET']
      client.authorize_from_access token[0], token[1] # token and secret

      # todo: count number of connections retured from linkedin
      # todo: handle nil array returned from linkedin (r_network missing in scope)

      no_linkedin_connections = 0
      begin
        client.connections.all.each do |connection|
          no_linkedin_connections += 1
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
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user, :old_name => friend_user.user_name, :old_api_friend => 'N', :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend_name
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
        end # connection loop
      rescue LinkedIn::Errors::AccessDeniedError => e
        return ['.linkedin_access_denied', {:provider => provider}] if e.message.to_s =~ /Access to connections denied/
        raise
      end

      # update linkedin connections
      Friend.update_friends_from_hash(login_user_id, friends_hash, false)
      # linkedin connections updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil

    rescue Exception => e
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_linkedin


  # post login ajax task for twitter - get friends
  # using twitter gem
  # called from do_ajax_tasks - ajax requests after login
  # must return nil or a valid input to translate  private
  private
  def post_login_twitter
    begin

      # get twitter user, friends and api token
      provider = "twitter"
      login_user, friends_hash, token, key, options = get_user_friends_and_token(provider)
      return [key, options] if key
      login_user_id = login_user.user_id
      puts "token = #{token.join(', ')}"

      # create client for twitter api requests
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['GOFREEREV_TW_APP_ID']
        config.consumer_secret     = ENV['GOFREEREV_TW_APP_SECRET']
        config.access_token        = token[0]
        config.access_token_secret = token[1]
      end

      no_twitter_friends = 0
      begin
        client.friends.to_a.each do |friend|
          no_twitter_friends += 1
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
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user, :old_name => friend_user.user_name, :old_api_friend => 'N', :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend_name
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
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_twitter

  # fix problem with different currencies for logged in users - for example USD in facebook and GBP in linkedin
  private
  def post_login_fix_currency
    begin
      raise "not implemented"

      # ok
      nil

    rescue Exception => e
      puts "post_login_fix_currency:"
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_fix_currency

  # post on facebook wall - with or without picture
  # picture is temporary saved local, but is deleted when the picture has been posted in wall(s)
  # ajax task is inserted in gifts/create ajax
  private
  def post_on_facebook (id)
    begin
      # get login user and api access token
      provider = "facebook"
      login_user, token, key, options = get_login_user_and_token(provider)
      return [key, options] if key

      # get and check gift
      gift = Gift.find_by_id(id)
      return ['.post_on_api_unknown_gift_id', { :provider => provider, :id => id }] unless gift
      api_gift = ApiGift.find_by_gift_id_and_provider(gift.gift_id, provider)
      return ['.post_on_api_invalid_gift_id', { :provider => provider, :id => gift.id }] unless api_gift
      return ['.post_on_api_invalid_gift_id', { :provider => provider, :id => gift.id }] unless [api_gift.user_id_giver, api_gift.user_id_receiver].index(login_user.user_id)
      return ['.post_on_api_old_gift', { :provider => provider, :id => gift.id }] unless gift.created_at > 5.minute.ago
      # get api gift for facebook post - fields are empty at this point
      api_gift = ApiGift.find_by_gift_id_and_provider(gift.gift_id, provider)
      return [ '.post_on_api_no_api_gift', { :provider => provider, :id => id }] unless api_gift

      # gift_posted_on_wall_api_wall. values:
      #  1: "Gift posted in here but not on your %{apiname} wall. #{error}" # unhandled error message
      #  2: "Gift posted in here and on your %{apiname} wall"
      #  3: "Gift posted in here but not on your %{apiname} wall." # missing privileges
      #  4: "Gift posted in here but not on your %{apiname} wall. Duplicate status message on #{apiname} wall."
      #  5: "Gift posted in here but not on your %{apiname} wall. Post on #{apiname} wall not implemented."
      gift_posted_on_wall_api_wall = 1
      error = 'unknown error'

      if login_user.post_gift_allowed?
        # puts "access_token = #{session[:access_token]}"
        api = Koala::Facebook::API.new(token)
        begin
          if api_gift.picture == 'Y'
            # status post with picture
            filetype = gift.temp_picture_path.split('.').last
            content_type = "image/#{filetype}"
            api_response = api.put_picture(gift.temp_picture_path, content_type, {:message => gift.description})
            # api_response = {"id"=>"1396226023933952", "post_id"=>"100006397022113_1396195803936974"} (Hash)
            api_gift.api_gift_id = api_response['post_id']
          else
            # status post without picture
            api_response = api.put_connections('me', 'feed', :message => gift.description)
            # api_response = {"id"=>"100006397022113_1396235850599636"}
            api_gift.api_gift_id = api_response['id']
          end
          puts "api_response = #{api_response} (#{api_response.class.name})"
          gift_posted_on_wall_api_wall = 2 # Gift posted in here and on your facebook wall
        rescue Koala::Facebook::ClientError => e
          puts 'Koala::Facebook::ClientError'
          puts "e.fb_error_type = #{e.fb_error_type}"
          puts "e.fb_error_code = #{e.fb_error_code}"
          puts "e.fb_error_subcode = #{e.fb_error_subcode}"
          puts "e.fb_error_message = #{e.fb_error_message}"
          puts "e.http_status = #{e.http_status}"
          puts "e.response_body = #{e.response_body}"
          puts "e.fb_error_type.class.name = #{e.fb_error_type.class.name}"
          puts "e.fb_error_code.class.name = #{e.fb_error_code.class.name}"
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
            end
          else
            # unhandled exceptions
            gift_posted_on_wall_api_wall = 1 # unknown error. no translation
            error = e.to_s
          end
        rescue Koala::Facebook::ServerError => e
          puts 'Koala::Facebook::ServerError'
          puts "e.fb_error_type = #{e.fb_error_type}"
          puts "e.fb_error_code = #{e.fb_error_code}"
          puts "e.fb_error_subcode = #{e.fb_error_subcode}"
          puts "e.fb_error_message = #{e.fb_error_message}"
          puts "e.http_status = #{e.http_status}"
          puts "e.response_body = #{e.response_body}"
          puts "e.fb_error_type.class.name = #{e.fb_error_type.class.name}"
          puts "e.fb_error_code.class.name = #{e.fb_error_code.class.name}"
          # e.fb_error_type = Exception
          # e.fb_error_code = 1366046
          # e.fb_error_subcode =
          # e.fb_error_message = There was a problem with the image file.
          # e.http_status = 500
          # e.response_body = {"error":{"type":"Exception","message":"There was a problem with the image file.","code":1366046}}
          # e.fb_error_type.class.name = String
          # e.fb_error_code.class.name = Fixnum
          gift_posted_on_wall_api_wall = 1 # unknown error. no translation
          error = fb_error_message.to_s
        end # rescue
      else
        gift_posted_on_wall_api_wall = 3
      end # if

      if gift_posted_on_wall_api_wall != 2
        api_gift.picture = 'N'
        api_gift.save!
        options = {:apiname => login_user.api_name_without_brackets, :error => error}
        if gift_posted_on_wall_api_wall == 3
          # url to add missing privs. to post on facebook wall
          oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, 'http://localhost/gifts/')
          state = session[:state] = String.generate_random_string(30)
          url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => state)
          options[:url] = url
        end
        return ".gift_posted_#{gift_posted_on_wall_api_wall}_html", options
      else
        # get url for picture
        if api_gift.picture == 'Y'
          # todo: fb pictures too small - it should be possible to get url for a larger picture from fb
          # get temporary picture url - may change - url change is catched in onerror in img in html page
          # api_request = "#{gift.api_gift_id}?fields=full_picture"
          # api_request = gift.api_gift_id.split('_').join('/picture/') + '?type=normal' # still small picture
          # api_request = gift.api_gift_id.split('_').join('/picture/')  + '?fields=full_picture' # empty response (302 redirect) with profile picture
          # puts "api_request = #{api_request}"
          begin
            api_gift.api_picture_url = api_gift.get_api_picture_url(token)
            if api_gift.api_picture_url
              # valid picture url received from api
              api_gift.api_picture_url_updated_at = Time.now
              api_gift.api_picture_url_on_error_at = nil
              api_gift.save!
            else
              puts "Did not get a picture url from api. Must be problem with missing access token, picture != Y or deleted_at_api == Y"
              return ['.no_api_picture_url', :apiname => login_user.api_name_without_brackets]
            end
          rescue ApiPostNotFoundException => e
            # problem with picture uploads and permissions
            # could not get full_picture url for an uploaded picture with visibility friends
            # the problem appeared after changing app visibility from public to friends
            # that is - app is not allowed to get info about the uploaded picture!!
            # there must be more to it - changed visibility to only me and did get picture url
            # changed visibility to friends and did get the picture url
            # just display a warning and continue. Request read_stream permission from user if read_stream priv. is missing
                       # todo: add ajax show/inject link to grant read_stream permission in gifts/index page
              flash[:read_stream] = 'Missing read_stream permission' # display link to grant read_stream permission in gifts/index page
   if login_user.read_gifts_allowed?
              # check if user has removed read stream priv.
              login_user.get_api_permissions(session[:access_token])
            end
            if login_user.read_gifts_allowed?
              # error - this should not happen.
              return ['.picture_upload_unknown_problem', :appname => APP_NAME, :apiname => login_user.api_name_without_brackets]
            else
              # flash with request for read stream privs
              # todo: add ajax show/inject link to grant read_stream permission in gifts/index page. see gift_posted_3_html
              flash[:read_stream] = 'Missing read_stream permission' # display link to grant read_stream permission in gifts/index page
              return ['.picture_upload_missing_permission', :appname => APP_NAME, :apiname => login_user.api_name_without_brackets]
            end
            api_gift.picture = 'N'
            api_gift.save!
          end # rescue

        end # picture == 'Y'
        # no errors - return posted message
        return [".gift_posted_#{gift_posted_on_wall_api_wall}_html", :apiname => login_user.api_name_without_brackets, :error => error]
      end

    rescue Exception => e
      puts "post_on_facebook:"
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_on_facebook

  # post on google+ not implemented. The Google+ API is still a read only API
  # private
  # def post_on_google_oauth2 (id)
  # end

  def post_on_linkedin (id)
    begin
      # get login user and api access token
      provider = "linkedin"
      login_user, token, key, options = get_login_user_and_token(provider)
      return [key, options] if key

      # get and check gift
      gift = Gift.find_by_id(id)
      return ['.post_on_api_unknown_gift_id', { :provider => provider, :id => id }] unless gift
      return ['.post_on_api_invalid_gift_id', { :provider => provider, :id => gift.id }] unless [gift.user_id_giver, gift.user_id_receiver].index(login_user.user_id)
      return ['.post_on_api_old_gift', { :provider => provider, :id => gift.id }] unless gift.created_at > 5.minute.ago

      # create client for linkedin api requests
      client = LinkedIn::Client.new ENV['GOFREEREV_LI_APP_ID'], ENV['GOFREEREV_LI_APP_SECRET']
      client.authorize_from_access token[0], token[1] # token and secret
      puts "GOFREEREV_LI_APP_ID = #{ENV['GOFREEREV_LI_APP_ID']}"
      puts "GOFREEREV_LI_APP_SECRET = #{ENV['GOFREEREV_LI_APP_SECRET']}"
      puts "token = #{token[0]}"
      puts "secret = #{token[1]}"

      x = client.add_share(:comment => gift.description)
      puts "x = #{x}"

      nil

    rescue Exception => e
      puts "post_on_linkedin:"
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_on_linkedin

  # delete local picture file that was used when posting picture in api wall(s) - see post_on_facebook etc.
  def delete_local_picture (id)
    begin
      puts "ajax task: delete_local_picture"

      # get and check gift
      gift = Gift.find_by_id(id)
      return ['.post_on_api_unknown_gift_id', { :provider => 'API', :id => id }] unless gift
      return ['.post_on_api_old_gift', { :provider => 'API', :id => gift.id }] unless gift.created_at > 5.minute.ago

      # check local picture file
      return ['.no_local_picture', { :provider => provider, :id => id }] unless gift.temp_picture_filename
      return ['.local_picture_not_found', { :provider => provider, :id => id }] unless File.exist?(gift.temp_picture_path)

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
      puts "delete_local_picture:"
      puts "Exception: #{e.message.to_s} (#{e.class})"
      puts "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # delete_local_picture
  
  
end # UtilController

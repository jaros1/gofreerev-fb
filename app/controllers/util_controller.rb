class UtilController < ApplicationController

  # update new message count in menu line in page header
  # called from hidden check-new-messages-link link in page header once every 15, 60 or 300 seconds
  # new_message_count is also ajax injecting gifts and comments into gifts pages
  # Parameters: {"request_fullpath"=>"/gifts", "newest_gift_id"=>"275", "newest_status_update_at"=>"417"}
  # - request_fullpath is request path for current page where ajax request was send from
  # - newest_gift_id is newest gift id when page was loaded or newest gift id in last new_messages_count request for this session
  # - newest_status_update_at is newest status_update_at when page was loaded or newest status_update_at in last new_message_count request for this session
  def new_messages_count
    if !@user
      puts "ignoring not logged in user"
      render :nothing => true
      return
    end
    # cleanup - destroy old delete marked gifts
    # gift was marked as deleted in util/delete_gift request
    # gift has been ajax removed from  gifts pages for other sessions in previous util/new_message_count requests
    # now is the time to destroy old delete marked gifts
    Gift.where("? in (user_id_giver, user_id_received) and deleted_at is not null and deleted_at < ?", @user.user_id, 10.minutes.ago) do |g|
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
      # source 2 - all visible gifts, but only comments with status_update_at > :newest_status_update_at
      friends = @user.app_friends.collect { |u| u.user_id_receiver }
      friends.push(@user.user_id)
      @comments = Comment.includes(:gift).where("(comment_id in (?)) or " +
                                                    "((gifts.user_id_giver in (?) or gifts.user_id_receiver in (?)) and " +
                                                    "gifts.deleted_at is null and " +
                                                    "comments.status_update_at > ?)",
                                                com_ids,
                                                friends, friends, old_newest_status_update_at).references(:gifts)
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
      @gifts = @user.gifts(old_newest_gift_id, old_newest_status_update_at)
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
    return unless params[:gifts].has_key?(:ids)
    return if  params[:gifts][:ids] == ''
    ids = params[:gifts][:ids].split(',')
    gs = Gift.find(ids)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
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
    if !gift.visible_for(@user)
      puts "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_reject_new_deal_link?(@user)
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
    if !gift.visible_for(@user)
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
    AjaxTask.where("session_id = ?", session[:session_id]).order("id").each do |at|
      at.destroy
      begin
        res = eval(at.task)
      rescue Exception => e
        puts "error when processing ajax task #{at.task}"
        puts "Exception: #{e.message.to_s}"
        puts "Backtrace: " + e.backtrace.join("\n")
        res = [ '.ajax_task_exception', { :task => at.task, :exception => e.message.to_s }]
      end
      # puts "ajax task #{at.task}, response = #{res}, no tasks = #{session[:ajax_tasks].size}"
      next unless res
      # check response from ajax task. Must be a valid input to translate
      begin
        key, options = res
        t key, options
      rescue Exception => e
        puts "invalid response from ajax task #{at.task}. Must be nil or a valid input to translate. Response: #{res}"
        res = [ '.ajax_task_invalid_response', { :task => at.task, :response => res, :exception => e.message.to_s }]
      end
      @errors << res
    end
    if @errors.size == 0
      render :nothing => true
      return
    end
  end # do_ajax_tasks

  # post login ajax task for facebook - get permissions and friends - using koala gem
  # called from do_ajax_tasks - ajax requests after login
  # must return nil or a valid input to translate
  private
  def post_login_facebook
    provider = "facebook"
    puts "post_login_#{provider}"

    # find user id and token for facebook user
    login_user_id = (session[:user_ids] || []).find { |user_id2| user_id2.split('/').last == provider }
    return ['.post_login_user_id_not_found', {:provider => provider}] unless login_user_id
    login_user = User.find_by_user_id(login_user_id)
    return ['.post_login_unknown_user_id', {:provider => provider, :user_id => login_user_id}] unless login_user
    token = (session[:tokens] || {})[provider]
    return ['.post_login_token_not_found', {:provider => provider}] if token.to_s == ""

    # get user information - permissions and friends  - use koala gem for this
    # puts 'fetch_user: get user id and name'
    api = Koala::Facebook::API.new(token)
    api_request = 'me?fields=permissions,friends'
    # puts "fetch_user: api_request = #{api_request}"
    api_response = api.get_object api_request
    # puts "fetch_user: api_response = #{api_response.to_s}"
    #fetch_user: api_response = {"id"=>"100006397022113", "friends"=>{"data"=>[{"name"=>"David Amfcdabcjbif Martinazzisen", "id"=>"100006341230296"}, {"name"=>"Dick Amfceacglc Bushakson", "id"=>"100006351370003"}, {"name"=>"Karen Amfchcebfhjf Smithescu", "id"=>"100006383526806"}, {"name"=>"Sandra Amfciidbbaee Qinsen", "id"=>"100006399422155"}], "paging"=>{"next"=>"https://graph.facebook.com/100006397022113/friends?access_token=CAAFjZBGzzOkcBAFgvgvY7DmLBrzbKFuOiULN248i3AWlSNWqzzTLLINmRjDSM2djyQriVkcKnVJ80pRz3TiJ1koCNcOPU1ioy40aHHuAZCSXovba3pz74db08a6obnrABFZCgEMwX8cKStw25hwvyqkF1YHiV8d2yV5YoFytaI9hGYyCgk3&limit=5000&offset=5000&__after_id=100006399422155"}}, "permissions"=>{"data"=>[{"installed"=>1, "basic_info"=>1, "status_update"=>1, "photo_upload"=>1, "video_upload"=>1, "email"=>1, "create_note"=>1, "share_item"=>1, "publish_stream"=>1, "publish_actions"=>1, "user_friends"=>1, "bookmarked"=>1}], "paging"=>{"next"=>"https://graph.facebook.com/100006397022113/permissions?access_token=CAAFjZBGzzOkcBAFgvgvY7DmLBrzbKFuOiULN248i3AWlSNWqzzTLLINmRjDSM2djyQriVkcKnVJ80pRz3TiJ1koCNcOPU1ioy40aHHuAZCSXovba3pz74db08a6obnrABFZCgEMwX8cKStw25hwvyqkF1YHiV8d2yV5YoFytaI9hGYyCgk3&limit=5000&offset=5000"}}}

    # 1) update number of friends
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
    old_friends_list = Friend.where('user_id_giver = ?', login_user_id).includes(:friend)
    if api_response.has_key?('friends')
      api_friends_list = api_response['friends']['data']
    else
      api_friends_list = [] # no api friends
    end
    # merge friend info from db and fb before db update
    friends_hash = {}
    (0..(old_friends_list.size-1)).each do |i|
      old_friend = old_friends_list[i]
      old_friend.friend.user_name = old_friend.friend.user_name.force_encoding('UTF-8')
      login_user_id = old_friend.user_id_receiver
      friends_hash[login_user_id] = {:user => old_friend.friend, :old_name => old_friend.friend.user_name, :new_name => old_friend.friend.user_name, :old_api_friend => old_friend.api_friend, :new_api_friend => 'N', :new_record => false}
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
    # update user names
    friends_hash.each do |user_id2, hash|
      next if hash[:old_name] == hash[:new_name]
      # puts "fetch_user: update user names: old name = #{hash[:old_name]}, new name = #{hash[:new_name]}"
      login_user = hash[:user]
      login_user.user_name = hash[:new_name].force_encoding('UTF-8')
      login_user.save!
    end # each
    # update api_fiend
    friends_hash.each do |user_id2, hash|
      if hash[:new_record]
        # new friend entries
        # puts "new friend entries"
        Friend.add_friend(login_user_id, user_id2)
      else
        # old friend entry
        # puts "old friend entry, name = #{hash[:new_name]}, old api friend = #{hash[:old_api_friend]}, new api friend = #{hash[:new_api_friend]}"
        next if hash[:old_api_friend] == hash[:new_api_friend] # no change in api friend status
                                                               # api friend status changed
        f1 = Friend.where("user_id_giver = ? and user_id_receiver = ?", login_user_id, user_id2).first
        f2 = Friend.where("user_id_giver = ? and user_id_receiver = ?", user_id2, login_user_id).first
        if (f1 == nil or f1.app_friend == nil) and (f2 == nil or f2.app_friend == nil)
          # Default app_friend status - just delete
          # puts "Default app_friend status - just delete"
          Friend.remove_friend(login_user_id, user_id2)
          next
        end
        # non default app_friend status - update - do not delete
        if !f1
          # create missing friend (error)
          f1 = Friend.new
          f1.user_id_giver = login_user_id
          f1.user_id_receiver = user_id2
          f1.app_friend = nil
        end
        if !f2
          # create missing friend (error)
          f2 = Friend.new
          f1.user_id_giver = user_id2
          f1.user_id_receiver = login_user_id
          f2.app_friend = nil
        end
        f1.api_friend = f2.api_friend = hash[:new_api_friend]
        # puts "before save"
        # puts "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
        # puts "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
        f1.save!
        f2.save!
        # puts "after save"
        f1.reload
        f2.reload
        # puts "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
        # puts "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
        raise "api_friend status was not updated" unless f1.api_friend == hash[:new_api_friend] and f2.api_friend == hash[:new_api_friend]
      end # if
    end # each
    # facebook friend list updated

    # 3) update balance
    login_user.recalculate_balance if login_user.balance_at != Date.today

    # ok
    nil

  end # post_login_facebook


end # UtilController

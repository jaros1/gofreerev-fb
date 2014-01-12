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
      logger.debug2  "ignoring not logged in user"
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
      # logger.debug2  "find comments to ajax insert in gifts/index or gifts/show pages"
      # two sources for comments to ajax insert into gifts table
      # source 1 - comments selected to be ajax inserted for this user - todo: check where AjaxCommment is initialized
      com_ids = AjaxComment.where("user_id = ?", @user.user_id).collect { |ac| ac.comment_id }
      com_ids.push('x') if com_ids.size == 0
      # logger.debug2  "com_ids.length = #{com_ids.length}"
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
        # logger.debug2  "new comments before gift_id filter = #{@comments.length}"
        @comments = @comments.find_all { |c| c.gift.id.to_s == $1 }
        # logger.debug2  "new comments after gift_id filter = #{@comments.length}"
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
        # logger.debug2  "#{old_size-new_size} comments for hidden gifts was removed" if old_size != new_size
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
      # logger.debug2  "remove any comments that is included in gifts"
      # logger.debug2  "old @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
      @comments = @comments.delete_if { |c| @api_gifts.find_all { |g| c.gift_id == g.gift_id }.first }
      @comments = nil if @comments.size == 0
      # logger.debug2  "new @comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    end
    logger.debug2  "@gifts.size = #{@api_gifts.size}, gifts = " + @api_gifts.collect { |g| g.id }.join(', ') if @api_gifts
    logger.debug2  "@comments.size = #{@comments.size}, comments = " + @comments.collect { |c| c.id }.join(', ') if @comments
    logger.debug2  "@new_newest_gift_id = #{@new_newest_gift_id}"
    logger.debug2  "@new_newest_status_update_at = #{@new_newest_status_update_at}"
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
    @errors = []
    begin
      if !params.has_key?("api_gifts") or !params[:api_gifts].has_key?(:ids) or params[:api_gifts][:ids] == ''
        @errors << ['.mis_api_pic_no_param', {}]
        return
      end
      ids = params[:api_gifts][:ids].split(',')
      logger.debug2 "ids = #{ids}"
      api_gifts = ApiGift.where("id in (?)", ids)

      # get new picture urls if possible. Stategies for finding a new valid url:
      # 1) api_gift_id and deleted_at_api != 'Y'
      #    1a) logged in as creator - recheck api wall
      #    1b) not logged in as creator - skip - check later with creator login
      # 2) no api_gift_id or deleted_at_api == 'Y'
      #    2a) other provider with an valid api_gift_url - use url as workaround - mark invalid urls with error timestamp
      #    2b) invalid url and api_gift_id and deleted_at_api != 'Y' and logged in as creator - recheck api wall and use if valid
      #    2b) invalid url and api_gift_id and deleted_at_api != 'Y' and not

      # todo: 3 - max request picture url once every hour
      tokens = session[:tokens]
      if !tokens
        @errors << ['.mis_api_pic_no_tokens', {}]
        return
      end
      return unless tokens
      api_clients = {}
      api_gifts.each do |api_gift|
        if !api_gift.picture? or api_gift.api_picture_url.to_s == ""
          logger.debug2 "Ignoring api_gift #{api_gift.id} where picture has been deleted (refresh gifts/index page in browser)"
          next
        end
        if Picture.app_url?(api_gift.api_picture_url)
          # local url / picture on server, but picture was not found (by browser)
          # check if file exists. Could be a file protection problems
          full_os_path = Picture.full_os_path :url => api_gift.api_picture_url
          rel_path = Picture.rel_path :url => api_gift.api_picture_url
          if File.exists? full_os_path
            # picture exists on filesystem but was reported as missing by browser/js
            # must be invalid file protection for /images/temp/ or /images/perm/ folder
            logger.error2 "picture #{rel_path} exists in file system but was not found by browser. check file protection"
            @errors << ['.mis_api_pic_file_exists', {:rel_path => rel_path}]
            next
          end
          # local picture file has been deleted. Continue. Maybe picture is available from an other api provider
        else
          # api url. recheck that picture has move or has been deleted
          image_type = FastImage.type(api_gift.api_picture_url).to_s
          if %w(jpg jpeg gif png bmp).index(image_type)
            # api url still exists. Could be a temporary problem
            logger.warn2 "api gift #{api_gift.id} url #{api_gift.api_picture_url} exists, but was not found by browser"
            @errors << ['.mis_api_pic_url_exists', {:url => api_gift.api_picture_url}]
            next
          end
        end
        # correct that api picture url does not exist - error mark api gift
        api_gift.api_picture_url_on_error_at = Time.now
        api_gift.save!

        # check api wall - skip check if logged in user not is creator of post/picture
        created_by_user_id = api_gift.gift.created_by == 'giver' ? api_gift.user_id_giver : api_gift.user_id_receiver
        created_by_user = login_user_ids.index(created_by_user_id)
        if api_gift.api_gift_id and api_gift.deleted_at_api != 'Y' and !created_by_user
          # recheck api wall later as user created_by_user_id
          logger.debug2 "check api gift #{api_gift.id} later with creator #{created_by_user_id} permissions"
          next
        end

        # check api wall. logged in user is creator of post/picture
        if api_gift.api_gift_id and api_gift.deleted_at_api != 'Y'
          # check api wall

          # check/initialize api client
          api_client = api_clients[api_gift.provider]
          if !api_client
            # initialize api client for provider
            token = tokens[api_gift.provider]
            if !token
              logger.warn2 "received api_gift.id #{api_gift.id} for provider #{api_gift.provider}, but user is not connected with provider #{api_gift.provider}"
              @errors << ['.mis_api_pic_no_token', { :apiname => provider_downcase(api_gift.provider)}]
              next
            end
            case api_gift.provider
              when 'facebook' then
                api_client = Koala::Facebook::API.new(token)
              when 'twitter' then
                api_client = init_api_client_twitter(token)
              else
                logger.error2 "initialize api client for #{api_gift.provider} not implemented, api_gift.id = #{api_gift.id}"
                @errors << ['.mis_api_pic_not_implemented1', { :apiname => provider_downcase(api_gift.provider)} ]
                next
            end
            api_clients[api_gift.provider] = api_client
          end
          # api client initialized

          # get new picture url from API
          begin
            # check api wall
            case api_gift.provider
              when 'facebook'
                key, options = get_api_picture_url_facebook(api_gift, false, api_client)
              when 'twitter'
                key, options = get_api_picture_url_twitter(api_gift, false, api_client)
              else
                logger.error2 "No get_api_picture_url_#{api_gift.provider} method"
                @errors << ['.mis_api_pic_not_implemented2', { :apiname => provider_downcase(api_gift.provider)} ]
                next2
            end
            if key
              @errors << [key, options]
              next
            end
            # ok - post/picture os still on api wall and new api gift picture url has been received
            next
          rescue ApiPostNotFoundException => e
            # identical api error response if picture is deleted or if user is not allowed to see picture
            logger.debug2 "api gift #{api_gift.id} has been deleted on #{api_gift.provider} wall."
            api_gift.deleted_at_api = 'Y'
            api_gift.save!
            # Continue. Maybe picture url is available from an other api provider
          end # rescue

          # end check api wall
        end

        # api gift no longer on api wall. Check if picture url is available from an other api provider
        # that is - user was logged in with multiple api providers when gift was created
        # could be local perm path for linked used for a linkedin api gift
        # could be a facebook api url used for an not facebook api provider
        api_gift.reload
        new_api_picture_url = nil
        api_gift.gift.api_gifts.delete_if { |ag| ag.id == api_gift.id }.each do |api_gift2|
          next if !api_gift2.picture?
          next if api_gift2.api_picture_url_on_error_at
          next if api_gift2.api_picture_url.to_s == ""
          image_type2 = FastImage.type(api_gift2.api_picture_url).to_s
          logger.debug2 "api_gift: provider #{api_gift2.provider}, api_picture_url = #{api_gift2.api_picture_url}, image_type2 = #{image_type2}"
          next unless %w(jpg jpeg gif png bmp).index(image_type2)
          new_api_picture_url = api_gift2.api_picture_url
          break
        end # each api_gift2
        if !new_api_picture_url
          logger.debug2 "api_gift id #{api_gift.id} - did not found api picture url for other provider"
          api_gift.picture = 'N'
          api_gift.save!
          next
        end

        # use api_picture_url from other provider
        logger.debug2 "api gift id #{api_gift.id} - found api picture url for an other provider"
        logger.debug2 "old provider #{api_gift.provider}"
        logger.debug2 "url = #{new_api_picture_url}"
        api_gift.api_picture_url = new_api_picture_url
        api_gift.api_picture_url_on_error_at = nil
        api_gift.save!

      end # each api_gift
    rescue Exception => e
      logger.debug2 "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2 "Backtrace: " + e.backtrace.join("\n")
      @errors << ['.mis_api_pic_exception', {:error => e.message} ]
    end
  end # missing_api_picture_urls


  #
  # gift link ajax methods
  #

  def like_gift
    gift_id = params[:gift_id]
    gift = Gift.find_by_id(gift_id)
    if !gift
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    gl = GiftLike.where("user_id = ? and gift_id = ?", @user.user_id, gift.gift_id).first
    if !gl or gl.like != 'Y'
      logger.debug2  "Non previous like was found for user #{@user.short_user_name} and gift id #{gift_id}"
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
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
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
      logger.debug2  "Gift with id #{gift_id} was not found - silently ignore ajax request"
      return
    end
    if !gift.show_delete_gift_link?(@users)
      logger.debug2  "user is not allowed to delete gift id #{gift_id} - silently ignore ajax request"
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
      logger.debug2  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_cancel_new_deal_link?(@user)
      logger.debug2  "cancel link no longer active for comment with id #{comment_id} - silently ignore ajax request"
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
      logger.debug2  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_reject_new_deal_link?(@users)
      logger.debug2  "reject link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # reject agreement proposal
    comment.accepted_yn = 'N'
    comment.save!
    # hide links
    # todo: other comment changes? Maybe an other layout, style, color for accepted gift/comments
    # todo: change gift and comment for other users after reject (new messages count ajax)?
    @link_id = "gift-#{gift.id}-comment-#{comment.id}-reject-link"
    logger.debug2  "link_id = #{@link_id}"
  end # reject_new_deal

  def accept_new_deal
    comment_id = params[:comment_id]
    comment = Comment.find_by_id(comment_id)
    if !comment
      logger.debug2  "Comment with id #{comment_id} was not found - silently ignore ajax request"
      return
    end
    gift = comment.gift
    if !gift.visible_for?(@users)
      logger.debug2  "#{@user.short_user_name} is not allowed to see gift id #{gift_id} - silently ignore ajax request"
      return
    end
    if !comment.show_accept_new_deal_link?(@user)
      logger.debug2  "accept link not active for comment with id #{comment_id} - silently ignore ajax request"
      return
    end
    # accept agreement proposal - mark proposal as accepted - callbacks sent notifications and updates gift
    # logger.debug2  "comment.currency = #{comment.currency}"
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
      logger.debug2  "return currencies to client on onfocus event"
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
      logger.debug2  ""
      logger.debug2  "executing task #{at.task}\n"
      res = nil
      begin
        res = eval(at.task)
      rescue Exception => e
        logger.debug2  "error when processing task #{at.task}"
        logger.debug2  "Exception: #{e.message.to_s}"
        logger.debug2  "Backtrace: " + e.backtrace.join("\n")
        res = [ '.ajax_task_exception', { :task => at.task, :exception => e.message.to_s }]
      end
      # logger.debug2  "task #{at.task}, response = #{res}"
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
        logger.debug2  "exception = #{e.message.to_s}"
        logger.debug2  "response = #{res}"
        argument = $1 if e.message.to_s =~ /:(.+?)\s/
        logger.debug2  "argument = #{argument}"
        res = [ '.ajax_task_missing_translate_arg', { :key => key, :task => at.task, :argument => argument, :response => res, :exception => e.message.to_s } ]
      rescue Exception => e
        logger.debug2  "invalid response from task #{at.task}. Must be nil or a valid input to translate. Response: #{res}"
        res = [ '.ajax_task_invalid_response', { :task => at.task, :response => res, :exception => e.message.to_s }]
      end
      # logger.debug2  "task = #{at.task}, res = #{res}"
      @errors << res
    end
    logger.debug2 "@errors.size = #{@errors.size}"
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
    # logger.debug2  "token = #{token}"
    # ok
    return [login_user, token]
  end


  # helper to get information to be used in post_login_<provider> methods
  # return array with login_user, friends_hash, token, key and options - key and options only if error
  private
  def get_user_friends_and_token(provider)
    logger.debug2  "provider = #{provider}"
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
    return [gift, api_gift, deep_link, 'gift_posted_6_html', { :apiname => provider}] if api_gift.picture? and !gift.rel_path_picture_exists?

    # initialize and check deep link
    deep_link = api_gift.init_deep_link()
    if error = api_gift.deep_link_invalid?
      # error in deep link page - stop post on API and return error message with deep link and error to gifts/index page
      return [gift, api_gift, deep_link, ".gift_posted_7_html", { :apiname => provider, :link => deep_link, :error => error }]
    end

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

      # get user information - permissions, friends and picture  - koala gem is used for facebook api requests
      # logger.debug2  'get user id and name'
      api = Koala::Facebook::API.new(token)
      api_request = 'me?fields=permissions,friends,picture'
      # logger.debug2  "api_request = #{api_request}"
      api_response = api.get_object api_request
      logger.debug2  "api_response = #{api_response.to_s}"
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

      # logger.debug2  "permissions = #{login_user.permissions}"
      # logger.debug2  "post_gift_allowed? = #{login_user.post_gift_allowed?}"

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
        # logger.debug2 "friend = #{friend}"
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
            friend_user.post_on_wall_yn = 'Y'
            friend_user.save!
          end
          friends_hash[friend_user_id] = {:user => friend_user, :old_name => friend_user.user_name, :old_api_friend => 'N', :new_record => true}
        end
        friends_hash[friend_user_id][:new_name] = friend["name"]
        friends_hash[friend_user_id][:new_api_friend] = 'Y'
      end # each

      # update facebook friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, true,%w(name))
      # facebook friend list updated

      # 3) update profile picture
      image = api_response['picture']['data']['url'] if api_response['picture'] and api_response['picture']['data']
      logger.debug2 "image = #{image}"
      key, options = User.update_profile_image(login_user_id, image)
      return [key, options] if key # error when updating profile picture information

      # ok
      nil
    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s}"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_login_facebook


  # post login task for google+
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
      # logger.debug2  "token = #{token}"
      client = Google::APIClient.new(
          :application_name => 'Gofreerev',
          :application_version => '0.1'
      )
      # client = Google::APIClient.new
      plus = client.discovered_api('plus')
      client.authorization.client_id = API_ID[provider]
      client.authorization.client_secret = API_SECRET[provider]
      client.authorization.access_token = token
      # logger.debug2 "token = #{token}"

      # find people in login user circles
      # https://developers.google.com/api-client-library/ruby/guide/pagination
      request = {:api_method => plus.people.list,
                 :parameters => {'collection' => 'visible', 'userId' => 'me'}}

      # loop for all google+ friends
      loop do

        result = client.execute(request)
        # logger.debug2  "result = #{result}"
        # logger.debug2  "result.error_message.class = #{result.error_message.class}"
        # logger.debug2  "result.error_message = #{result.error_message}"
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
        # logger.debug2  "result.data.class = #{result.data.class}"
        # logger.debug2  "result.data = #{result.data}"
        # logger.debug2  "result.data.total_items = #{result.data.total_items}"

        # known errors from Google API
        return ['.google_access_not_configured', {:provider => provider}] if result.error_message.to_s == 'Access Not Configured'
        return ['.google_insufficient_permission', {:provider => provider}] if result.error_message.to_s == 'Insufficient Permission'
        # other errors from Google API
        return ['.google_other_errors', {:provider => provider, :error => result.error_message}] if !result.data.total_items

        # copy friends to hash.
        # logger.debug2  "result.data.items = #{result.data.items}"
        # todo: check friend.kind = plus#person - maybe ignore rows with friend.kind != plus#person
        # todo: returns profile picture urls with size 50 x 50 (?sz=50) - replace with ?sz=100 ?
        for friend in result.data.items do
          # logger.debug2  "friend = #{friend} (#{friend.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            friend_user = friends_hash[friend_user_id][:user]
          else
            # new google friend
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend.display_name.force_encoding('UTF-8')
              friend_user.api_profile_url = friend.url
              friend_user.api_profile_picture_url = friend.image.url
              friend_user.post_on_wall_yn = 'N'
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user,
                                            :old_name => friend_user.user_name,
                                            :old_api_profile_url => friend_user.api_profile_url,
                                            :old_api_profile_picture_url => friend_user.api_profile_picture_url,
                                            :old_api_friend => 'N',
                                            :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend.display_name.force_encoding('UTF-8')
          friends_hash[friend_user_id][:new_api_profile_url] = friend.url
          friends_hash[friend_user_id][:new_api_profile_picture_url] = friend.image.url
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
        end # item
        # next page - get more friends if any
        break unless result.next_page_token
        request = result.next_page
      end # loop for all google+ friends

      # update google+ friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, false,%w(name api_profile_url api_profile_picture_url))
      # google+ friends updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil
    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s}"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
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
      # logger.debug2 "token = #{token.join(', ')}"

      ## get public profile url for login user
      #profile = client.profile :fields=>['public-profile-url']
      #public_profile_url = profile.public_profile_url
      #logger.debug2 "public_profile_url = #{public_profile_url}"

      # todo: count number of connections retured from linkedin
      # todo: handle nil array returned from linkedin (r_network missing in scope)

      no_linkedin_connections = 0
      begin
        # http://developer.linkedin.com/documents/profile-fields#profile
        fields = %w(id,first-name,last-name,public-profile-url,picture-url,num-connections)
        client.connections(:fields => fields).all.each do |connection|
          no_linkedin_connections += 1
          logger.debug2 "connection = #{connection} (#{connection.class})"
          logger.debug2 "connection.public_profile_url = #{connection.public_profile_url}"
          # copy friend to friends_hash
          friend_user_id = "#{connection.id}/#{provider}"
          friend_name = "#{connection.first_name} #{connection.last_name}".force_encoding('UTF-8')
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            friend_user = friends_hash[friend_user_id][:user]
          else
            # new google friend
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend_name
              friend_user.api_profile_url = connection.public_profile_url if connection.public_profile_url
              friend_user.api_profile_picture_url = connection.picture_url
              friend_user.no_api_friends = connection.num_connections
              friend_user.post_on_wall_yn = 'Y'
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user,
                                            :old_name => friend_user.user_name,
                                            :old_api_profile_url => friend_user.api_profile_url,
                                            :old_api_profile_picture_url => friend_user.api_profile_picture_url,
                                            :old_no_api_friends => friend_user.no_api_friends,
                                            :old_api_friend => 'N',
                                            :new_record => true}
          end
          friends_hash[friend_user_id][:new_name] = friend_name
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
          friends_hash[friend_user_id][:new_api_profile_url] = connection.public_profile_url if connection.public_profile_url
          friends_hash[friend_user_id][:new_api_profile_picture_url] = connection.picture_url
          friends_hash[friend_user_id][:new_no_api_friends] = connection.num_connections
        end # connection loop
      rescue LinkedIn::Errors::AccessDeniedError => e
        return ['.linkedin_access_denied', {:provider => provider}] if e.message.to_s =~ /Access to connections denied/
        raise
      end
      logger.debug2 "Found #{no_linkedin_connections} #{provider} connections"

      # update linkedin connections
      Friend.update_friends_from_hash(login_user_id, friends_hash, false,%w(name api_profile_url api_profile_picture_url no_api_friends))
      # linkedin connections updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil

    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
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

      # create client for twitter api requests
      client = init_api_client_twitter(token)

      no_twitter_friends = 0
      begin
        client.friends.to_a.each do |friend|
          no_twitter_friends += 1
          # logger.debug2 "friend.url = #{friend.url} (#{friend.url.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          friend_name = friend.name.dup.force_encoding('UTF-8')
          if friends_hash.has_key?(friend_user_id)
            # OK - user already in hash
            friend_user = friends_hash[friend_user_id][:user]
          else
            # new google friend - create user if friend does not exists
            if !(friend_user = User.where("user_id = ?", friend_user_id).first)
              # create unknown user - create user with minimal user information (user id and name)
              friend_user = User.new
              friend_user.user_id = friend_user_id
              friend_user.user_name = friend_name
              friend_user.api_profile_url = friend.url.to_s
              friend_user.api_profile_picture_url = friend.profile_image_url
              friend_user.no_api_friends = friend.friends_count
              friend_user.post_on_wall_yn = 'Y'
              friend_user.save!
            end
            friends_hash[friend_user_id] = {:user => friend_user,
                                            :old_name => friend_user.user_name,
                                            :old_api_profile_url => friend_user.api_profile_url,
                                            :old_api_profile_picture_url => friend_user.api_profile_picture_url,
                                            :old_no_api_friends => friend_user.no_api_friends,
                                            :old_api_friend => 'N',
                                            :new_record => true}
          end
          # only blank api_profile_picture_url is updated
          # omniauth login returns a size 73 x 73 profile picture (bigger)
          # friends list returns url to a size 48 x 48 profile picture (normal)
          friends_hash[friend_user_id][:new_name] = friend_name
          friends_hash[friend_user_id][:new_api_profile_url] = friend.url.to_s
          friends_hash[friend_user_id][:new_api_profile_picture_url] = friend_user.api_profile_picture_url || friend.profile_image_url.to_s
          friends_hash[friend_user_id][:new_no_api_friends] = friend.friends_count
          friends_hash[friend_user_id][:new_api_friend] = 'Y'
        end # connection loop
      end

      # update twitter friends
      Friend.update_friends_from_hash(login_user_id, friends_hash, false,%w(name api_profile_url api_profile_picture_url no_api_friends))
      # twitter friends updated

      # 3) update balance
      login_user.recalculate_balance if login_user.balance_at != Date.today

      # ok
      nil

    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
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
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # recalculate_user_balance


  # get url for api gift picture on facebook wall - size >= 200 x 200
  # used in post_in_facebook and in missing_api_picture_urls
  # raises ApiPostNotFoundException if post/picture was not found (missing permission or post/picture has been deleted)
  # that is - get_api_picture_url_facebook is also used to check for missing read stream permission
  # return nil (ok) or [key, options] error input to translate
  # params:
  # - just_posted - true if called from post_on_facebook - false if called from missing_api_picture_urls
  # - api_client - koala api client
  private
  def get_api_picture_url_facebook (api_gift, just_posted=true, api_client=nil) # api is Koala API client

    return nil if api_gift.deleted_at_api == 'Y' # ignore - post/picture has been deleted from facebook wall

    provider = "facebook"
    login_user, token, key, options = get_login_user_and_token(provider)
    return [key, options] if key

    if !api_client
      # get access token and initialize koala api client
      api_client = Koala::Facebook::API.new(token)
    end

    # two koala api request. 1) get picture and object_id, 2) get an array with different size pictures

    # 1) get picture and object id
    object_id = nil
    begin
      # check read access to facebook wall and get object_id for next api request (only for post with picture)
      res1 = api_client.get_object api_gift.api_gift_id
      # logger.debug2 "res1 = #{res1}"
      api_gift.api_gift_url = res1['link']
      object_id, picture = res1['object_id'], res1['picture']
      image_type = FastImage.type(picture) if picture.to_s != ""
      logger.debug2 "first lookup: object_id = #{object_id}, picture = #{picture}, image type = #{image_type}"
      if api_gift.picture?
        if %w(jpg jpeg gif png bmp).index(image_type.to_s)
          # valid (small) picture url received from facebook
          api_gift.api_picture_url = picture
          api_gift.api_picture_url_updated_at = Time.now
          api_gift.api_picture_url_on_error_at = nil
        else
          # unexpected error - found post, but did not get a valid picture url
          logger.debug2 "Did not get a picture url from api. Must be problem with missing access token, picture != Y or deleted_at_api == Y"
          logger.debug2 "res1 = #{res1}"
          return ['.no_api_picture_url', {:apiname => login_user.api_name_without_brackets}]
        end
      end
      api_gift.save!
    rescue Koala::Facebook::ClientError => e
      if e.fb_error_type == 'GraphMethodException' and e.fb_error_code == 100
        # identical error response if picture is deleted or if user is not allowed to see picture
        # picture not found - maybe picture has been deleted - maybe a permission problem
        # granting read_stream or changing visibility of app setting to public can solve the problem
        # read_stream permission will be requested if error is raise when posting on facebook wall

        # problem with upload and permissions
        # could not get full_picture url for an uploaded picture
        # or could not get mesaage for an post
        # the problem appeared after changing app visibility from public to friends
        # that is - app is not allowed to get info about the uploaded picture!!
        # there must be more to it - changed visibility to only me and did get picture url
        # changed visibility to friends and did get the picture url
        # just display a warning and continue. Request read_stream permission from user if read_stream priv. is missing
        api_gift.deleted_at_api = 'Y' if just_posted
        api_gift.save!
        # (re)check permissions
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
      else
        # unhandled koala / facebook exception
        e.logger = logger
        e.puts_exception("#{__method__}: ")
        raise
      end
    end # rescue
    return nil unless object_id # post without picture

    if object_id
      # post with picture
      # 2) get best size picture from facebook. picture with size >= 200 x 200 or largest picture
      # picture must be min 200 x 200 for open graph links on facebook
      # https://developers.facebook.com/tools/debug)
      begin
        res2 = api_client.get_object object_id
        # logger.debug2 "res2 = #{res2}"
        images = res2["images"]
        if images.class == Array and images.size > 0
          logger.debug2 "second lookup: images = #{images}"
          image = nil
          images.each do |hash|
            image = hash["source"] if hash["height"].to_i >= 200 and hash["width"].to_i >= 200
          end
          image = images.first["source"] unless image
          logger.debug2 "image = #{image}"
          api_gift.api_picture_url = image
          api_gift.save!
        else
          logger.warn2 "second lookup: no images array was returned from facebook API request. Keeping old picture"
          logger.warn2 "res2 = #{res2}"
        end
      rescue Koala::Facebook::ClientError => e
        # unhandled koala / facebook exception
        e.logger = logger
        e.puts_exception("#{__method__}: ")
        raise
      end
    end

    # ok
    nil

  end # get_api_picture_url_facebook


  # recheck post on twitter
  # mark as deleted if post has been deleted
  # get new api_picture_url if picture url has changed
  # called from missing_api_picture_urls if image has been moved or deleted
  private
  def get_api_picture_url_twitter (api_gift, just_posted=true, api_client=nil) # api is Koala API client

    provider = "twitter"
    login_user, token, key, options = get_login_user_and_token(provider)
    return [key, options] if key

    # initialize twitter api client
    api_client = init_api_client_twitter(token) if !api_client

    # check twitter post
    begin
      x = api_client.status api_gift.api_gift_id
      logger.debug2 "x = #{x}"
      logger.debug2 "x.class = #{x.class}"
      api_gift.api_picture_url = x.media.first.media_url.to_s if api_gift.picture?
    rescue Twitter::Error::NotFound => e
      logger.debug2 "Exception: e = #{e.message} (#{e.class})"
      api_gift.deleted_at_api = 'Y'
    end
    api_gift.save!

    # ok
    nil

  end # get_api_picture_url_twitter


  # change user.post_on_wall_yn. ajax request from auth/index page
  public
  def post_on_wall_yn
    @errors = []
    logger.debug2 "params = #{params}"
    # check provider
    provider = params[:provider]
    if !valid_provider?(provider)
      @errors << ['.unknown_provider', {:apiname => provider }]
      return
    end
    # check post_on_wall_yn
    post_on_wall = case params[:post_on_wall]
                        when 'true' then 'Y'
                        when 'false' then 'N'
                        else
                          logger.error2 "Invalid post_on_wall value received from client. params = #{params}"
                          return ['.unknown_post_on_wall', {:apiname => provider }]
                      end # case

    # get user
    login_user, token, key, options = get_login_user_and_token(provider)
    if key
      @errors << [key, options]
      return
    end

    # update user
    login_user.update_attribute('post_on_wall_yn', post_on_wall)

  end # post_on_wall_yn


  # grant_write_twitter is called from gifts/index page
  # ( remote link was ajax injected in post_on_twitter if missing write priv. )
  public
  def grant_write_twitter
    @errors = []
    @link = nil
    provider = 'twitter'
    # get user
    login_user, token, key, options = get_login_user_and_token(provider)
    if key
      @errors << [key, options]
      return
    end
    # change twitter user permissions from read to write
    login_user.update_attribute('permissions', 'write')
    # hide ajax injected link to grant write permission to twitter wall
    @link = "grant_write_div_#{provider}"
    # ok
    @errors << ['.grant_write_ok', {:appname => APP_NAME, :apiname => provider_downcase(provider)} ]
  end # grant_write_twitter


  # return [key, options] with @errors ajax to grant write access to facebook wall
  # link is injected in tasks_errors table in page header
  private
  def grant_write_link_facebook
    provider = 'facebook'
    oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
    url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => set_state('status_update'))
    ['.gift_posted_3_html', {:apiname => provider_downcase(provider),
                             :url => url,
                             :appname => APP_NAME}]
  end # grant_write_link_facebook

  # return [key, options] with @errors ajax to grant write access to linkedin wall
  # link is injected in tasks_errors table in page header
  private
  def grant_write_link_linkedin
    provider = 'linkedin'
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
  end # grant_write_link_linkedin

  # return [key, options] with @errors ajax to grant write access to twitter wall
  # link is injected in tasks_errors table in page header
  # read/write authorization in twitter is a gofreerev concept - omniauth login is with write permission to twitter wall
  def grant_write_link_twitter
    provider = 'twitter'
    url = '/util/grant_write_twitter'
    confirm = t 'shared.translate_ajax_errors.confirm_grant_write', :apiname => provider_downcase(provider)
    # ajax inject link in gifts/index page
    return ['.gift_posted_3b_html',
            { :appname => APP_NAME, :apiname => provider_downcase(provider), :provider => provider,
              :url => url, :confirm => confirm}]
  end

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

      # check user privs before post in facebook wall
      # ( permissions is also checked before scheduling post_on_facebook task )
      case login_user.get_write_on_wall_action
        when User::WRITE_ON_WALL_NO then return nil # ignore
        when User::WRITE_ON_WALL_YES then nil # continue
        when User::WRITE_ON_WALL_MISSING_PRIVS then return grant_write_link_facebook # inject link to grant missing priv.
      end

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

      api = nil # Koala API client

      if login_user.post_gift_allowed?
        # post with or without picture - link is a deep link from facebook wall to gift in gofreerev
        # link will be clickable if public url
        # link will be not clickable if localhost or server behind firewall

        begin
          # post - initialize koala client
          api = Koala::Facebook::API.new(token)
          # todo: add method gift.temp_picture_exists?
          if api_gift.picture? and !gift.rel_path_picture_exists?
            # post with picture but picture was not found.
            # There must be some error handling in gifts/create that is missing
            gift_posted_on_wall_api_wall = 6
          elsif api_gift.picture?
            # status post with picture
            picture_url = Picture.url :rel_path => gift.app_picture_rel_path
            picture_full_os_path = Picture.full_os_path :rel_path => gift.app_picture_rel_path
            filetype = gift.app_picture_rel_path.split('.').last
            content_type = "image/#{filetype}"
            api_response = api.put_picture(picture_full_os_path,
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
          logger.debug2 "api_response = #{api_response} (#{api_response.class.name})"
          gift_posted_on_wall_api_wall = 2 # Gift posted in here and on your facebook wall
        rescue Koala::Facebook::ClientError => e
          e.logger = logger
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
              return grant_write_link_facebook
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
          e.logger = logger
          e.puts_exception("#{__method__}: ")
          gift_posted_on_wall_api_wall = 1 # unknown error. no translation
          error = e.fb_error_message.to_s
          api_gift.clear_deep_link
        end # rescue
      else
        # post_gift_allowed? false - ajax inject link to grant missing permission
        gift_posted_on_wall_api_wall = 3
        return grant_write_link_facebook
      end # if

      if gift_posted_on_wall_api_wall != 2
        # error or warning
        api_gift.picture = 'N'
        api_gift.save!
        return [".gift_posted_#{gift_posted_on_wall_api_wall}_html",
                {:apiname => login_user.api_name_without_brackets, :error => error}]
      elsif !api_gift.picture? or api_gift.picture? and Picture.perm_app_url?(picture_url)
        # post ok - no picture or picture with perm app url
        # no need to read access to api wall
        # return posted message
        return [".gift_posted_#{gift_posted_on_wall_api_wall}_html", :apiname => login_user.api_name_without_brackets, :error => error]
      else
        # post ok - gift posted in facebook wall
        # check read access to gift and get picture url with best size > 200 x 200
        # must have read access to post on facebook wall to display picture in gofreerev
        # 1) use api_gift.api_gift_id to get object_id (picture size in first request is too small)
        key, options = get_api_picture_url_facebook(api_gift, true, api)
        return [key, options] if key

        # post ok and no permission problems
        # no errors - return posted message
        return [".gift_posted_#{gift_posted_on_wall_api_wall}_html", :apiname => login_user.api_name_without_brackets, :error => error]
      end

    rescue Exception => e
      logger.debug2 "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2 "Backtrace: " + e.backtrace.join("\n")
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

      # check user privs before post in linkedin wall
      # ( permissions is also checked before scheduling post_on_linkedin task )
      case login_user.get_write_on_wall_action
        when User::WRITE_ON_WALL_NO then return nil # ignore
        when User::WRITE_ON_WALL_YES then nil # continue
        when User::WRITE_ON_WALL_MISSING_PRIVS then return grant_write_link_linkedin # inject link to grant missing priv.
      end

      # get gift, api_gift and deep_link
      gift, api_gift, deep_link, key, options = get_gift_and_deep_link(id, login_user, provider)
      return [key, options] if key

      # create client for linkedin api requests
      client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
      client.authorize_from_access token[0], token[1] # token and secret
      # logger.debug2  "token = #{token[0]}"
      # logger.debug2  "secret = #{token[1]}"

      # todo: add offers/seeks to description
      # todo: add picture
      # todo: add url for gift
      begin

        image_url = Picture.url :rel_path => gift.app_picture_rel_path if api_gift.picture? and gift.rel_path_picture_exists?
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
        # my test says: title 60, description 245 and comment 600 characters
        text = "#{format_direction_without_user(api_gift)} #{gift.description}"
        logger.debug2 "picture = #{api_gift.picture?}, text.length = #{text.length}, image_url = #{image_url}"
        comment = nil
        content = { "submitted-url" => deep_link }
        if api_gift.picture?
          # title (max 200 characters) required for post with image.
          content["submitted-image-url"] = image_url
          # layout rules for post with image on linkedin:
          case
            when text.length <= 200
              content["title"] = text
              content["description"] = '.'
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
        logger.debug2 "content = #{content}, comment = #{comment}"
        x = client.add_share :content => content, :comment => comment
      rescue LinkedIn::Errors::AccessDeniedError => e
        logger.debug2  "LinkedIn::Errors::AccessDeniedError"
        logger.debug2  "e.message = #{e.message}"
        api_gift.clear_deep_link
        if e.message.to_s =~ /^\(403\)/
          # e.message = (403): Access to posting shares denied
          # inject link in tasks_errors table in gifts/index page to allow user to grant missing write permission
          return grant_write_link_linkedin
        end
        raise
      end

      # check response from client.add_share request
      if x.class != Net::HTTPCreated
        api_gift.clear_deep_link
        logger.debug2 "no exception from client.add_share, but post was not created"
        logger.debug2 "x = #{x} (#{x.class})"
        logger.debug2 "x.body = #{x.body} (#{x.body.class})"
        return ['.gift_posted_1_html', {:apiname => provider, :error => x.body}]
      end

      # post on linkedin ok
      logger.debug2 "x = #{x} (#{x.class})"
      # logger.debug2 "x.methods = #{x.methods.sort.join(', ')}"
      logger.debug2 "x.body = #{x.body} (#{x.body.class})"
      #post_on_linkedin: x.body = {
      #    "updateKey": "UNIU-310307710-5824797827771314176-SHARE",
      #    "updateUrl": "http://www.linkedin.com/updates?discuss=&scope=310307710&stype=M&topic=5824797827771314176&type=U&a=omJz"
      #}

      # extract update key and url
      # todo: update_url redirects to linkedin login page
      update_key = $1 if x.body.to_s =~ /"updateKey": "(.*?)"/
      update_url = $1 if x.body.to_s =~ /"updateUrl": "(.*?)"/
      logger.debug2 "update key = #{update_key}, update_url = #{update_url}"
      api_gift.api_gift_id = update_key
      api_gift.api_gift_url = update_url # note that post on linkedin wall is created in a batch process. Will work in one or 2 minutes
      api_gift.save!

      # https://developer.linkedin.com/documents/share-api
      # You can use the update key to request the XML or JSON representation of the newly created share.
      # This can be achieved by making a GET call to http://www.linkedin-ei.com/v1/people/~/network/updates/key={update_key}
      # (setting {update_key} to the value you received in the previous response)
      # can not lookup post in linkedin wall at this time - post is created batch - will be created in one or two minutes
      # x2 = client.shares :key => update_key
      # logger.debug2 "x2 = #{x2} (#{x2.class})"
      # logger.debug2 "x2.methods = #{x2.methods.sort.join(', ')}"

      # no errors - return posted message
      return [".gift_posted_2_html", :apiname => provider, :error => nil]

    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # post_on_linkedin


  private
  def post_on_twitter (id)
    begin
      # get login user and api access token
      provider = "twitter"
      login_user, token, key, options = get_login_user_and_token(provider)
      return [key, options] if key

      # check user privs before post in twitter wall
      # ( permissions is also checked before scheduling post_on_twitter task )
      case login_user.get_write_on_wall_action
        when User::WRITE_ON_WALL_NO then return nil # ignore
        when User::WRITE_ON_WALL_YES then nil # continue
        when User::WRITE_ON_WALL_MISSING_PRIVS then return grant_write_link_twitter # inject link to grant missing priv.
      end

      # get gift, api_gift and deep_link
      gift, api_gift, deep_link, key, options = get_gift_and_deep_link(id, login_user, provider)
      return [key, options] if key

      # create client for twitter api requests
      client = init_api_client_twitter(token)

      tweet = gift.description.first(140)
      if api_gift.picture?
        # http://rubydoc.info/github/jnunemaker/twitter/Twitter/Client:update_with_media
        full_os_path = Picture.full_os_path :rel_path => gift.app_picture_rel_path
        x = client.update_with_media(tweet, File.new(full_os_path))
      else
        x = client.update(tweet)
      end
      return ['.gift_posted_1_html', {:apiname => provider, :error => "Expected Twitter::Tweet. Found #{x.class}"}] if x.class != Twitter::Tweet
      api_gift.api_picture_url = x.media.first.media_url.to_s if api_gift.picture?
      api_gift.api_gift_id  = x.id.to_s
      api_gift.api_gift_url = x.url.to_s
      api_gift.save!

      # no errors - return posted message
      return [".gift_posted_2_html", :apiname => provider, :error => nil]

    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end


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
      logger.debug2  "@gift_file = #{@gift_file}"
      nil
    rescue Exception => e
      logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # disable_file_upload

  # delete local picture file that was used when posting picture in api wall(s) - see post_on_facebook etc.
  def delete_local_picture (id)
    begin
      logger.debug2  ""

      # get and check gift
      gift = Gift.find_by_id(id)
      return ['.post_on_api_unknown_gift_id', { :provider => 'API', :id => id }] unless gift
      return ['.post_on_api_old_gift', { :provider => 'API', :id => gift.id }] unless gift.created_at > 5.minute.ago

      # check local picture file
      return ['.no_local_picture', { :provider => 'API', :id => id }] unless gift.app_picture_rel_path
      app_picture_full_os_path = Picture.full_os_path :rel_path => gift.app_picture_rel_path
      app_picture_url          = Picture.url :rel_path => gift.app_picture_rel_path
      return ['.local_picture_not_found', { :provider => 'API', :id => id }] unless File.exist?(app_picture_full_os_path)

      # delete file
      perm_app_picture = Picture.perm_app_url?(app_picture_url)
      if !perm_app_picture
        File.delete(app_picture_full_os_path) if File.exists?(app_picture_full_os_path)
        gift.app_picture_rel_path = nil
        gift.save!
      end

      # check temp picture after posting on api walls
      # should be set in post_in_<provider> tasks, but not after exceptions
      gift.api_gifts.each do |api_gift|
        if Picture.temp_app_url?(api_gift.api_picture_url)
          # temp url - delete or replace with perm url
          # replace with perm url is only a workaround/fallback for this gift
          if perm_app_picture
            api_gift.api_picture_url = app_picture_url
            logger.warn "fallback after post_on_#{api_gift.provider} failure. Added perm app url for gift id #{gift.id}"
          else
            api_gift.api_picture_url = nil
            api_gift.picture = 'N'
            logger.debug2 "fallback after post_on_#{api_gift.provider} failure. Blanked picture url for gift id #{gift.id}"
          end
          api_gift.save!
        end
      end

      nil

    rescue Exception => e
      logger.debug2  "#{__method__}: Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2  "#{__method__}: Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # delete_local_picture

  private
  def init_api_client_twitter (token)
    provider = 'twitter'
    # logger.debug2  "token = #{token.join(', ')}"
    api_client = Twitter::REST::Client.new do |config|
      config.consumer_key        = API_ID[provider]
      config.consumer_secret     = API_SECRET[provider]
      config.access_token        = token[0]
      config.access_token_secret = token[1]
    end
    api_client
  end # init_api_client_twitter
  
  
end # UtilController

class UtilController < ApplicationController

  # update new message count in menu line in page header once every minute
  # called from hidden check-new-messages-link link in page header once every todo: describe frequence
  #   Parameters: {"request_fullpath"=>"/gifts"}
def new_messages_count
    # return new messages count
    if @user
      count = @user.inbox_new_notifications
      @new_messages_count = count if count > 0
    end
    # return new comments
    if @new_messages_count and ( params[:request_fullpath] == '/gifts' or params[:request_fullpath] =~ /^\/gifts\/([0-9]+)$/ )
      # find comments to ajax insert in gifts/index or gifts/show pages
      # puts "find comments to ajax insert in gifts/index or gifts/show pages"
      # puts "new_messages_count = #{@new_messages_count}"
      com_ids = AjaxComment.where("user_id = ?", @user.user_id).collect { |ac| ac.comment_id }
      # puts "com_ids.length = #{com_ids.length}"
      @comments = Comment.where("comment_id in (?)", com_ids) if com_ids.length > 0
      if @comments and params[:request_fullpath] =~ /^\/gifts\/([0-9]+)$/
        # gifts/show/<nnn> page - return only ajax comments for actual gift (id=<nnn>)
        # puts "new comments before gift_id filter = #{@comments.length}"
        @comments = @comments.find_all { |c| c.gift.id.to_s == $1 }
        # puts "new comments after gift_id filter = #{@comments.length}"
        @comments = nil if @comments.length == 0
      end
        # empty AjaxComment buffer - only return ajax comments once
      AjaxComment.destroy_all(:user_id => @user.user_id)
    end
    # return newly created gifts. Input newest_gift_id when user page was loaded or newest gift_id in last new_messages_count
    # 0 if not called from gifts/index page
    old_newest_gift_id = params[:newest_gift_id].to_i
    new_newest_gift_id = Gift.last.id if old_newest_gift_id > 0
    if old_newest_gift_id > 0 and new_newest_gift_id > old_newest_gift_id
      # called from gifts/index page and new gifts created since page load or last new_messages_count request
      # return new newest_gift_id value and any new gifts visible to user
      @new_newest_gift_id = new_newest_gift_id
      @gifts = @user.gifts(old_newest_gift_id)
      @gifts = nil if @gifts.length == 0
    end
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
        user_id_created_by = User.facebook_user_prefix + gift.api_gift_id.split('_').first
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

end

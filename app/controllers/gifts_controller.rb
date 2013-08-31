# encoding: utf-8
class GiftsController < ApplicationController



  def new
  end

  # todo: ajax create new gift? How to handle picture upload, missing api privs. show/hide link i gifts/index page?
  def create
    flash.now[:notice] = nil
    @gift = Gift.new
    # todo: should validate :price with an regular expressions. "x".to_f == 0.0
    @gift.price = params[:gift][:price].to_f if params[:gift][:price].to_s != ''
    @gift.direction = 'giver' if @gift.direction.to_s == ''
    @gift.currency = @user.currency
    @gift.description = params[:gift][:description]
    if params[:gift][:direction].to_s != 'receiver'
      @gift.user_id_giver = session[:user_id]
    else
      @gift.user_id_receiver = session[:user_id]
    end
    @gift.gifttype = 'G'
    gift_file = params[:gift_file]
    @gift.picture = gift_file.class.name == 'ActionDispatch::Http::UploadedFile' ? 'Y' : 'N'
    unless @gift.valid?
      # todo: check how to handle error messages in rails 4
      flash.now[:notice] = @gift.errors.full_messages.join(', ')
      index
      return
    end

    # check for file upload

    if gift_file.class.name == 'ActionDispatch::Http::UploadedFile' and @user.post_gift_allowed?
      # puts "gift_file = #{gift_file} (#{gift_file.class.name})"
      # puts "gift_file.methods = " + gift_file.methods.sort.join(', ')
      if !@user.post_gift_allowed?
        flash.now[:notice] = my_t '.file_upload_not_allowed', :appname => APP_NAME, :apiname => @user.api_name_without_brackets
        index
        return
      end
      original_filename = gift_file.original_filename
      # puts "gift_file.original_filename = #{gift_file.original_filename}"
      # puts "size = #{gift_file.size}"
      filetype = gift_file.original_filename.split('.').last
      if !%w(jpg gif png bmp).index(filetype)
        flash.now[:notice] = my_t '.unsupported_filetype', :filetype => filetype
        index
        return
      end
      if gift_file.size > 2.megabytes
        flash.now[:notice] = my_t '.file_is_too_big', :maxsize => '2 Mb'
        index
        return
      end
    end # if

    # puts "create: description = #{@gift.description}"

    gift_posted_on_wall_api_wall = nil
    if @user.post_gift_allowed?
      # post gift on login api wall (facebook, google+ etc)

      gift_posted_on_wall_api_wall = false
      case
        when @user.facebook?
          puts "access_token = #{session[:access_token]}"
          api = Koala::Facebook::API.new(session[:access_token])
          begin
            if gift_file
              # post with picture
              api_response = api.put_picture(gift_file, {:message => params[:gift][:description]})
              # api_response = {"id"=>"1396226023933952", "post_id"=>"100006397022113_1396195803936974"} (Hash)
              @gift.api_gift_id = api_response['post_id']
              picture_id = api_response['id']
            else
              # post without picture
              api_response = api.put_connections('me', 'feed', :message => params[:gift][:description])
              # api_response = {"id"=>"100006397022113_1396235850599636"}
              @gift.api_gift_id = api_response['id']
            end
            puts "api_response = #{api_response} (#{api_response.class.name})"
            gift_posted_on_wall_api_wall = true
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
              flash.now[:notice] = 'Not posted. Duplicate status message on wall'
            else
              flash.now[:notice] = e.to_s
            end
          end # rescue
        when @user.google_plus?
          # todo: post message on gogole+ wall
          gift_posted_on_wall_api_wall = false
        else
          # not implemented login api
          gift_posted_on_wall_api_wall = nil
      end # case
    end # if

    puts "flash.now[:notice] = #{flash.now[:notice]}"
    unless flash.now[:notice]
      @gift.save!
      # todo: use api.get_object('me/statuses?__paging_token=3287865251224&limit=1') to read status
      # todo: fol query 100006397022113_1396195803936974?fields=full_picture returns picture url
      # todo: fol query me/picture/1396195803936974 returns picture url
      #                 <userid>/picture/<picture_id>
      if gift_posted_on_wall_api_wall
        flash[:notice] = my_t '.posted_api_and_app_ok', :apiname => @user.api_name_without_brackets
      else
        flash[:notice] = my_t '.posted_app_ok', :apiname => @user.api_name_without_brackets
      end

      if @gift.picture == 'Y'
        # todo: gets only small picture url from fb - is should be possible to get url for a larger picture from fb
        # get temporary picture url - may change - url change is catched in onerror in img in html page
        api_request = "#{@gift.api_gift_id}?fields=full_picture"
        # api_request = @gift.api_gift_id.split('_').join('/picture/') + '?type=normal' # still small picture
        # api_request = @gift.api_gift_id.split('_').join('/picture/')  + '?fields=full_picture' # empty response (302 redirect) with profile picture
        # todo: add exception handler
        puts "access_token = #{session[:access_token]}"
        puts "api_request = #{api_request}"

        begin
          @gift.api_picture_url = @gift.get_api_picture_url(session[:access_token])
        rescue ApiPostNotFoundException => e
          # problem with picture uploads and permissions
          # could not get full_picture url for an uploaded picture with visibility friends
          # the problem appeared after changing app visibility from public to friends
          # that is - app is not allowed to get info about the uploaded picture!!
          # there must be more to it - changed visibility to only me and did get picture url
          # changed visibility to friends and did get the picture url
          # just display a warning and continue. Request read_stream permission from user if read_stream priv. is missing
          if @user.read_gifts_allowed?
            # check if user has removed read stream priv.
            @user.get_api_permissions(session[:access_token])
          end
          if @user.read_gifts_allowed?
            # error - this should not happen.
            flash[:notice] = my_t '.picture_upload_unknown_problem', :appname => APP_NAME, :apiname => @user.api_name_without_brackets
          else
            # flash with request for read stream privs
            flash[:notice] = my_t '.picture_upload_missing_permission', :appname => APP_NAME, :apiname => @user.api_name_without_brackets
            flash[:read_stream] = 'Missing read_stream permission' # display link to grant read_stream permission
          end
          @gift.picture = 'N'
          @gift.save!
          redirect_to :action => 'index'
          return
        end # rescue
        if @gift.api_picture_url
          # save picture url from api
          @gift.api_picture_url_updated_at = Time.now
          @gift.api_picture_url_on_error_at = nil
          @gift.save!
        else
          puts "Did not get a picture url from api. Must be problem with missing access token, picture != Y or deleted_at_api == Y"
        end
      end

      redirect_to :action => 'index'
      return
    end

    index
  end # create

  def update
  end

  def edit
  end

  def destroy
  end

  def index
    # test if flash object can be used
    puts "flash[:read_stream] = #{flash[:read_stream]}"


    # get any pictures with invalid picture urls
    # that is gifts where picture url are marked as invalid and where url lookup in /util/missing_api_picture_urls failed
    # most possible explanation is that the pictures has been deleted in api
    # but is could also be a fb permission problem (gofreerev user was not allowed to see picture in api)
    # check picture url again with owner permission
    # the existing /util/missing_api_picture_urls is used to check ivalid picture urls
    # done in a client js call after the page has been rendered to the user
    # see last lines in /gifts/index page
    # see onload tag on img
    # see js functions check_api_picture_url and report_missing_api_picture_urls
    gifts = []
    if @user
      gifts = Gift.where("(user_id_giver = ? or user_id_receiver = ?) and api_picture_url_on_error_at is not null and (deleted_at_api is null or deleted_at_api = 'N')",
                          @user.user_id, @user.user_id)
      gifts.delete_if do |gift|
        user_id_created_by = User.facebook_user_prefix + gift.api_gift_id.split('_')[0]
        (user_id_created_by != @user.user_id)
      end # delete_if
    end # if
    if gifts.size == 0
      @missing_api_picture_urls = nil
    else
      @missing_api_picture_urls = 'missing_api_picture_urls = [' + gifts.collect { |g| g.id }.join(', ') + '] ;'
    end


    puts "user_name = #{@user.user_name}" if @user
    puts "access_token = #{session[:access_token]}"
    @gift = Gift.new
    if params[:gift]
      # returned from create - error in save or error in api request - gift not saved
      @gift.price = params[:gift][:price].to_f if params[:gift][:price].to_s != ''
      @gift.direction = params[:gift][:direction]
      @gift.description = params[:gift][:description]
    end
    @gift.direction = 'giver' if @gift.direction.to_s == ''
    unless @user
      @gifts = []
      render_with_language __method__
      return
    end
    if @user
      @gift.currency = @user.currency unless @gift.currency
      @gift.user_id_giver = session[:user_id]
    end
    # puts "index: description = #{@gift.description}"

    # initialize list of gifts
    # list of gifts with @user as giver or receiver + list of gifts med @user.friends as giver or receiver
    if @user then
      newest_gift = Gift.last
      @gifts = @user.gifts
    end

    # last_gift_id != nil. ajax request from end of gifts/index page - return next 10 rows to gifts/index page
    # puts "last_gift_id = #{params[:last_gift_id]}, gifts.length = #{@gifts.length}"
    if params[:last_gift_id].to_s == ""
      # not ajax - show first 10 gifts
      # remember newest gift id (global). Gifts created by friends after page load will be ajax inserted in gifts/index page
      @newest_gift_id = newest_gift.id if newest_gift
      # empty AjaxComment buffer for current user - comments created after page load will be ajax inserted in gifts/index page
      AjaxComment.destroy_all(:user_id => @user.user_id)
    else
      # ajax - show next 10 gifts after last_gift_id
      @last_gift_id = nil
      from = @gifts.find_index { |g| g.id == params[:last_gift_id].to_i }
      # puts "from = #{from}"
      @gifts = @gifts[from+1..-1]
    end

    # puts "gifts.length = #{@gifts.length}"
    if  @gifts.length > 10
      @gifts = @gifts[0..9]
      @last_gift_id = @gifts.last.id
    else
      @last_gift_id = nil
    end
    # puts "last_gift_id = #{@last_gift_id}, gifts.length = #{@gifts.length}"

    # show 4 last comments for each gift
    @first_comment_id = nil

    respond_to do |format|
      format.html { }
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # index

  def show
    # check gift id
    gift = Gift.find_by_id(params[:id])
    if !gift
      flash[:notice] = my_t '.invalid_gift_id'
      redirect_to :action => :index
      return
    end
    # check access. giver and/or receiver must be a app friend
    if [gift.user_id_receiver, gift.user_id_giver].index(@user.user_id)
      access = true
    else
      access = @user.app_friends.find { |f| [gift.user_id_receiver, gift.user_id_giver].index(f.user_id_receiver) }
    end
    if !access
       flash[:notice] = my_t ('.no_access')
       redirect_to :action => :index
       return
    end
    # ok - show gift
    @gift = gift
  end # show

end # GiftsController

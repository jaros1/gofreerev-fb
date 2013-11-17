# encoding: utf-8
class GiftsController < ApplicationController


  def new
  end

  # todo: ajax create new gift? How to handle picture upload, missing api privs. show/hide link i gifts/index page?
  def create
    flash.now[:notice] = nil
    @gift = Gift.new
    @gift.price = params[:gift][:price].gsub(',','.').to_f unless invalid_price?(params[:gift][:price])
    @gift.direction = 'giver' if @gift.direction.to_s == ''
    @gift.currency = @user.currency
    @gift.description = params[:gift][:description]
    if params[:gift][:direction].to_s != 'receiver'
      @gift.user_id_giver = session[:user_id]
    else
      @gift.user_id_receiver = session[:user_id]
    end
    gift_file = params[:gift_file]
    @gift.picture = gift_file.class.name == 'ActionDispatch::Http::UploadedFile' ? 'Y' : 'N'
    # price= accepts only float and model can not return invalid price errors
    @gift.valid?
    @gift.errors.add :price, :invalid if invalid_price?(params[:gift][:price])
    if @gift.errors.size > 0
      flash.now[:notice] = @gift.errors.full_messages.join(', ')
      index
      return
    end

    # check for file upload
    if gift_file.class.name == 'ActionDispatch::Http::UploadedFile' and @user.post_gift_allowed?
      # puts "gift_file = #{gift_file} (#{gift_file.class.name})"
      # puts "gift_file.methods = " + gift_file.methods.sort.join(', ')
      if !@user.post_gift_allowed?
        flash.now[:notice] = t '.file_upload_not_allowed', :appname => APP_NAME, :apiname => @user.api_name_without_brackets
        index
        return
      end
      original_filename = gift_file.original_filename
      # puts "gift_file.original_filename = #{gift_file.original_filename}"
      # puts "size = #{gift_file.size}"
      # todo: should not get image type from file extension. Should check image type from file content
      filetype = gift_file.original_filename.split('.').last
      if !%w(jpg gif png bmp).index(filetype)
        flash.now[:notice] = t '.unsupported_filetype', :filetype => filetype
        index
        return
      end
      if gift_file.size > 2.megabytes
        flash.now[:notice] = t '.file_is_too_big', :maxsize => '2 Mb'
        index
        return
      end
    end # if

    # puts "create: description = #{@gift.description}"

    # gift_posted_on_wall_api_wall. values:
    #  1: "Gift posted in here but not on your %{apiname} wall. #{error}" # unhandled error message
    #  2: "Gift posted in here and on your %{apiname} wall"
    #  3: "Gift posted in here but not on your %{apiname} wall." # missing privileges
    #  4: "Gift posted in here but not on your %{apiname} wall. Duplicate status message on #{apiname} wall."
    #  5: "Gift posted in here but not on your %{apiname} wall. Post on #{apiname} wall not implemented."
    gift_posted_on_wall_api_wall = 1
    error = 'unknown error'

    if @user.post_gift_allowed?
      # post gift on login api wall (facebook, google+ etc)
      case
        when @user.facebook?
          # puts "access_token = #{session[:access_token]}"
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
              @user.get_api_permissions(session[:access_token])
              if !@user.post_gift_allowed?
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
          end # rescue
        when @user.google_plus?
          # todo: post message on google+ wall
          gift_posted_on_wall_api_wall = 5 # Post on %{apiname} wall not implemented.
        when @user.linkedin?
          # todo: post message on linkedIn wall
          gift_posted_on_wall_api_wall = 5 # Post on %{apiname} wall not implemented.
        else
          # not implemented login api
          gift_posted_on_wall_api_wall = 5 # Post on %{apiname} wall not implemented.
          error = 'Unknown api'
      end # case
    else
      gift_posted_on_wall_api_wall = 3
    end # if

    if !@gift.save
      # @gift.save should not fail. @gift was validated a moment ago before posting on api wall
      messages = [ t(".gift_not_posted_#{gift_posted_on_wall_api_wall}", :apiname => @user.api_name_without_brackets, :error => error) ]
      messages = messages + @gift.errors.full_messages
      flash.now[:notice] = messages.join('. ')
      index
      return
    else
      # save picture posted message
      messages = [ t(".gift_posted_#{gift_posted_on_wall_api_wall}", :apiname => @user.api_name_without_brackets, :error => error) ]
      # get url for picture
      if @gift.picture == 'Y'
        # todo: gets only small picture url from fb - is should be possible to get url for a larger picture from fb
        # get temporary picture url - may change - url change is catched in onerror in img in html page
        api_request = "#{@gift.api_gift_id}?fields=full_picture"
        # api_request = @gift.api_gift_id.split('_').join('/picture/') + '?type=normal' # still small picture
        # api_request = @gift.api_gift_id.split('_').join('/picture/')  + '?fields=full_picture' # empty response (302 redirect) with profile picture
        puts "api_request = #{api_request}"
        begin
          @gift.api_picture_url = @gift.get_api_picture_url(session[:access_token])
          if @gift.api_picture_url
            # valid picture url received from apii
            @gift.api_picture_url_updated_at = Time.now
            @gift.api_picture_url_on_error_at = nil
            @gift.save!
          else
            puts "Did not get a picture url from api. Must be problem with missing access token, picture != Y or deleted_at_api == Y"
            messages << t('.no_api_picture_url', :apiname => @user.api_name_without_brackets)
          end
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
            messages << t('.picture_upload_unknown_problem', :appname => APP_NAME, :apiname => @user.api_name_without_brackets)
          else
            # flash with request for read stream privs
            messages << t('.picture_upload_missing_permission', :appname => APP_NAME, :apiname => @user.api_name_without_brackets)
            flash[:read_stream] = 'Missing read_stream permission' # display link to grant read_stream permission in gifts/index page
          end
          @gift.picture = 'N'
          @gift.save!
        end # rescue
      end
    end

    flash[:notice] = messages.join('. ')
    redirect_to :action => 'index'

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
    # but is could also be a api permission problem (gofreerev user is not allowed to see picture in api)
    # check picture url again with owner permission
    # the existing /util/missing_api_picture_urls is used to check invalid picture urls
    # done in a client js call after the page has been rendered to the user
    # see last lines in /gifts/index page
    # see onLoad tag on img
    # see js functions check_api_picture_url and report_missing_api_picture_urls
    @missing_api_picture_urls = get_missing_api_picture_urls()

    # initialize gift form in top of gifts/index page
    puts "user_name = #{@user.user_name}" if @user
    # puts "access_token = #{session[:access_token]}"
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
    # list of gifts with @user as giver or receiver + gifts med @user.friends as giver or receiver
    if @user then
      newest_status_update_at = Sequence.status_update_at
      newest_gift = Gift.last
      # get list with gifts
      gifts = @user.gifts
    end

    # use this gifts select for ajax debug - returns all gifts
    # gifts = Gift.where('user_id_giver is not null or user_id_receiver is not null').order('id desc') # uncomment to test ajax

    # http request: return first 10 gifts (last_row_id = nil)
    # ajax request: return next 10 gifts (last_row_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end

    # last_row_id != nil. ajax request from end of gifts/index page - return next 10 rows to gifts/index page
    # puts "last_row_id = #{params[:last_row_id]}, gifts.length = #{@gifts.length}"
    if !last_row_id
      # http request - return first 10 gifts
      # remember newest gift id (global). Gifts created by friends after page load will be ajax inserted in gifts/index page
      @newest_gift_id = newest_gift.id if newest_gift
      # remember newest status update (gifts and comments). Gifts and comments with status changes after page load will be ajax replaced in gifts/index page
      @newest_status_update_at = newest_status_update_at if newest_gift
      # empty AjaxComment buffer for current user - comments created after page load will be ajax inserted in gifts/index page
      AjaxComment.destroy_all(:user_id => @user.user_id)
    end

    @gifts, @last_row_id = get_next_set_of_rows(gifts, last_row_id)

    # show 4 last comments for each gift
    @first_comment_id = nil

    respond_to do |format|
      format.html { render :action => "index" }
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # index

  def show
    # check gift id
    gift = Gift.find_by_id(params[:id])
    if !gift
      puts "invalid gift id"
      flash[:notice] = t '.invalid_gift_id'
      redirect_to :action => :index
      return
    end
    # check access. giver and/or receiver of gift must be a app friend
    if !gift.visible_for(@user)
      puts "no access"
      flash[:notice] = t ('.no_access')
      redirect_to :action => :index
      return
    end
    # ok - show gift
    @gift = gift

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end
  end # show

end # GiftsController

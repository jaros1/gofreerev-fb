# encoding: utf-8
class GiftsController < ApplicationController


  def new
  end

  # ajax request - called from gifts/index page
  # return gift in new_messages_buffer_div and return any messages in ajax_tasks_errors
  # both divs in page header
  def create
    # start with empty ajax response
    @errors = []
    @gifts = []
    # initialize gift
    @gift = Gift.new
    @gift.price = params[:gift][:price].gsub(',', '.').to_f unless invalid_price?(params[:gift][:price])
    @gift.direction = 'giver' if @gift.direction.to_s == ''
    @gift.currency = @user.currency
    @gift.description = params[:gift][:description]
    if params[:gift][:direction].to_s != 'receiver'
      @gift.user_id_giver = session[:user_id]
    else
      @gift.user_id_receiver = session[:user_id]
    end
    gift_file = params[:gift_file]
    picture = (gift_file.class.name == 'ActionDispatch::Http::UploadedFile')
    if picture and !@user.post_gift_allowed?
      @errors << t('.file_upload_not_allowed', :appname => APP_NAME, :apiname => @user.api_name_without_brackets)
      picture = false
    end
    if picture
      filetype = FastImage.type(gift_file.path).to_s
      if !%w(jpg jpeg gif png bmp).index(filetype)
        @errors << t('.unsupported_filetype', :filetype => filetype)
        picture = false
      end
    end
    if picture and gift_file.size > 2.megabytes
      @errors << t('.file_is_too_big', :maxsize => '2 Mb')
      picture = false
    end
    if picture
      @gift.picture = 'Y'
      @gift.temp_picture_filename = "#{String.generate_random_string(20)}.#{filetype}".last(20)
      @gift.api_picture_url = @gift.temp_picture_url
    else
      @gift.picture = 'N'
    end
    @gift.valid?
    @gift.errors.add :price, :invalid if invalid_price?(params[:gift][:price]) # price= accepts only float and model can not return invalid price error
    return add_error_and_format_ajax_resp(@gift.errors.full_messages.join(', ')) if @gift.errors.size > 0

    # save picture
    @gift.save!
    User.open4("mv #{gift_file.path} #{@gift.temp_picture_path}") if picture

    # post on api wall(s) - priority = 5
    # status:
    # - facebook ok
    # - google+ not implemented - The Google+ API is still a read only API
    # - linkedin
    tokens = session[:tokens] || {}
    tokens.keys.each do |provider|
      task_name = "post_on_#{provider}"
      add_ajax_task "#{task_name}(#{@gift.id})" if UtilController.new.private_methods.index(task_name.to_sym)
    end

    # delete picture after posting on api wall(s) - priority = 4
    add_ajax_task "delete_local_picture(#{@gift.id})", 4 if picture

    @gifts = [ @gift]
    format_ajax_response
    return
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

    # http request: return first 10 gifts (last_row_id = nil)
    # ajax request: return next 10 gifts (last_row_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end
    if last_row_id and get_next_set_of_rows_error?(last_row_id)
      # problem with ajax request.
      # can be invalid last_row_id - can be too many get-more-rows ajax requests - max one request every 3 seconds - more info in log
      # return "empty" ajax response with dummy row with correct last_row_id to client
      puts "return empty ajax response with dummy row with correct last_row_id to client"
      @gifts = []
      @last_row_id = session[:last_row_id]
      respond_to do |format|
        format.js {}
      end
      return
    end

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

    # last_row_id != nil. ajax request from end of gifts/index page - return next 10 rows to gifts/index page
    # puts "last_row_id = #{params[:last_row_id]}, gifts.length = #{@gifts.length}"
    if !last_row_id
      # http request - return one gift - ajax request for the next 10 rows will start in a second - see shared/show_more_rows
      # remember newest gift id (global). Gifts created by friends after page load will be ajax inserted in gifts/index page
      @newest_gift_id = newest_gift.id if newest_gift
      # remember newest status update (gifts and comments). Gifts and comments with status changes after page load will be ajax replaced in gifts/index page
      @newest_status_update_at = newest_status_update_at if newest_gift
      # empty AjaxComment buffer for current user - comments created after page load will be ajax inserted in gifts/index page
      AjaxComment.destroy_all(:user_id => @user.user_id)
      # insert dummy profile pictures in first row - force fixed size for empty from or to columns
      @first_gift = true
    end

    @gifts, @last_row_id = get_next_set_of_rows(gifts, last_row_id)
    # session[:last_row_at] = GET_MORE_ROWS_INTERVAL.seconds.ago.to_f if !last_row_id # first http request at startup - ajax request for the next 10 rows in a split second

    # show 4 last comments for each gift
    @first_comment_id = nil

    respond_to do |format|
      format.html { render :action => "index" }
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end

  # index

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
  end

  # show

  private
  def format_ajax_response
    respond_to do |format|
      format.js {}
    end
    nil
  end

  def add_error_and_format_ajax_resp (error)
    @errors << error
    format_ajax_response
  end

end # GiftsController

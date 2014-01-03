# encoding: utf-8
class GiftsController < ApplicationController

  before_filter :clear_state, :if => lambda {|c| !request.xhr?}
  before_filter :login_required, :except => :show # allow deep link without login

  def new
  end

  # ajax request - called from gifts/index page
  # return gift in new_messages_buffer_div and return any error messages in tasks_errors table
  # both in page header
  # JS function insert_update_gifts will move new gift from div buffer to gifts table in html page
  def create
    # start with empty ajax response
    @errors = []
    @api_gifts = []
    # initialize gift
    gift = Gift.new
    gift.price = params[:gift][:price].gsub(',', '.').to_f unless invalid_price?(params[:gift][:price])
    gift.direction = 'giver' if gift.direction.to_s == ''
    gift.created_by = gift.direction
    gift.currency = @users.first.currency
    gift.description = params[:gift][:description]
    gift_file = params[:gift_file]
    picture = (gift_file.class.name == 'ActionDispatch::Http::UploadedFile')
    if picture and !User.post_gift_allowed?(@users)
      @errors << t('.file_upload_not_allowed',
                   :appname => APP_NAME,
                   :apiname => (@users.length > 1 ? 'login provider' : @users.first.api_name_without_brackets))
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
    gift.temp_picture_filename = "#{String.generate_random_string(20)}.#{filetype}".last(20) if picture
    gift.valid?
    gift.errors.add :price, :invalid if invalid_price?(params[:gift][:price]) # price= accepts only float and model can not return invalid price error
    return add_error_and_format_ajax_resp(gift.errors.full_messages.join(', ')) if gift.errors.size > 0

    # add api_gifts - one api_gifts for each provider
    # api_gift_id and any picture will be added in post_on_<provider> tasks
    @users.each do |user|
      api_gift = ApiGift.new
      api_gift.gift_id = gift.gift_id
      api_gift.provider = user.provider
      api_gift.user_id_giver = gift.direction == 'giver' ? user.user_id : nil
      api_gift.user_id_receiver = gift.direction == 'receiver' ? user.user_id : nil
      api_gift.picture = picture ? 'Y' : 'N'
      api_gift.api_picture_url = gift.temp_picture_url if picture
      gift.api_gifts << api_gift
    end
    gift.save!

    # temporary save picture on server before posting it on api walls in post_on_<provider> tasks
    # picture will be deleted from server when posting on api walls are done
    if picture
      stdout, stderr, status = User.open4("mv #{gift_file.path} #{gift.temp_picture_path}")
      if status != 0
        # mv failed - continue post without picture
        @errors << t(".file_mv_error", :error => stderr)
        gift.temp_picture_filename = nil
        gift.save!
        gift.api_gifts.each do |api_gift|
          api_gift.picture = 'N'
          api_gift.api_picture_url = nil
          api_gift.save!
        end
        picture = false
      end
    end

    # post on api wall(s) - priority = 5
    # status:
    # - facebook ok -
    # - google+ not implemented - The Google+ API is at current time a read only API
    # - linkedin - todo - post without picture ok
    # - twitter - todo
    # note that post_on_<provider> is called even if post_gift_allowed? is false (inject link to grant missing permission)
    tokens = session[:tokens] || {}
    tokens.keys.each do |provider|
      task_name = "post_on_#{provider}"
      add_task "#{task_name}(#{gift.id})", 5 if UtilController.new.private_methods.index(task_name.to_sym)
    end

    # disable file upload button if post on provider wall was rejected for all apis
    # enable file upload button if post on wall was allowed for one provider
    add_task "disable_enable_file_upload", 5

    # delete picture after posting on api wall(s) - priority = 10
    add_task "delete_local_picture(#{gift.id})", 10 if picture

    @api_gifts = ApiGift.where("id = ?", gift.api_gifts.first.id).includes(:gift)
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
      logger.debug2  "return empty ajax response with dummy row with correct last_row_id to client"
      @api_gifts = []
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
    #
    # logger.debug2  "user_name = #{@user.user_name}" if @user
    # logger.debug2  "access_token = #{session[:access_token]}"
    @gift = Gift.new
    @gift.direction = 'giver'
    if User.dummy_users?(@users)
      @api_gifts = []
      render_with_language __method__
      return
    end
    @gift.currency = @users.first.currency unless @gift.currency
    # logger.debug2  "index: description = #{@gift.description}"

    # initialize list of gifts
    # list of gifts with @user as giver or receiver + gifts med @user.friends as giver or receiver
    newest_status_update_at = Sequence.status_update_at
    newest_gift = Gift.last
    # get list with gifts
    gifts = User.api_gifts(@users)

    # use this gifts select for ajax debug - returns all gifts
    # gifts = Gift.where('user_id_giver is not null or user_id_receiver is not null').order('id desc') # uncomment to test ajax

    # last_row_id != nil. ajax request from end of gifts/index page - return next 10 rows to gifts/index page
    # logger.debug2  "last_row_id = #{params[:last_row_id]}, gifts.length = #{@gifts.length}"
    if !last_row_id
      # http request - return one gift - ajax request for the next 10 rows will start in a second - see shared/show_more_rows
      # remember newest gift id (global). Gifts created by friends after page load will be ajax inserted in gifts/index page
      @newest_gift_id = newest_gift.id if newest_gift
      # remember newest status update (gifts and comments). Gifts and comments with status changes after page load will be ajax replaced in gifts/index page
      @newest_status_update_at = newest_status_update_at if newest_gift
      # empty AjaxComment buffer for current user - comments created after page load will be ajax inserted in gifts/index page
      AjaxComment.where("user_id in (?)", login_user_ids).delete_all if login_user_ids.length > 0
      # insert dummy profile pictures in first row - force fixed size for empty from or to columns
      @first_gift = true
    end

    @api_gifts, @last_row_id = get_next_set_of_rows(gifts, last_row_id)
    # session[:last_row_at] = GET_MORE_ROWS_INTERVAL.seconds.ago.to_f if !last_row_id # first http request at startup - ajax request for the next 10 rows in a split second

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
    id = params[:id].to_s
    deep_link = deep_link? # deep link from api wall to gift in gofreerev
    if deep_link
      deep_link_id = id.first(20)
      deep_link_pw = id.last(10)
      api_gift = ApiGift.where("deep_link_id = ?", deep_link_id).includes(:gift).first
      gift = api_gift.gift if api_gift
    else
      gift = Gift.find_by_id(id)
    end
    if !gift
      if deep_link
        logger.debug2  "invalid deep link id"
        if User.dummy_users?(@users)
          flash[:notice] = t '.invalid_deep_link_id_not_logged_in'
        else
          flash[:notice] = t '.invalid_deep_link_id_logged_in'
        end
      else
        logger.debug2  "invalid gift id"
        flash[:notice] = t '.invalid_gift_id'
      end
      if deep_link and User.dummy_users?(@users)
        # not logged in
        redirect_to :controller => :auth
      else
        # logged in
        redirect_to :action => :index
      end
      return
    end
    if deep_link and deep_link_pw != api_gift.deep_link_pw
      api_gift.deep_link_errors += 1
      api_gift.save!
      api_gift.clear_deep_link if api_gift.deep_link_errors > 10
      logger.debug2  "invalid deep link pw"
      if User.dummy_users?(@users)
        flash[:notice] = t '.invalid_deep_link_id_not_logged_in'
      else
        flash[:notice] = t '.invalid_deep_link_id_logged_in'
      end
      if deep_link and User.dummy_users?(@users)
        redirect_to :controller => :auth
      else
        redirect_to :action => :index
      end
      return
    end
    # check access. giver and/or receiver of gift must be a app friend
    if !deep_link and !gift.visible_for?(@users)
      logger.debug2  "no access"
      flash[:notice] = t ('.no_access')
      redirect_to :action => :index
      return
    end

    # ok - show gift
    if deep_link
      @gift = api_gift
      # http://ogp.me/
      # 1) http://wptest.means.us.com/online-meta-tag-length-checker/
      #    og:title max length: facebook 94, google+ 63, twitter 70
      #    og:description max length: facebook 200, google+ 155, twitter 200
      # 2) http://www.joshspeters.com/how-to-optimize-the-ogdescription-tag-for-search-and-social
      #    og:description max lengths: Facebook 300, linkedIn 225, Google+ 200 (LinkedIn have a 256 character limit in content.description field when posting)
      # 3) http://moz.com/blog/title-tags-is-70-characters-the-best-practice-whiteboard-friday
      #    title <= 70 characters
      title, description = open_graph_title_and_desc(api_gift)
      @open_graph = { :title => title,
                      :description => description,
                      :image => (api_gift.picture? ? api_gift.api_picture_url : API_OG_DEFAULT_IMAGE),
                      :url   => api_gift.deep_link()}
    elsif gift.api_gifts.length == 1
      @gift = gift.api_gifts.first
    else
      # same sort criteria as in user.api_gifts sort (gift.id not relevant here)
      api_gifts = gift.api_gifts.sort do |a, b|
        if  a.status_sort != b.status_sort
          a.status_sort <=> b.status_sort # 2) closed gift before open gift
        else
          a.picture_sort(@users) <=> b.picture_sort(@users) # 3, 4 and 5
        end
      end # ags sort 1
      @gift = api_gifts.first
    end

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end
  end # show

  private
  def open_graph_title_and_desc(api_gift)
    text = "#{format_direction_without_user(api_gift)}#{api_gift.gift.description}"
    title_lng = API_OG_TITLE_SIZE[api_gift.provider] || 70
    desc_lng = API_OG_DESC_SIZE[api_gift.provider] || 200
    return [text, nil] if text.length <= title_lng
    to = text.first(title_lng).rindex(' ')
    if (to)
      [text.first(to), text.from(to+1)]
    else
      [text.first(title_lng), text.from(title_lng)]
    end
  end

end # GiftsController

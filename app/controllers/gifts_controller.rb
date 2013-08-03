# encoding: utf-8
class GiftsController < ApplicationController



  def new
  end

  def create
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
      puts "gift_file = #{gift_file} (#{gift_file.class.name})"
      puts "gift_file.methods = " + gift_file.methods.sort.join(', ')
      if !@user.post_gift_allowed?
        flash.now[:notice] = my_t '.file_upload_not_allowed', :appname => APP_NAME, :apiname => @user.api_name_without_brackets
        index
        return
      end
      original_filename = gift_file.original_filename
      puts "gift_file.original_filename = #{gift_file.original_filename}"
      puts "size = #{gift_file.size}"
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

    unless flash.now[:notice]
      @gift.save!
      # todo: use api.get_object('me/statuses?__paging_token=3287865251224&limit=1') to read status
      # todo: fol query 100006397022113_1396195803936974?fields=full_picture returns picture url
      # todo: fol query me/picture/1396195803936974 returns picture url
      #                 <userid>/picture/<picture_id>
      # todo: language support missing
      if gift_posted_on_wall_api_wall
        flash[:notice] = "Gift posted in here and on your #{@user.api_name_without_brackets} wall"
      else
        flash[:notice] = 'Gift not posted on your wall'
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
          api_response = api.get_object(api_request)
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
          puts "api_response = #{api_response}"

          if e.fb_error_type == 'GraphMethodException' and e.fb_error_code == 100
            # problem with picture uploads and permissions
            # could not get full_picture url for an uploaded picture with visibility friends
            # the problem appeared after changing app visibility from public to friends
            # that is - app is not allowed to get info about the uploaded picture!!
            # there must be more to it - changed visibility to only me and did get picture url
            # changed visibility to friends and did get the picture url
            # just display a warning and continue
            # todo: translate
            flash[:notice] = "Gift posted in here and on your #{@user.api_name_without_brackets} wall. " +
                             "Picture was uploaded to your #{@user.api_name_without_brackets} wall but #{APP_NAME} did not have permission to read the picture on your wall and can not display the picture in here. " +
                              "You can solve this problem either by changing visibility of app and posts for #{APP_NAME} to public " +
                              "or by granting #{APP_NAME} permission to read posts in your wall."
            flash[:read_stream] = 'Missing read_stream permission' # display link to grant read_stream permission
            @gift.picture = 'N'
            @gift.save!
            redirect_to :action => 'index'
            return
          end

          raise

        end
        # api_request = 100006397022113_1396195803936974?fields=full_picture,
        # api_response = {"full_picture"=>"https://fbexternal-a.akamaihd.net/safe_image.php?d=AQCxjY2WxJW1STSP&url=https%3A%2F%2Ffbcdn-photos-a-a.akamaihd.net%2Fhphotos-ak-ash4%2F1006016_1396195797270308_1576848979_s.jpg", "id"=>"100006397022113_1396195803936974", "created_time"=>"2013-08-02T10:50:54+0000"}
        @gift.api_picture_url = api_response["full_picture"]
        @gift.api_picture_url_updated_at = Time.now
        @gift.api_picture_url_on_error_at = nil
        @gift.save!
      end
      # api_response = api.get_object("me/statuses?__paging_token=#{@gift.api_gift_id}&limit=1")
      # api_response = api.get_object("me/statuses?__paging_token=#{picture_id}&limit=1")

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
    # that is gifts where picture url is marked as invalid and where url lookup in missing_api_picture_urls failed
    # most possible the pictures has been deleted in api
    # but problem could also be a fb permission problem
    # check picture url again now with owner permission
    # the existing /util/missing_api_picture_urls is used to check ivalid picture urls
    # done in a client js call after the page has been rendered to the user
    # see last lines in /gifts/index page
    # see onload tag on img
    # see js functions check_api_picture_url and report_missing_api_picture_urls
    gifts = Gift.where("(user_id_giver = ? or user_id_receiver = ?) and api_picture_url_on_error_at is not null and (deleted_at_api is null or deleted_at_api = 'N')",
                        @user.user_id, @user.user_id)
    gifts.delete_if do |gift|
      user_id_created_by = User.facebook_user_prefix + gift.api_gift_id.split('_')[0]
      (user_id_created_by != @user.user_id)
    end # delete_if
    if gifts.size == 0
      @missing_api_picture_urls = nil
    else
      @missing_api_picture_urls = 'missing_api_picture_urls = [' + gifts.collect { |g| g.id }.join(', ') + '] ;'
    end
    ids = gifts.collect { |g| g.id }.join(',')


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
    puts "index: description = #{@gift.description}"

    # initialize list of gifts
    # list of gifts with @user as giver or receiver + list of gifts med @user.friends as giver or receiver
    # where clause is used for non encrypted fields. find_all is used for encrypted fields
    friends = Friend.where("user_id_giver = ?", @user.user_id).find_all do |f|
      puts "user_id_receiver = #{f.user_id_receiver}, api_friend = #{f.api_friend}, app_friend = #{f.app_friend}"
      if f.app_friend == 'Y'
        true
      elsif f.app_friend == nil and f.api_friend == 'Y'
        true
      else
        false
      end
    end.collect { |u| u.user_id_receiver }
    friends.push(@user.user_id)
    # todo: problem with sort. received_at is encrypted text in db and can not be used in sort
    #       there should also be a possible for user to select sort conditions
    #       for example last commented post first
    #       sort columns can not be encrypted text
    #       could be datetime columns in db
    #       could be anonymous sequences or float for timestamps
    @gifts = Gift.where('user_id_giver in (?) or user_id_receiver in (?)', friends, friends).includes(:giver, :receiver).order('ifnull(received_at,created_at)').paginate(:page => params[:page]) if @user
    puts "@gifts.size = #{@gifts.size}"
    @gifts.sort! do |b, a|
      if (a.received_at || a.created_at.to_date) ==  (b.received_at || b.created_at.to_date)
        a.id <=> b.id
      else
        (a.received_at || a.created_at.to_date) <=>  (b.received_at || b.created_at.to_date)
      end
    end

    render_with_language __method__
  end # index

  def show
  end

end

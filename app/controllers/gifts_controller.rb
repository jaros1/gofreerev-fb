class GiftsController < ApplicationController



  def new
  end

  def create
    @gift = Gift.new
    @gift.price = BigDecimal.new params[:gift][:price]
    @gift.currency = @user.currency
    @gift.description = params[:gift][:description]
    @gift.user_id_giver = session[:user_id]
    @gift.gifttype = 'G'
    if !@gift.valid?
      # todo: check how to handle error messages in rails 4
      flash.now[:notice] = @gift.errors.full_messages.join(', ')
      index
      return
    end
    # puts "create: description = #{@gift.description}"

    if @user.post_gift_allowed?
      # post gift on login api wall (facebook, google+ etc)
      gift_posted_on_wall_api_wall = false
      case
        when @user.facebook?
          puts "access_token = #{session[:access_token]}"
          api = Koala::Facebook::API.new(session[:access_token])
          begin
            api_response = api.put_connections("me", "feed", :message => params[:gift][:description])
            puts "api_response = #{api_response} (#{api_response.class.name})"
            @gift.api_gift_id = api_response["id"].split("_")[1] # id to post in facebook wall
            gift_posted_on_wall_api_wall = true
          rescue Koala::Facebook::ClientError => e
            puts "Koala::Facebook::ClientError"
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

    if !flash.now[:notice]
      @gift.save!
      # todo: use api.get_object('me/statuses?__paging_token=3287865251224&limit=1') to read status
      # todo: language support missing
      if gift_posted_on_wall_api_wall
        flash[:notice] = 'Gift posted in  and on your wall'
      else
        flash[:notice] = 'Gift not posted on your wall'
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
    puts "user_name = #{@user.user_name}" if @user
    puts "access_token = #{session[:access_token]}"
    @gift = Gift.new
    if params[:gift]
      # returned from create - error in save or error in api request - gift not saved
      @gift.price = BigDecimal.new params[:gift][:price]
      @gift.description = params[:gift][:description]
      @gift.file = params[:gift][:file]
    end
    if !@user
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
    friends = Friend.where('user_id_giver = ?', @user.user_id).collect { |u| u.user_id_receiver }
    friends.push(@user.user_id)
    @gifts = Gift.where("user_id_giver in (?) or user_id_receiver in (?)", friends, friends).includes(:giver, :receiver).paginate(:page => params[:page]).order("created_at desc") if @user
    puts "@gifts.size = #{@gifts.size}"

    balance = 0
    @gifts.each do |g|
      next if !g.price or ![g.user_id_giver, g.user_id_receiver].index(@user.user_id)
      new_price = g.new_price_user(@user)
      if new_price
        balance += new_price
        g.balance = "%0.2f" % balance
      end
    end # each

    render_with_language __method__
  end # index

  def show
  end

end

class GiftsController < ApplicationController



  def new
  end

  def create
    @gift = Gift.new
    # todo: catch invalid price exception
    @gift.price = BigDecimal.new params[:gift][:price]
    @gift.currency = @user.currency
    @gift.description = params[:gift][:description]
    @gift.user_id_giver = session[:user_id]
    if !@gift.save
      # todo: check how to handle error messages in rails 4
      flash.now[:notice] = @gift.errors.full_messages.join(', ')
      index
      return
    end
    puts "create: description = #{@gift.description}"


    # todo: post message on gogole+ wall if google+ user
    api = Koala::Facebook::API.new(session[:access_token])
    begin
      api.put_connections("me", "feed", :message => params[:gift][:description])
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

    if flash.now[:notice]
      # error from login api (facebook, google etc)
      @gift.destroy
    else
      # todo: language support missing
      flash[:notice] = 'Gift written to your wall'
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
    @gift = Gift.new
    if params[:gift]
      # returned from create - error in save or error in api request - gift not saved
      @gift.price = BigDecimal.new params[:gift][:price]
      @gift.description = params[:gift][:description]
      @gift.file = params[:gift][:file]
    end
    if @user
      @gift.currency = @user.currency unless @gift.currency
      @gift.user_id_giver = session[:user_id]
    end
    puts "index: description = #{@gift.description}"

    # todo: initialize list of gifts. user_id_giver in fieldslist

    render_with_language __method__
  end # index

  def show
  end

end

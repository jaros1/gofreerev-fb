class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :request_url_for_header
  before_filter :fetch_user

  # Facebook API information is defined as OS environment variable
  private
  def api_id
    ENV['GOFREEREV_FB_APP_ID']
  end
  def api_secret
    ENV['GOFREEREV_FB_APP_SECRET']
  end

  # render to language specific pages.
  # viewname=create, session[:language] = da => call create-da.html.erb if the page exists
  private
  def render_with_language(viewname)
    language = session[:language]
    # language = 'en' # todo: remove this line
    puts "render_with_language: language = #{language}"
    if !language or language == 'en'
      render :action => viewname
      return
    end
    viewname2 = "#{viewname}_#{language}"
    filename = Rails.root.join('app', 'views', controller_name, "#{viewname2}.html.erb").to_s
    puts "render_with_language: filename = #{filename}"
    viewname2 = viewname unless File.exists?(filename)
    render :action => viewname2
  end # render_with_language

  private
  def debug_session (msg)
    [:oauth, :language, :country, :state, :access_token, :user_id].each do |name|
      puts "#{msg}: session[:#{name}] = #{session[name]}"
    end
  end

  private
  # used in page header for currency change
  def request_url_for_header
    @request_fullpath = request.fullpath
  end

  # check for code from FB - create/update user
  # fetch user info. Used in page heading etc
  private
  def fetch_user
    if params[:state] != session[:state] and params[:code].to_s != ''
      # Possible Cross-site Request Forgery - ignore code from FB
      puts "fetch_user: Possible csrf: params[:state] = #{params[:state]}, session[:state] = #{session[:state]}, params[:code] = #{params[:code]}"
      params[:code] = nil
    end
    if params[:code].to_s != '' and session[:oauth]
      # exchange code for access_token
      current_url = "#{request.protocol}#{request.host_with_port}#{request.fullpath}/"

      oauth = session[:oauth]
      access_token = oauth.get_access_token(params[:code])
      if access_token
        session[:access_token] = access_token
        # authorization ok (first login, following logins or new privs)
        # get name and current privs

        # get user id and name
        puts "get user id and name"
        api = Koala::Facebook::API.new(session[:access_token])
        api_request = "me?fields=name,permissions"
        puts "api_request = #{api_request}"
        api_response = api.get_object api_request
        puts "api_response = #{api_response.to_s}"
        user_id = "FB-#{api_response["id"]}"
        user_name = api_response["name"]
        u = User.find_by_user_id(user_id)
        u = User.new unless u
        u.user_id = user_id
        u.user_name = user_name
        if u.new_record?
          # set currency and balance for new user.
          puts "new user"
          country = session[:country] || 'US' #  Default USD
          u.currency = Country[country].currency.code
          u.balance = BigDecimal.new '0.0'
          u.balance_at = Date.today
        end
        u.permissions = api_response["permissions"]["data"][0]
        u.save!
        # login ok
        puts "login ok: user_id = #{session[:user_id]}"
        session[:user_id] = user_id
      end
      params[:code] = nil
      session.delete(:oauth)
    end
    puts "fetch_user: user_id = #{session[:user_id]}"
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
  end

end # ApplicationController

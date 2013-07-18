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
  helper_method :api_id
  def api_secret
    ENV['GOFREEREV_FB_APP_SECRET']
  end
  helper_method :api_secret

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
      # todo: catch
      #       Koala::Facebook::OAuthTokenRequestError in FbController#index
      #       type: OAuthException, code: 100, message: This authorization code has been used. [HTTP 400]
      #       should redirect to /fb/cross_site_forgery page
      # todo: rename cross_site_forgery to login_error
      access_token = oauth.get_access_token(params[:code])
      if access_token
        session[:access_token] = access_token

        # authorization ok (first login, following login or return from new priv.dialog)
        # get user id, name, permissions, profile picture and friends

        # 1) create/update user info (name and permissions)
        puts "get user id and name"
        api = Koala::Facebook::API.new(session[:access_token])
        api_request = "me?fields=name,permissions,friends,picture"
        puts "api_request = #{api_request}"
        api_response = api.get_object api_request
        puts "api_response = #{api_response.to_s}"
        user_id = "FB-#{api_response["id"]}"
        user_name = api_response["name"]
        u = User.find_by_user_id(user_id)
        u = User.new unless u
        u.user_id = user_id
        u.user_name = user_name
        u.no_api_friends = api_response["friends"]["data"].size
        if u.new_record?
          # set currency and balance for new user.
          puts "new user"
          country = session[:country] || 'US' #  Default USD
          u.currency = Country[country].currency.code
          u.balance = BigDecimal.new '0.0'
          u.balance_at = Date.today
        end
        u.permissions = api_response["permissions"]["data"][0]
        u.permissions = {} if u.permissions == []
        api_profile_picture_url = api_response["picture"]["data"]["url"]
        u.profile_picture_type = api_profile_picture_url.split('.').last
        u.save!

        # login ok - user created/updated - set session[:user_id]
        puts "login ok: user_id = #{session[:user_id]}"
        session[:user_id] = user_id

        # 2) update friends (insert/delete Friend)
        # compare Friend model data with friends array from API
        # only friends using Gofreerev are relevant
        # friends not using Gofreerev are ignored
        old_friend_list = Friend.where('user_id_giver = ?', u.user_id).collect { |u| u.user_id_receiver }
        api_friends_list = api_response["friends"]["data"].collect { |h| 'FB-' + h["id"] }
        new_friend_list = User.where('user_id in (?)', api_friends_list).collect { |u| u.user_id }
        new_friends = new_friend_list - old_friend_list
        removed_friends = old_friend_list - new_friend_list
        removed_friends.each do |user_id2|
          # remove friend
          f = Friend.where('user_id_giver = ? and user_id_receiver = ?', user_id, user_id2).first
          f.destroy if f
          f = Friend.where('user_id_giver = ? and user_id_receiver = ?', user_id2, user_id).first
          f.destroy if f
        end
        puts "#{removed_friends.size} friend(s) removed" if removed_friends.size > 0
        new_friends.each do |user_id2|
          f = Friend.new
          f.user_id_giver = user_id
          f.user_id_receiver= user_id2
          f.save!
          f = Friend.new
          f.user_id_giver = user_id2
          f.user_id_receiver= user_id
          f.save!
        end
        puts "#{new_friends.size} friend(s) added" if new_friends.size > 0

        # 3) download profile picture
        FileUtils.mkdir_p u.profile_picture_os_folder
        system("wget #{api_profile_picture_url} -O #{u.profile_picture_os_filename}")
      end
      params[:code] = nil
      session.delete(:oauth)
    end
    puts "fetch_user: user_id = #{session[:user_id]}"
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
    @usertype = @user ? @user.usertype : nil
  end

end # ApplicationController

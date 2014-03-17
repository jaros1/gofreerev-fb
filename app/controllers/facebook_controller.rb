class FacebookController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:create] # no crsf token when facebook starts the App with post /facebook
  after_filter :allow_iframe


  # post /facebook = facebook/create is called when facebook starts the APP.
  # / will route to this method if :fb_locale and :signed_request are in params (see routes.rb root and /lib/role_constraints.rb)
  # Signature 1: when an unauthorized user starts the app from facebook
  #   input: signed_request encoded JSON hash with (user, issued_at and algorithm)
  #          1) user 	      A JSON array containing the locale string, country string and the age object (containing the min and max numbers of the age range) for the current person using the app.
  #          2) algorithm 	A JSON string containing the mechanism used to sign the request.
  #          3) issued_at 	A JSON number containing the Unix timestamp when the request was signed.
  #   example: hash = { "algorithm"=>"HMAC-SHA256",
  #                     "issued_at"=>1373284394,
  #                     "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}}
  #   action: redirect to https://www.facebook.com/dialog/oauth?client_id=<client_id>&redirect_uri=<current_url>&scope=read_stream for FB app logn / authorization
  #           must be a redirect to top frame (top.location.href)
  # Signature 2: when an authorized user starts the app from facebook
  #   input: signed_request encoded JSON hash with (user, issued_at, algorithm, expires, oauth_token and user_id)
  #   example: hash = { "algorithm"=>"HMAC-SHA256",
  #                     "expires"=>1373374800,
  #                     "issued_at"=>1373370798,
  #                     "oauth_token"=>"CAAFjZBGzzOkcBAM3vNXbvDtDm3qcV7RQ3HwSRZAC9PRUiSvA8zLAnFFUwEmuV5t6fWohIPn8ZCDUrTZCUFtlUdOK1aSPhL1nvobmEBNucZBu9KLWqb4wRcB6jZBy6K49pZCQOaXRl0C8cj4ZCAYfdZC9tZCLC8wZAFhs9GWJMGIkO91AwZDZD",
  #                     "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}},
  #                     "user_id"=>"1705481075"}
  #   action:
  # Signature 3: when an authorized user deauthorise gofreerev in facebook (advanced settings - deauthorise dallback url)
  #   input: signed_request encoded JSON hash with (user, issued_at, algorithm, and user_id)
  #   example: hash = {"algorithm"=>"HMAC-SHA256",
  #                    "issued_at"=>1391445050,
  #                    "user"=>{"country"=>"dk", "locale"=>"en_GB"},
  #                    "user_id"=>"1705481075"}

  def create
    # logout any old facebook user
    logout(provider)

    signed_request = params[:signed_request]
    logger.debug2  "signed_request = #{signed_request}"
    # signed_request = 9m_Xew0oojeuzMjIZFqwx9lI_UI4AqC-vMWXL9o45g4.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsImlzc3VlZF9hdCI6MTM3MzI4NDA4OCwidXNlciI6eyJjb3VudHJ5IjoiZGsiLCJsb2NhbGUiOiJkYV9ESyIsImFnZSI6eyJtaW4iOjIxfX19
    if signed_request.to_s == ''
      # fatal error - signed_request parameter was missing in request
      logger.debug2  'fatal error - signed_request parameter was missing in request'
      render_with_language('cross_site_forgery')
      return
    end

    # unpack unsigned request
    oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
    hash = oauth.parse_signed_request(signed_request)
    logger.debug2  "hash = #{hash}"
    # hash = {"algorithm"=>"HMAC-SHA256", "issued_at"=>1373284394, "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}}

    # save language (only if language was nil)
    locale = hash['user']['locale']
    language = locale.to_s.first(2)
    session[:language] = language if !filter_locale(session[:language]) and filter_locale(language)
    logger.debug2  "session[:language] = #{session[:language]}"

    # todo: check if user already has authorized the required FB privileges
    # hash: hash = {"algorithm"=>"HMAC-SHA256", "expires"=>1373374800, "issued_at"=>1373370798,
    #               "oauth_token"=>"CAAFjZBGzzOkcBAM3vNXbvDtDm3qcV7RQ3HwSRZAC9PRUiSvA8zLAnFFUwEmuV5t6fWohIPn8ZCDUrTZCUFtlUdOK1aSPhL1nvobmEBNucZBu9KLWqb4wRcB6jZBy6K49pZCQOaXRl0C8cj4ZCAYfdZC9tZCLC8wZAFhs9GWJMGIkO91AwZDZD",
    #               "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}, "user_id"=>"1705481075"}
    if hash.has_key?('oauth_token') && hash.has_key?('user_id')
      # signature 2 - authorization in progress - show autologin page and redirect to facebook to complete authorization
      signature = 2
      logger.debug2  'user has already authorized gofreerev'
      # logger.debug2  "oauth_token = #{hash['oauth_token']}"
      logger.debug2  "user_id #{hash['user_id']}"
      # oauth_token = CAAFjZBGzzOkcBAB0GGUE4i4O9ZAT6FJ1N3U3mhl7S1TELLRl514fdEZAMuyMY4iUmFt74bBUWRH9WM4LYafsxs6osDzJc0ARo1yhRZCbAeQo0A9RXh5yEEW9cC3SjKC4LqbeO8x2Qy6JINJGO1pSkTllmQp5jPMZD
      # user_id  = 1705481075
      # autologin redirect to https://www.facebook.com/dialog/oauth? to get code without showing create.html erb page
      viewname = 'autologin'
    elsif hash.has_key?('user_id')
      # signature 3 - used has deauthorization gofreerev in facebook
      signature = 3
      viewname = 'deauthorize'
    else
      # signature 1 - new unauthorized user
      signature = 1
      # create.html.erb shows an intro page with an authorize link
      viewname = __method__
    end

    if signature == 3
      # FB deauthorize - user has removed Gofreerev from app settings page in facebook
      # a deleted marked user account (users/edit delete link) will be deleted within 6 minutes (CLEANUP_USER_DELETED)
      # a deauthorized user acccount will be deleted after 14 days (CLEANUP_USER_DEAUTHORIZED)
      # a inactive user account will be deleted after 1 year (CLEANUP_USER_INACTIVE)
      # todo: double check that user has deauthorized gofreerev. http://stackoverflow.com/questions/5623035/facebook-app-users-list. Maybe user.is_app_user can be used
      user_id = "#{hash['user_id']}/facebook"
      user = User.find_by_user_id(user_id)
      user.update_attribute(:deauthorized_at, Time.new) if user
    else
      # FB authorization with minimal permissions (information already public)
      # More permissions will be requested later when they are needed and the user can understand why
      # note that there are problems with cookie store and IE10 when login starts from facebook (session[:state] not preserved)
      # tasks table is used for temporary store of state in facebook/index => autologin => FB => facebook/index sequence
      # @auth_url =  oauth.url_for_oauth_code(:permissions=>"read_stream")
      @auth_url =  oauth.url_for_oauth_code :state => set_state_tasks_store('login')
      @auth_url = @auth_url.gsub('&amp;', '&') # fix invalid escape in auth url
      logger.debug2  "@auth_url = #{@auth_url}"
    end

    # show_friend page with an introduction and a authorize link - use create-<language>.html.erb if the view exists
    render_with_language viewname

  end # create


  # get /facebook - is called after authorization (create)
  # rejected: Parameters: {"error_reason"=>"user_denied", "error"=>"access_denied", "error_description"=>"The user denied your request."}
  # accepted: Parameters: {"code"=>"AQA6165EwuVn3EVKkzy2TOocej1wBb_t-9jEuhJQFFK7GH2PDkDbbSOOd9lhoqIYibusDfPpWOwaUg6XYiR2lcmP2tLgG0RPgRxL6qwFBZalg0j6wXSO8bZmjKn-yf9O_GOH9wm5ugMKLUihU7mjfLAbR58FrJ8wdgnej2aG9KLQvKNenb16Hf_ULI016u3DGHM-zGvmyb8xAgAAabOHkDQNT5C3lIO0eXTGMwo66zLrnn0jkENguAnAUuZrVym9OMiBV1f9ocg8WfgprflPq-BHOSHdhuHgYISHxO_nTs1dT7Ku5z551ZyBq1hG15aG4"}
  def index

    # where is request comming from?
    # login - login starter from facebook - previous request was post facebook/create
    # status_update - return from status_update priv. request (link in gifts/index page - inserted from util.post_on_facebook)
    # read_stream - return from read_stream priv. request (link in gifts/index page - inserted from util.post_on_facebook)
    # looks like permission status_update has been replaced with publish_actions
    # publish_actions is added when requesting status_update priv.
    context = params[:state].to_s.from(31)
    context = 'other' unless %w(login status_update read_stream).index(context)

    # Cross-site Request Forgery check
    # note that there are problems with cookie store and IE10 when login starts from facebook (session[:state] not preserved)
    # tasks table is used for temporary store of state in facebook/index => autologin => FB => facebook/index sequence
    # use special "tasks" session store for login. use normal session cookie store for add. mission privs. actions
    if context == 'login' and invalid_state_tasks_store? or # state in tasks store (special IE10 workaround)
        context != 'login' and invalid_state_cookie_store? # state in normal session cookie store
      save_flash ".invalid_state_#{context}", :appname => APP_NAME
      redirect_to :controller => (%w(login other).index(context) ? :auth : :gifts)
      logout(provider)
      return
    end # if invalid_state?
    clear_state_cookie_store

    if params[:error_reason] == 'user_denied'
      # user cancelled or denied api request
      save_flash ".user_denied_#{context}", :appname => APP_NAME
      redirect_to :controller => (%w(login other).index(context) ? :auth : :gifts)
      logout(provider) if context == 'login'
      return
    end

    if params[:code]
      # code received from FB - login in progress - exchange code for an access token
      # todo: error handling?!
      logger.debug2  "code = #{params[:code]}"
      oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
      begin
        access_token = oauth.get_access_token(params[:code])
      rescue Koala::Facebook::OAuthTokenRequestError => e
        if e.message =~ /authorization code has expired/
          save_flash ".auth_code_expired", :appname => APP_NAME
        else
          save_flash ".auth_code_error", :appname => APP_NAME, :error => e.message
        end
        redirect_to :controller => :auth
        return
      rescue Exception => e
        logger.debug2 "exception: #{e.message} (#{e.class})"
        save_flash ".auth_code_error_", :appname => APP_NAME, :error => e.message
        redirect_to :controller => :auth
        return
      end
      # logger.debug2  "access_token = #{access_token}"
      # login completed. access token is saved.
    end

    unless access_token
      # access token was not found. Eg if FB app login page not was used
      # todo: change to flash message
      render_with_language 'cross_site_forgery'
      return
    end

    # FB login completed
    logger.debug2 "login completed. context = #{context}"

    # get some basic user information
    # todo: what to do with permissions?
    #       permissions are updated in post_login_facebook task and after that page has been written
    #       as result file upload is disabled after ok status_update request
    #       could refresh permissions here
    #       or could add ajax to post_on_facebook to enable/disable file upload button?
    logger.debug2  'get user id and name'
    api_client = init_api_client(provider, access_token)
    api_request = 'me?fields=name,locale,link,picture.width(100).height(100),permissions'
    # logger.debug2  "api_request = #{api_request}"
    api_response = api_client.get_object api_request
    # logger.debug2  "api_response = #{api_response.to_s}"
    image = api_response['picture']['data']['url'] if api_response['picture'] and api_response['picture']['data']
    # fb_locale was received in FacebookController.create post request from facebook
    # add to api_response hash - is used for user.currency
    # api_response["language"] = session[:language]
    res = login :provider => provider,
                :token => access_token,
                :uid => api_response["id"],
                :name => api_response['name'],
                :image => image, # only used for new facebook users
                :country => api_response['locale'].to_s.last(2),
                :language => api_response['locale'].to_s.first(2),
                :profile_url => api_response['link']
    if !res
      # login ok
      user_id = "#{api_response['id']}/#{provider}"
      user = User.find_by_user_id(user_id)
      if context == 'login'
        no_friends = user.friends.size-1
        context = 'login_new_user' if no_friends == 0
      end
      if context == 'read_stream'
        logger.debug2 "identical facebook signatur for ok and skip response when requesting read_stream priv."
        logger.debug2  "api_response = #{api_response.to_s}"
        user.permissions = api_response['permissions']['data'][0]
        user.save
        context = 'read_stream_skip' unless user.read_gifts_allowed?
      end
      if context == 'status_update'
        # add publish_actions to facebook user before redirecting to gifts/index page
        # permissions will be updated in post_login_facebook task, but that is to late for this redirect
        # adding publish_actions enables file upload in gifts/index page now
        permissions = user.permissions
        permissions["publish_actions"] = 1
        user.permissions = permissions
        user.save!
      end
      save_flash ".ok_#{context}", user.app_and_apiname_hash
      redirect_to :controller => :gifts
    else
      # login failed
      key, options = res
      begin
        save_flash key, options
      rescue Exception => e
        logger.debug2  "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        save_flash '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
      end
      redirect_to :controller => :auth
    end

  end # index



  # fix blank canvas in facebook - https://coderwall.com/p/toddiq
  private
  def allow_iframe
    response.headers['X-Frame-Options'] = 'GOFORIT'
  end

  private
  def provider
    "facebook"
  end

end

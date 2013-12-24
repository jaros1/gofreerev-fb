class FacebookController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:create] # no crsf token when facebook starts the App with post /facebook
  after_filter :allow_iframe


  # post /facebook = facebook/create is called when facebook starts the APP.
  # / will route to this method if :fb_locale and :signed_request are in params (see routes.rb root and /lib/role_constraints.rb)
  # Signatur 1: when an unauthorized user starts the app from facebook
  #   input: signed_request encoded JSON hash with (user, issued_at and algorithm)
  #          1) user 	      A JSON array containing the locale string, country string and the age object (containing the min and max numbers of the age range) for the current person using the app.
  #          2) algorithm 	A JSON string containing the mechanism used to sign the request.
  #          3) issued_at 	A JSON number containing the Unix timestamp when the request was signed.
  #   example: hash = { "algorithm"=>"HMAC-SHA256",
  #                     "issued_at"=>1373284394,
  #                     "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}}
  #   action: redirect to https://www.facebook.com/dialog/oauth?client_id=<client_id>&redirect_uri=<current_url>&scope=read_stream for FB app logn / authorization
  #           must be a redirect to top frame (top.location.href)
  # Signatur 2: when an authorized user starts the app from facebook
  #   input: signed_request encoded JSON hash with (user, issued_at, algorithm, expires, oauth_token and user_id)
  #   example: hash = { "algorithm"=>"HMAC-SHA256",
  #                     "expires"=>1373374800,
  #                     "issued_at"=>1373370798,
  #                     "oauth_token"=>"CAAFjZBGzzOkcBAM3vNXbvDtDm3qcV7RQ3HwSRZAC9PRUiSvA8zLAnFFUwEmuV5t6fWohIPn8ZCDUrTZCUFtlUdOK1aSPhL1nvobmEBNucZBu9KLWqb4wRcB6jZBy6K49pZCQOaXRl0C8cj4ZCAYfdZC9tZCLC8wZAFhs9GWJMGIkO91AwZDZD",
  #                     "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}},
  #                     "user_id"=>"1705481075"}
  #   action:
  def create
    signed_request = params[:signed_request]
    puts2log  "signed_request = #{signed_request}"
    # signed_request = 9m_Xew0oojeuzMjIZFqwx9lI_UI4AqC-vMWXL9o45g4.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsImlzc3VlZF9hdCI6MTM3MzI4NDA4OCwidXNlciI6eyJjb3VudHJ5IjoiZGsiLCJsb2NhbGUiOiJkYV9ESyIsImFnZSI6eyJtaW4iOjIxfX19
    if signed_request.to_s == ''
      # fatal error - signed_request parameter was missing in request
      puts2log  'fatal error - signed_request parameter was missing in request'
      render_with_language('cross_site_forgery')
      return
    end

    # unpack unsigned request
    oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
    hash = oauth.parse_signed_request(signed_request)
    puts2log  "hash = #{hash}"
    # hash = {"algorithm"=>"HMAC-SHA256", "issued_at"=>1373284394, "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}}

    # save language (only if language was nil)
    locale = hash['user']['locale']
    language = locale.to_s.first(2)
    session[:language] = language if !filter_locale(session[:language]) and filter_locale(language)
    puts2log  "session[:language] = #{session[:language]}"

    # todo: check if user already has authorized the required FB privileges
    # hash: hash = {"algorithm"=>"HMAC-SHA256", "expires"=>1373374800, "issued_at"=>1373370798,
    #               "oauth_token"=>"CAAFjZBGzzOkcBAM3vNXbvDtDm3qcV7RQ3HwSRZAC9PRUiSvA8zLAnFFUwEmuV5t6fWohIPn8ZCDUrTZCUFtlUdOK1aSPhL1nvobmEBNucZBu9KLWqb4wRcB6jZBy6K49pZCQOaXRl0C8cj4ZCAYfdZC9tZCLC8wZAFhs9GWJMGIkO91AwZDZD",
    #               "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}, "user_id"=>"1705481075"}
    if hash.has_key?('oauth_token') && hash.has_key?('user_id')
      puts2log  'user has already authorized gofreerev'
      puts2log  "oauth_token = #{hash['oauth_token']}"
      puts2log  "user_id #{hash['user_id']}"
      # oauth_token = CAAFjZBGzzOkcBAB0GGUE4i4O9ZAT6FJ1N3U3mhl7S1TELLRl514fdEZAMuyMY4iUmFt74bBUWRH9WM4LYafsxs6osDzJc0ARo1yhRZCbAeQo0A9RXh5yEEW9cC3SjKC4LqbeO8x2Qy6JINJGO1pSkTllmQp5jPMZD
      # user_id  = 1705481075
      # autologin redirect to https://www.facebook.com/dialog/oauth? to get code without showing create.html erb page
      viewname = 'autologin'
    else
      # create.html.erb shows an intro page with an authorize link
      viewname = __method__
    end

    # FB authorization with minimal permissions (information already public)
    # More permissions will be requested later when they are needed and the user can understand why
    # @auth_url =  oauth.url_for_oauth_code(:permissions=>"read_stream")
    puts2log  "session[:state] = #{session[:state]}"
    @auth_url =  oauth.url_for_oauth_code :state => set_state('login')
    puts2log  "@auth_url = #{@auth_url}"

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
    if invalid_state?
      flash[:notice] = t ".invalid_state_#{context}", :appname => APP_NAME
      redirect_to :controller => (%w(login other).index(context) ? :auth : :gifts)
      logout(provider)
      clear_state
      return
    end # if invalid_state?
    clear_state

    if params[:error_reason] == 'user_denied'
      # user cancelled or denied api request
      flash[:notice] = t ".user_denied_#{context}", :appname => APP_NAME
      redirect_to :controller => (%w(login other).index(context) ? :auth : :gifts)
      logout(provider) if context == 'login'
      return
    end

    if params[:code]
      # code received from FB - login in progress - exchange code for an access token
      # todo: error handling?!
      puts2log  "code = #{params[:code]}"
      oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider]
      access_token = oauth.get_access_token(params[:code])
      # puts2log  "access_token = #{access_token}"
      # login completed. access token is saved.
    end

    unless access_token
      # access token was not found. Eg if FB app login page not was used
      # todo: change to flash message
      render_with_language 'cross_site_forgery'
      return
    end

    # FB login completed
    puts2log  'login completed'

    # get some basic user information
    # todo: what to do with permissions?
    #       permissions are updated in post_login_facebook task and after that page has been written
    #       as result file upload is disabled after ok status_update request
    #       could refresh permissions here
    #       or could add ajax to post_on_facebook to enable/disable file upload button?
    puts2log  'get user id and name'
    api = Koala::Facebook::API.new(access_token)
    api_request = 'me?fields=name,picture,locale'
    puts2log  "api_request = #{api_request}"
    api_response = api.get_object api_request
    puts2log  "api_response = #{api_response.to_s}"
    # fb_locale was received in FacebookController.create post request from facebook
    # add to api_response hash - is used for user.currency
    # api_response["language"] = session[:language]
    res = login :provider => provider,
                :token => access_token,
                :uid => api_response["id"],
                :name => api_response['name'],
                :image => (api_response['picture']['data']['url'] if api_response['picture'] and api_response['picture']['data']),
                :country => api_response['locale'].to_s.last(2),
                :language => api_response['locale'].to_s.first(2)
    if !res
      # login ok
      user_id = "#{api_response['id']}/#{provider}"
      user = User.find_by_user_id(user_id)
      if context == 'status_update'
        # add publish_actions to facebook user before redirecting to gifts/index page
        # permissions will be updated in post_login_facebook task, but that is to late for this redirect
        # adding publish_actions enables file upload in gifts/index page now
        permissions = user.permissions
        permissions["publish_actions"] = 1
        user.permissions = permissions
        user.save!
      end
      flash[:notice] = t ".ok_#{context}", :appname => APP_NAME
      redirect_to :controller => :gifts
    else
      # login failed
      key, options = res
      begin
        flash[:notice] = t key, options
      rescue Exception => e
        puts2log  "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        flash[:notice] = t '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
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

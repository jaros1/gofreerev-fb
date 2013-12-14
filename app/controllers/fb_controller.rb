class FbController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:create] # no crsf token when facebook starts the App with post /fb
  after_filter :allow_iframe


  # post /fb = fb/create is called when FB starts the APP.
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
    puts "signed_request = #{signed_request}"
    # signed_request = 9m_Xew0oojeuzMjIZFqwx9lI_UI4AqC-vMWXL9o45g4.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsImlzc3VlZF9hdCI6MTM3MzI4NDA4OCwidXNlciI6eyJjb3VudHJ5IjoiZGsiLCJsb2NhbGUiOiJkYV9ESyIsImFnZSI6eyJtaW4iOjIxfX19
    if signed_request.to_s == ''
      # fatal error - signed_request parameter was missing in request
      puts 'fatal error - signed_request parameter was missing in request'
      render_with_language('cross_site_forgery')
      return
    end

    # unpack unsigned request
    api_callback_url = SITE_URL + 'fb/'
    puts "Koala::Facebook::OAuth.new: api_callback_url = #{api_callback_url}"
    oauth = Koala::Facebook::OAuth.new(api_id, api_secret, api_callback_url)
    hash = oauth.parse_signed_request(signed_request)
    puts "hash = #{hash}"
    # hash = {"algorithm"=>"HMAC-SHA256", "issued_at"=>1373284394, "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}}

    # save language and country
    locale = hash['user']['locale']
    session[:language] = locale.first(2)
    session[:country] = locale.last(2)
    puts "session[:language] = #{session[:language]}"

    # todo: check if user already has authorized the required FB privileges
    # hash: hash = {"algorithm"=>"HMAC-SHA256", "expires"=>1373374800, "issued_at"=>1373370798,
    #               "oauth_token"=>"CAAFjZBGzzOkcBAM3vNXbvDtDm3qcV7RQ3HwSRZAC9PRUiSvA8zLAnFFUwEmuV5t6fWohIPn8ZCDUrTZCUFtlUdOK1aSPhL1nvobmEBNucZBu9KLWqb4wRcB6jZBy6K49pZCQOaXRl0C8cj4ZCAYfdZC9tZCLC8wZAFhs9GWJMGIkO91AwZDZD",
    #               "user"=>{"country"=>"dk", "locale"=>"da_DK", "age"=>{"min"=>21}}, "user_id"=>"1705481075"}
    if hash.has_key?('oauth_token') && hash.has_key?('user_id')
      puts 'user has already authorized gofreerev'
      puts "oauth_token = #{hash['oauth_token']}"
      puts "user_id #{hash['user_id']}"
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
    puts "session[:state] = #{session[:state]}"
    @auth_url =  oauth.url_for_oauth_code :state => set_state('login')
    puts "@auth_url = #{@auth_url}"

    # show_friend page with an introduction and a authorize link - use create-<language>.html.erb if the view exists
    render_with_language viewname
  end # create


  # get /fb - is called after authorization (create)
  # rejected: Parameters: {"error_reason"=>"user_denied", "error"=>"access_denied", "error_description"=>"The user denied your request."}
  # accepted: Parameters: {"code"=>"AQA6165EwuVn3EVKkzy2TOocej1wBb_t-9jEuhJQFFK7GH2PDkDbbSOOd9lhoqIYibusDfPpWOwaUg6XYiR2lcmP2tLgG0RPgRxL6qwFBZalg0j6wXSO8bZmjKn-yf9O_GOH9wm5ugMKLUihU7mjfLAbR58FrJ8wdgnej2aG9KLQvKNenb16Hf_ULI016u3DGHM-zGvmyb8xAgAAabOHkDQNT5C3lIO0eXTGMwo66zLrnn0jkENguAnAUuZrVym9OMiBV1f9ocg8WfgprflPq-BHOSHdhuHgYISHxO_nTs1dT7Ku5z551ZyBq1hG15aG4"}
  def index
    # uncomment the next line to check Cross-site Request Forgery response
    # session[:state] = String.generate_random_string(30)
    if invalid_state?
      # possible Cross-site Request Forgery
      case params[:state].to_s.from(31)
        when 'login'
          # from fb/create - login started from fb with invalid state
          flash[:notice] = t '.invalid_state_login'
          redirect_to :controller => :auth
        when 'status_update'
          # return from request status_update priv. with invalid state
          flash[:notice] = t '.invalid_state_status_update'
          redirect_to :controller => :gifts
        when 'read_stream'
          # return from request read_stream priv, with invalid state
          flash[:notice] = t '.invalid_state_read_stream'
          redirect_to :controller => :gifts
        else
          # invalid state - unknown start
          flash[:notice] = t '.invalid_state_other'
          redirect_to :controller => :auth
      end
      # log out any old facebook user
      provider = 'facebook'
      user_ids = session[:user_ids] || []
      user_ids.delete_if { |user_id| user_id.split('/').last == provider}
      tokens = session[:tokens]
      tokens.delete(provider)
      return
    end # if invalid_state?

    debug_session(__method__.to_s + ' - start') # debug. dump session variables

    if params[:error_reason] == 'user_denied'
      # todo: this error message is returned in three different situations.
      # 1) First login from rails to facebook - user reject authorisation
      puts 'used denied access to basic information'
      session.delete(:state)
      render_with_language 'user_denied'
      # debug_session(__method__.to_s + ' - end') # debug. dump session variables
      return
    end

    if params[:code]
      # code received from FB - login in progress - exchange code for an access token
      if session[:state] == params[:state].to_s.split('-').first
        # exchange code for an access token
        # todo: error handling?!
        puts "code = #{params[:code]}"
        api_callback_url = SITE_URL + 'fb/'
        oauth = Koala::Facebook::OAuth.new(api_id, api_secret, api_callback_url)
        access_token = oauth.get_access_token(params[:code])
        # puts "access_token = #{access_token}"
        # login completed. access token is saved.
        session.delete(:state)
      else
        # possible Cross-site Request Forgery
        puts 'state missing or does not match - could be Cross-site Request Forgery'
        puts "state: session[:state] = #{session[:state]}, params[:state] = #{params[:state]}"
        session.delete(:state)
        session.delete(:user_ids)
        render_with_language 'cross_site_forgery'
        # debug_session(__method__.to_s + ' - end') # debug. dump session variables
        return
      end
    end
    session.delete(:state)

    unless access_token
      # access token was not found. Eg if FB app login page not was used
      render_with_language 'cross_site_forgery'
      return
    end

    # FB login completed
    puts 'index: login completed'

    # get user information
    puts 'get user id and name'
    api = Koala::Facebook::API.new(access_token)
    api_request = 'me?fields=name,picture,locale'
    puts "api_request = #{api_request}"
    api_response = api.get_object api_request
    puts "api_response = #{api_response.to_s}"
    # fb_locale was received in fbController.create post request from facebook
    # add to api_response hash - is used for user.currency
    # api_response["country"] = session[:country]
    # api_response["language"] = session[:language]
    res = login :provider => 'facebook',
                :token => access_token,
                :uid => api_response["id"],
                :name => api_response['name'],
                :image => (api_response['picture']['data']['url'] if api_response['picture'] and api_response['picture']['data']),
                :country => api_response['locale'].to_s.last(2),
                :language => api_response['locale'].to_s.first(2)
    if !res
      # login ok
      redirect_to :controller => :gifts
    else
      # login failed
      key, options = res
      begin
        flash[:notice] = t key, options
      rescue Exception => e
        puts "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
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

end

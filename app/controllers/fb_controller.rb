class FbController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:create] # no crsf token when FB starts the App with post /fb
  after_filter :allow_iframe

  # get /fb - is called after authorization (create)
  # rejected: Parameters: {"error_reason"=>"user_denied", "error"=>"access_denied", "error_description"=>"The user denied your request."}
  # accepted: Parameters: {"code"=>"AQA6165EwuVn3EVKkzy2TOocej1wBb_tD0-9jEuhJQFFK7GH2PDkDbbSOOd9lhoqIYibusDfPpWOwaUg6XYiR2lcmP2tLgG0RPgRxL6qwFBZalg0j6wXSO8bZmjKn-yf9O_GOH9wm5ugMKLUihU7mjfLAbR58FrJ8wdgnej2aG9KLQvKNenb16Hf_ULI016u3DGHM-zGvmyb8xAgAAabOHkDQNT5C3lIO0eXTGMwo66zLrnn0jkENguAnAUuZrVym9OMiBV1f9ocg8WfgprflPq-BHOSHdhuHgYISHxO_nTs1dT7Ku5z551ZyBq1hG15aG4"}
  def index
    # uncomment the next line to check Cross-site Request Forgery response
    # session[:state] = String.generate_random_string(30)

    debug_session(__method__.to_s + ' - start') # debug. dump session variables

    if params[:error_reason] == 'user_denied'
      puts 'used denied access to basic information'
      session.delete(:oauth)
      session.delete(:state)
      render_with_language 'user_denied'
      # debug_session(__method__.to_s + ' - end') # debug. dump session variables
      return
    end

    if params[:code]
      # code received from FB - login in progress - exchange code for an access token
      if session[:state] == params[:state]
        # exchange code for an access token
        # todo: error handling?!
        puts "code = #{params[:code]}"
        access_token = session[:access_token] = session[:oauth].get_access_token(params[:code])
        puts "access_token = #{access_token}"
        # login completed. access token is saved.
        session.delete(:oauth)
        session.delete(:state)
      else
        # possible Cross-site Request Forgery
        puts 'state missing or does not match - could be Cross-site Request Forgery'
        puts "state: session[:state] = #{session[:state]}, params[:state] = #{params[:state]}"
        session.delete(:oauth)
        session.delete(:state)
        session.delete(:user_id)
        render_with_language 'cross_site_forgery'
        # debug_session(__method__.to_s + ' - end') # debug. dump session variables
        return
      end
    end

    unless session[:access_token]
      # access token was not found. Eg if FB app login page not was used
      render_with_language 'cross_site_forgery'
      return
    end

    # FB login completed
    puts 'index: login completed'

    unless (user_id = session[:user_id])
      # get user id and name
      puts 'get user id and name'
      api = Koala::Facebook::API.new(session[:access_token])
      api_request = 'me?fields=name,permissions'
      puts "api_request = #{api_request}"
      api_response = api.get_object api_request
      puts "api_response = #{api_response.to_s}"
      user_id = "FB-#{api_response['id']}"
      user_name = api_response['name']
      u = User.find_by_user_id(user_id)
      u = User.new unless u
      u.user_id = user_id
      u.user_name = user_name
      if u.new_record?
        # set currency and balance for new user.
        puts 'new user'
        country = session[:country] || 'US' #  Default USD
        u.currency = Country[country].currency.code
        u.balance = 0.0
        u.balance_at = Date.today
      end
      u.permissions = api_response['permissions']['data'][0]
      u.save!
      # login ok
      puts "login ok: user_id = #{session[:user_id]}"
      session[:user_id] = user_id
    end # if

    # redirect to gifts page
    redirect_to '/gifts'
    # debug_session(__method__.to_s + ' - end') # debug. dump session variables
  end # index

  # post /fb = fb/create is called when FB starts the APP.
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
    # new rails session every time FB starts the rails app
    reset_session

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
    # oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, SITE_URL + '/fb/callback')
    api_callback_url = SITE_URL + 'fb/'
    puts "Koala::Facebook::OAuth.new: api_callback_url = #{api_callback_url}"
    oauth = session[:oauth] = Koala::Facebook::OAuth.new(api_id, api_secret, api_callback_url) unless oauth =  session[:oauth]
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
      # create.erb.html shows an intro page with an authorize link
      viewname = __method__
    end

    # FB authorization with minimal permissions (information already public)
    # More permissions will be requested later when they are needed and the user can understand why
    # @auth_url =  oauth.url_for_oauth_code(:permissions=>"read_stream")
    state = session[:state] = String.generate_random_string(30)
    puts "session[:state] = #{session[:state]}"
    @auth_url =  oauth.url_for_oauth_code :state => state
    puts "@auth_url = #{@auth_url}"

    # show_friend page with an introduction and a authorize link - use create-<language>.html.erb if the view exists
    render_with_language viewname
  end # create

  # logout
  def destroy
    # fetch user for language support in logout page
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
    # empty session - keep language for language support in pages
    session.keys.each do |name|
      session.delete(name) unless %w(_csrf_token).index(name.to_s)
    end
    case
      when @user.facebook? then
        redirect_to 'http://facebook.com/'
      when @user.google_plus? then
        redirect_to 'https://plus.google.com/'
      else
        # unknown login API
        render_with_language __method__
    end
  end


  # fix blank canvas in facebook - https://coderwall.com/p/toddiq
  private
  def allow_iframe
    response.headers['X-Frame-Options'] = 'GOFORIT'
  end

end
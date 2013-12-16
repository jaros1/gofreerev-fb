class AuthController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:check] # no crsf token when facebook starts the App with post /fb
  after_filter :allow_iframe
  before_filter :clear_state

  def index
    @providers = OmniAuth::Builder.providers
    # find logged in providers - userid and token
    user_ids = session[:user_ids] || []
    tokens = session[:tokens] || {}
    @logged_in_providers = user_ids.collect { |user_id| user_id.split('/').last }.find_all { |provider| tokens[provider].to_s != "" }
  end

  # omniauth callback on success (login was started from rails)
  def create
    @auth_hash = auth_hash
    # puts "auth_hash = #{auth_hash}"
    # login - return nil (ok) or array with translate key and options for error message
    # auth_hash.get_xxx methods are defined in initializers/omniauth*.rb
    res = login :provider => auth_hash.get_provider,
                :token => auth_hash.get_token,
                :uid => auth_hash.get_uid,
                :name => auth_hash.get_user_name,
                :image => auth_hash.get_image,
                :country => auth_hash.get_country,
                :language => auth_hash.get_language
    if !res
      # login ok
      redirect_to :controller => :gifts, :action => :index
    else
      # login failed
      # todo: copy translate error handling from util.do_tasks
      key, options = res
      begin
        flash[:notice] = t key, options
      rescue Exception => e
        puts "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        flash[:notice] = t '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
      end
      redirect_to :controller => :auth, :action => :index
    end
  end # create

  # omniauth callback on failure (login was started from rails)
  # oauth_failure is also used if user cancels authorization/login
  def oauth_failure
    env = request.env
    # puts "env.keys = #{env.keys.sort.join(', ')}"
    # puts "env = #{env} (#{env.class})"
    error = env['omniauth.error']
    type = env['omniauth.error.type']
    strategy = env['omniauth.error.strategy']
    puts "error = #{error} (#{error.class})"
    puts "error.methods = #{error.methods.sort.join(', ')}"
    puts "error.message = #{error.message} (#{error.message.class})"

    # check cancelled facebook login
    # Parameters: {"error_reason"=>"user_denied",
    #              "error"=>"access_denied",
    #              "error_description"=>"The user denied your request.", "state"=>"480ee4d402ad5b940d6b48
    # error.message = OmniAuth::Strategies::OAuth2::CallbackError (String)
    # request_uri = http://localhost/auth/facebook/callback?error_reason=user_denied&error=access_denied&error_description=The+user+denied+your+request.&state=480ee4d402ad5b940d6b48805c6ec91ac70f840d400ac998
    # type = invalid_credentials (Symbol)
    # error.class = OmniAuth::Strategies::OAuth2::CallbackError
    # error.message = OmniAuth::Strategies::OAuth2::CallbackError
    request_uri = env['REQUEST_URI']
    uri_prefix = "#{SITE_URL}auth/facebook/callback?error"
    if request_uri.first(uri_prefix.length) == uri_prefix and
        type == :invalid_credentials and
        error.class == OmniAuth::Strategies::OAuth2::CallbackError and
        params[:error] == 'access_denied'
      puts "facebook login was cancelled"
      flash[:notice] = t ".login_cancelled", :provider => 'facebook', :appname => APP_NAME
      redirect_to :controller => :auth
      return
    end

    # todo: check cancelled google+ login
    # no cancel button in google+ - use have to use back button

    # check for cancelled linkedin login
    # that is first logon with scope r_basicprofile r_network
    # and additional authorisation with scope r_basicprofile r_network rw_nus.)
    type = env['omniauth.error.type']
    if request_uri == "#{SITE_URL}auth/linkedin/callback" and
        type == :invalid_credentials and
        error.class == OAuth::Problem and
        error.message == 'parameter_absent'
      client = get_linkedin_client()
      if client
        puts "request for linked rw_nus priv. was cancelled"
        flash[:notice] = t ".linkedin_rw_nus_cancelled", :appname => APP_NAME
        redirect_to :controller => :gifts
      else
        puts "linkedin login was cancelled"
        flash[:notice] = t ".login_cancelled", :provider => 'linkedin', :appname => APP_NAME
        redirect_to :controller => :auth
      end
      return
    end

    # todo: check cancelled twitter login
    # twitter login fejlede! invalid_credentials: 401 Unauthorized
    puts "request_uri = #{request_uri}"
    puts "type = #{type} (#{type.class})"
    puts "error.class = #{error.class}"
    puts "error.message = #{error.message}"
    # request_uri = http://localhost/auth/twitter/callback?denied=2ddtp3zYx5CdldwXCOshMuFVC3QEiAMyAJpKUbO4Fc
    # type = invalid_credentials (Symbol)
    # error.class = OAuth::Unauthorized
    # error.message = 401 Unauthorized
    # Parameters: {"denied"=>"2ddtp3zYx5CdldwXCOshMuFVC3QEiAMyAJpKUbO4Fc"}
    uri_prefix = "#{SITE_URL}auth/twitter/callback?denied="
    if request_uri.first(uri_prefix.length) == uri_prefix and
        type == :invalid_credentials and
        error.class == OAuth::Unauthorized and
        error.message == '401 Unauthorized'
      puts "twitter login was cancelled"
      flash[:notice] = t ".login_cancelled", :provider => 'twitter', :appname => APP_NAME
      redirect_to :controller => :auth
      return
    end

    # puts "type = #{type}"
    # puts "strategy = #{strategy}"
    # puts "strategy.methods = #{strategy.methods.sort.join(', ')}"
    # puts "strategy.name = #{strategy.name}"
    #error = :
    #    {
    #        "errorCode": 0,
    #    "message": "Unable to verify access token",
    #    "requestId": "K7SXSRYQUA",
    #    "status": 401,
    #    "timestamp": 1384762283211
    #}
    #type = invalid_credentials
    #strategy = #<OmniAuth::Strategies::LinkedIn:0xb6480cb8>
    #strategy.name = linkedin
    message = $1 if error.message =~ /"message": "(.*?)"/
    message = error.message unless message
    # flash[:notice] = "Authentication failure! #{type}: #{message}"
    flash[:notice] = t '.authentication_failure', :provider => my_provider(strategy.name), :type => type, :message => message
    redirect_to '/auth'
  end # oauth_failure


  # logout
  def destroy
    # fetch user for language support in logout page
    if @users.length == 0
      flash[:notice] = t '.already_logged_off'
      redirect_to :action => :index
      return
    end
    # empty session
    # language is kept for post log out language support
    # created is kept so that cookie note is not displayed after log out
    session.keys.each do |name|
      session.delete(name) unless %w(_csrf_token language created).index(name.to_s)
    end
    if @users.length > 1
      flash[:notice] = t '.logged_off', :appname => APP_NAME
      redirect_to :action => :index
      return
    end
    @user = @users.first
    case @user.provider
      when 'facebook'
        redirect_to 'https://facebook.com/'
      when 'google_oauth2'
        redirect_to 'https://plus.google.com/'
      when 'linkedin'
        redirect_to 'https://www.linkedin.com/'
      when 'twitter'
        redirect_to 'https://twitter.com/'
      else
        redirect_to :action => :index
    end
  end # destroy



  protected
  def auth_hash
    request.env['omniauth.auth']
  end

  # fix blank canvas in facebook - https://coderwall.com/p/toddiq
  private
  def allow_iframe
    response.headers['X-Frame-Options'] = 'GOFORIT'
  end

end

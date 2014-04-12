class AuthController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:check] # no crsf token when facebook starts the App with post /facebook
  after_filter :allow_iframe
  before_filter :clear_state_cookie_store

  # log in/out index page
  def index
    all_providers = OmniAuth::Builder.providers
    logged_in_providers = @users.find_all { |user| !user.dummy_user? }.collect { |user| user.provider }
    # initialize @providers hash with true/false to logged in provider
    @providers = []
    all_providers.each do |provider|
      # logged_in: 0 not connected, 1 connected with one login provider, 2 connected with multiple login providers
      logged_in = case
                    when !logged_in_providers.index(provider) then
                      0 # not logged in - log in link
                    when logged_in_providers.length == 1 then
                      1 # logged in with one login provider - log out link and return to login provider
                    else
                      2 # logged in with multiple login providers - log out link and stay on auth/index page
                  end # case
      # access; 0 not connected, 1 read access, 2 read+write access, 3 special note about twitter access
      if logged_in == 0
        access = 0
      else
        user = @users.find { |u| u.provider == provider }
        access = user.post_on_wall_authorized? ? 2 : 1
        access = 3 if access == 1 and provider == 'twitter'
      end
      # post_on_wall checkbox. 0 disable/hide, 1 unchecked, 2 checked
      if logged_in == 0 or !API_POST_PERMITTED[provider]
        post_on_wall = 0
      else
        post_on_wall = user.post_on_wall_yn == 'Y' ? 2 : 1
      end
      @providers << [provider, logged_in, access, post_on_wall]
    end # each provider

    @providers = @providers.sort_by { |a| provider_camelize(a) }

    # check share_level and offline_access
    @users.each do |user|
      next unless user.share_account_id
      if [3,4].index(user.share_account.share_level) and user.share_account.offline_access_yn == 'N'
        user.share_account.share_level = 2
        user.share_account.save!
      end
    end

  end # index

  # omniauth callback on success (login was started from rails)
  def create
    @auth_hash = auth_hash

    # login - return nil (ok) or array with translate key and options for error message
    # auth_hash.get_xxx methods are defined in initializers/omniauth*.rb
    provider = auth_hash.get_provider

    # auth hash debugging for new login providers:
    #if provider == 'flickr' and auth_hash.get_uid.to_s == '107614965@N99'
    #  logger.debug2 'checking structure of auth hash for flickroursquare'
    #  t = Task.new
    #  t.session_id = session[:session_id]
    #  t.task = 'flickr'
    #  t.priority = 5
    #  t.ajax = 'N'
    #  t.task_data = auth_hash.to_yaml
    #  t.save!
    #end

    res = login :provider => provider,
                :token => auth_hash.get_token,
                :expires_at => auth_hash.get_expires_at,
                :uid => auth_hash.get_uid,
                :name => auth_hash.get_user_name,
                :image => auth_hash.get_image,
                :country => auth_hash.get_country,
                :language => auth_hash.get_language,
                :profile_url => auth_hash.get_profile_url
    if !res
      # login ok
      user_id = login_user_ids.find { |userid2| userid2.split('/').last == provider }
      user = User.find_by_user_id(user_id)
      no_friends = user.friends.size-1
      if no_friends == 0 and !user.share_account_id
        save_flash_key '.login_ok_new_user', user.app_and_apiname_hash
      else
        save_flash_key '.login_ok', user.app_and_apiname_hash
      end
      if @users.size == 1 and !user.share_account_id
        # singleton user login
        redirect_to :controller => :gifts, :action => :index
      else
        # multi user login
        redirect_to :controller => :auth, :action => :index
      end
    else
      # login failed
      # todo: copy translate error handling from util.do_tasks
      key, options = res
      begin
        save_flash_key key, options
      rescue Exception => e
        logger.debug2  "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        save_flash_key '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
      end
      redirect_to :controller => :auth, :action => :index
    end
  end # create

  # omniauth callback on failure (login was started from rails)
  # oauth_failure is also used if user cancels authorization/login
  def oauth_failure
    env = request.env
    # logger.debug2  "env.keys = #{env.keys.sort.join(', ')}"
    # logger.debug2  "env = #{env} (#{env.class})"
    error = env['omniauth.error']
    type = env['omniauth.error.type']
    strategy = env['omniauth.error.strategy']
    logger.debug2  "error = #{error} (#{error.class})"
    logger.debug2  "error.methods = #{error.methods.sort.join(', ')}"
    logger.debug2  "error.message = #{error.message} (#{error.message.class})"

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
      logger.debug2  "facebook login was cancelled"
      save_flash_key ".login_cancelled", :provider => 'facebook', :appname => APP_NAME
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
      client = get_linkedin_api_client()
      if client
        logger.debug2  "request for linked rw_nus priv. was cancelled"
        save_flash_key ".linkedin_rw_nus_cancelled", :appname => APP_NAME
        redirect_to :controller => :gifts
      else
        logger.debug2  "linkedin login was cancelled"
        save_flash_key ".login_cancelled", :provider => 'linkedin', :appname => APP_NAME
        redirect_to :controller => :auth
      end
      return
    end

    # todo: check cancelled twitter login
    # twitter login fejlede! invalid_credentials: 401 Unauthorized
    logger.debug2  "request_uri = #{request_uri}"
    logger.debug2  "type = #{type} (#{type.class})"
    logger.debug2  "error.class = #{error.class}"
    logger.debug2  "error.message = #{error.message}"
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
      logger.debug2  "twitter login was cancelled"
      save_flash_key ".login_cancelled", :provider => 'twitter', :appname => APP_NAME
      redirect_to :controller => :auth
      return
    end

    # logger.debug2  "type = #{type}"
    # logger.debug2  "strategy = #{strategy}"
    # logger.debug2  "strategy.methods = #{strategy.methods.sort.join(', ')}"
    # logger.debug2  "strategy.name = #{strategy.name}"
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
    message = message.to_s.first(40)
    # flash[:notice] = "Authentication failure! #{type}: #{message}"
    save_flash_key '.authentication_failure', :provider => provider_downcase(strategy.name), :type => type, :message => message
    redirect_to '/auth'
  end # oauth_failure


  # logout. id is all or login provider
  def destroy
    if User.dummy_users?(@users)
      save_flash_key '.already_logged_off'
      redirect_to :action => :index
      return
    end
    provider = params[:id].to_s
    if provider != "all" and !valid_provider?(provider)
      logger.debug2 "1: unknown provider #{provider}"
      save_flash_key '.unknown_provider'
      redirect_to :action => :index
      return
    end
    if provider == 'all'
      provider = @users.first.provider if @users.size == 1 # redirect to this provider after logout
      logout()
    else
      logout(provider)
    end
    # redirect to api or redirect to auth/index page
    if !@users.first.dummy_user?
      # user logged in with other login provider(s)
      save_flash_key '.logged_off', :appname => APP_NAME, :apiname => provider_downcase(provider)
      if params[:return_to]
        # logout from users/edit page. return to users/index?friends=me
        redirect_to params[:return_to]
      else
        redirect_to :action => :index
      end
      return
    end
    if provider == 'all' or !(api_url = API_URL[provider])
      redirect_to :action => :index
    elsif
      redirect_to api_url
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

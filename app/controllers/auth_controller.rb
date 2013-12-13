class AuthController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => [:check] # no crsf token when facebook starts the App with post /fb
  after_filter :allow_iframe

  def index
    @providers = OmniAuth::Builder.providers
    # find logged in providers - userid and token
    user_ids = session[:user_ids] || []
    tokens = session[:tokens] || {}
    @logged_in_providers = user_ids.collect { |user_id| user_id.split('/').last }.find_all { |provider| tokens[provider].to_s != "" }
  end

  # omniauth callback on success
  def create
    @auth_hash = auth_hash
    puts "ENV = #{ENV}"
    puts "auth_hash = #{auth_hash}"
    user = User.find_create_from_omniauth_hash(auth_hash)
    if user.class == User
      # login ok - insert user_id and token in session
      provider = auth_hash.get_provider
      user_ids = session[:user_ids] || []
      user_ids.delete_if { |user_id| user_id.split('/').last == provider }
      user_ids << user.user_id
      tokens = session[:tokens] || {}
      tokens[provider] = auth_hash.get_token
      session[:user_ids] = user_ids
      session[:tokens] = tokens
      # add tasks to be ajax processed after login
      # todo: add helper add_ajax_task
      image = auth_hash.get_image
      post_login_task_provider = "post_login_#{provider}" # private method in UtilController
      add_ajax_task "User.update_timezone('#{user.user_id}', params[:timezone])" # timezone from client/javascript
      add_ajax_task "User.download_profile_image('#{user.user_id}', '#{image}')"
      if UtilController.new.private_methods.index(post_login_task_provider.to_sym)
        add_ajax_task post_login_task_provider
      else
        puts "Warning. No post login task was found for #{provider}. No #{provider} friend information will be downloaded"
      end
      # currencies for logged in users must be identical
      if user_ids.length > 1
        currencies = User.where('user_id in (?)', user_ids).collect { |user2| user2.currency }.uniq
        add_ajax_task 'post_login_fix_currency' if currencies.length > 1
      end
    else
      # login failed
      key, options = user
      begin
        flash[:notice] = t key, options
      rescue Exception => e
        puts "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        flash[:notice] = t '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
      end
    end
    redirect_to '/auth'
  end # create

  # omniauth callback on failure
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


  # alias for /
  # check any parameters and redirect to relevant method
  # 1) empty request - redirect to gifts/index (logged in user) or auth/index (not logged in user)
  def check
    puts "params.size = #{params.size}"
    puts "params.keys = #{params.keys.join(', ')}"
    signature = params.keys
    signature.delete_if { |key| %w(controller action).index(key) or params[key].to_s == ""}
    signature.sort!
    puts "signature = #{signature.join(', ')}"

    if signature.size == 0
      # 1) - empty request - redirect to gifts/index (logged in user) or auth/index (not logged in user)
      if @users.size == 0
        redirect_to :controller => :auth
      else
        redirect_to :controller => :gifts
      end
      return
    end

    if signature == %w(fb_locale signed_request)
      # 2) - login from facebook - FB_APP_URL

    end


    raise "not implemented"
  end

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

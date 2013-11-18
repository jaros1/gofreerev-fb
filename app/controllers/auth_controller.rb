class AuthController < ApplicationController

  def index
    @providers = OmniAuth::Builder.providers
    # find logged in providers - userid and token
    user_ids = session[:user_ids] || []
    tokens = session[:tokens] || {}
    @logged_in_providers = user_ids.collect { |user_id| user_id.split('/').last }.find_all { |provider| tokens[provider].to_s != "" }
  end

  def create
    @auth_hash = auth_hash
    user = User.find_or_create_from_auth_hash(auth_hash)
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
      image = auth_hash.get_image
      AjaxTask.add_task(session[:session_id], "User.update_timezone('#{user.user_id}', params[:timezone])") # timezone from client/javascript
      AjaxTask.add_task(session[:session_id], "User.download_profile_image('#{user.user_id}', '#{image}')")
      # todo: add provider tasks (get permissions, friend lists)
    else
      # login failed
      key, options = user
      begin
        flash[:nootice] = t key, options
      rescue Exception => e
        puts "invalid response from User.find_or_create_from_auth_hash. Must be nil or a valid input to translate. Response: #{user}"
        flash[:notice] = t '.find_or_create_from_auth_hash', :response => user, :exception => e.message.to_s
      end
    end
    redirect_to '/auth'
  end # create

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

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

end

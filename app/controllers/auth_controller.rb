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
      # add tasks to be ajax processed after login - see util.do_ajax_tasks
      session[:ajax_tasks] = [] unless session[:ajax_tasks]
      session[:ajax_tasks] << "User.update_timezone('#{user.user_id}', params[:timezone])" # timezone from client/javascript
      image = auth_hash.get_image
      session[:ajax_tasks] << "User.download_profile_image('#{user.user_id}', '#{image}')" if image.to_s =~ /^https?\:\/\//
      redirect_to '/auth'
      return
    end
    # login not ok
    key, options = user
    puts "login_error: #{my_t(key, options)}"
  end # create

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

end

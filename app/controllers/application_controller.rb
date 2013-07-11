class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Facebook API information is defined as OS environment variable
  private
  def api_id
    ENV['GOFREEREV_FB_APP_ID']
  end
  def api_secret
    ENV['GOFREEREV_FB_APP_SECRET']
  end

  # render to language specific pages.
  # viewname=create, session[:language] = da => call create-da.html.erb if the page exists
  private
  def render_with_language(viewname)
    language = session[:language]
    puts "render_with_language: language = #{language}"
    viewname2 = "#{viewname}_#{language}"
    filename = Rails.root.join('app', 'views', controller_name, "#{viewname2}.html.erb").to_s
    viewname2 = viewname unless File.exists?(filename)
    render :action => viewname2
  end # render_with_language

  # to prevent Cross-site Request Forgery
  private
  def generate_random_string (lng)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(lng) { |i| newpass << chars[rand(chars.size-1)] }
    newpass
  end # generate_random_string

  private
  def debug_session (msg)
    [:oauth, :language, :country, :state, :access_token, :user_id].each do |name|
      puts "#{msg}: session[:#{name}] = #{session[name]}"
    end
  end


end # ApplicationController

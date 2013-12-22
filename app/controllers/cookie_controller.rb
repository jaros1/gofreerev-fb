class CookieController < ApplicationController

  session :off # session not used - all cookies will be deleted

  before_action :set_locale
  skip_filter :get_timezone
  layout 'no_cookies_layout'

  # cookie note cancel method - cookies has been removed - display
  def decline_cookies
    #cookies.each do |name, value|
    #  puts "delete #{name} cookie"
    #  cookies.delete(name)
    #end
    #cookies.delete('_gofreerev-fb_session')
  end

  private
  def set_locale
    params[:locale] = nil if params.has_key?(:locale) and request.xhr?
    I18n.locale = params[:locale] if filter_locale(params[:locale])
  end

  private
  def fetch_user
    @user = User.find_by_user_id('gofreerev/gofreerev')
    @users = [ @user ]
  end

  # don't use session and don't use cookies in this controller
  # some rails gems writes to session or cookies
  # this should prevent rails from creating new cookies in this controller
  private
  def session
    {}
  end
  alias_method :old_cookies, :cookies
  def cookies
    old_cookies.each do |name, value|
      old_cookies.delete(name)
    end
    old_cookies.delete('_gofreerev-fb_session')
    {}
  end

end

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

  # language specific pages.
  private
  def render_with_language(viewname, language)
    viewname2 = "#{viewname}-#{language}"
    filename = Rails.root.join('app', 'views', controller_name, "#{viewname2}.html.erb").to_s
    viewname2 = viewname unless File.exists?(filename)
    render :action => viewname2
  end # render_with_language

end

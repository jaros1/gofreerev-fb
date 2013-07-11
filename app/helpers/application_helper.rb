module ApplicationHelper

  def link_to_facebook
    link_to "facebook", "javascript: {top.location.href='http://www.facebook.com/'}"
  end
  def link_to_app_on_facebook
    link_to APP_NAME, "javascript: {top.location.href='" + FB_APP_URL + "'}"
  end
  def link_to_google_plus
    link_to "google+", "https://plus.google.com/"
  end

  def link_to_cvs
    link_to CVS_NAME, CVS_URL, { :target => "_blank" }
  end
  def link_to_charles_eisenstein
    link_to "Charles Eisenstein", "http://charleseisenstein.net/", { :target => "_blank" }
  end
  def link_to_sacred_economics
    link_to "Sacred Economics", "http://sacred-economics.com/", { :target => "_blank" }
  end
  def render_page_footer
    language = session[:language]
    puts "render_page_footer: language = #{language}"
    language = nil if language == 'en'
    return render("layouts/page_footer") unless language # english
    partialname = "page_footer_#{language}"
    filename = Rails.root.join('app', 'views', 'layouts', "_#{partialname}.html.erb").to_s
    puts "render_page_footer: filename = #{filename}"
    partialname = 'page_footer' unless File.exists?(filename)
    return render "layouts/#{partialname}"
  end # render_page_footer

end # ApplicationHelper

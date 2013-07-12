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

  # application layout helpers
  def currencies
    Money::Currency.table.collect { |a| [  "#{a[1][:iso_code]} #{a[1][:name]}".first(25), a[1][:iso_code] ] }
  end
  def render_application_partial (partialname)
    language = session[:language]
    puts "render_#{partialname}: language = #{language}"
    language = nil if language == 'en'
    return render("layouts/#{partialname}") unless language # english
    partialname2 = "#{partialname}_#{language}"
    filename = Rails.root.join('app', 'views', 'layouts', "_#{partialname2}.html.erb").to_s
    puts "render_#{partialname}: filename = #{filename}"
    partialname2 = partialname unless File.exists?(filename)
    return render "layouts/#{partialname2}"
  end # render_application_partial
  def render_page_header
    render_application_partial('page_header')
  end # render_page_header
  def render_page_footer
    render_application_partial('page_footer')
  end # render_page_footer

end # ApplicationHelper

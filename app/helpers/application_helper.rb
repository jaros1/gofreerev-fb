module ApplicationHelper

  # debug
  def dump_session_variables
    puts "@user = #{@user}"
    puts "session.to_hash = #{session.to_hash}"
  end

  # link_to helpers

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

  # partial helpers
  def render_partial_with_language (folder, partialname)
    language = session[:language]
    puts "render_partial_with_language: folder = #{folder}, partialname = #{partialname}, language = #{language}"
    language = nil if language == 'en'
    if !language
      # no language or english
      return (render(:partial => "#{folder}/#{partialname}"))
    end
    # check for language specific partial
    partialname2 = "#{partialname}_#{language}"
    filename = Rails.root.join('app', 'views', folder, "_#{partialname2}.html.erb").to_s
    puts "render_partial_with_language: filename = #{filename}"
    partialname2 = partialname unless File.exists?(filename)
    render :partial => "#{folder}/#{partialname2}"
  end # render_application_partial

  # application layout helpers
  def currencies
    Money::Currency.table.collect { |a| [  "#{a[1][:iso_code]} #{a[1][:name]}".first(25), a[1][:iso_code] ] }
  end
  def render_page_header
    render_partial_with_language('layouts', 'page_header')
  end # render_page_header
  def render_page_footer
    render_partial_with_language('layouts', 'page_footer')
  end # render_page_footer

  # output_text takes a String, an Array or an Hash as input
  # String - outout text string
  # Array - output text array with <br /> between each line
  # Hash - find usertype in hash and outputs String or Array
  # the last option can be used to implement different texts for FB users, GP users and other type of users
  def output_text (text_object)
    render :partial => 'layouts/output_text', :locals => { :text_object => text_object}
  end

end # ApplicationHelper

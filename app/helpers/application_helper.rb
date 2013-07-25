# encoding: utf-8
module ApplicationHelper

  # debug
  def dump_session_variables
    puts "@user = #{@user}"
    puts "session.to_hash = #{session.to_hash}"
  end

  # link_to helpers

  def link_to_facebook
    link_to 'facebook', 'javascript: {top.location.href="http://www.facebook.com/"}'
  end
  def link_to_app_on_facebook
    link_to APP_NAME, "javascript: {top.location.href='" + FB_APP_URL + "'}"
  end
  def link_to_google_plus
    link_to 'google+', 'https://plus.google.com/'
  end

  def link_to_cvs
    link_to CVS_NAME, CVS_URL, { :target => '_blank'}
  end
  def link_to_charles_eisenstein
    link_to 'Charles Eisenstein', 'http://charleseisenstein.net/', { :target => '_blank' }
  end
  def link_to_sacred_economics
    link_to 'Sacred Economics', 'http://sacred-economics.com/', { :target => '_blank' }
  end

  # partial helpers
  def render_partial_with_language (folder, partialname)
    language = session[:language]
    puts "render_partial_with_language: folder = #{folder}, partialname = #{partialname}, language = #{language}"
    language = nil if language == 'en'
    unless language
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
  def header_log_out_link_url
    fb_path(@user.id)
  end
  def render_page_footer
    render_partial_with_language('layouts', 'page_footer')
  end # render_page_footer

  # text translation: http://guides.rubyonrails.org/i18n.html
  # this extension adds usertype (fb, gp etc) first in scope.
  # first lookup with usertype first in scope
  # second lookup without usertype in scope only if text not found in first lookup with usertype in scope.
  def my_translate (key, options = {})
    # puts "my_tranlate"
    scope = options[:scope]
    if scope
      scope = scope.to_s if scope.class.name == 'Symbol'
      scope = scope.split('.') if scope.class.name == 'String'
      return translate(key, options) unless scope.class.name == 'Array'
      usertype_in_scope = scope.find { |s| s.to_s.downcase == session[:usertype] }
      options[:scope] = scope = [ session[:usertype] ] + scope unless usertype_in_scope
    else
      options[:scope] = scope = [ session[:usertype] ]
    end
    # first lookup with usertype in scope
    options[:raise] = I18n::MissingTranslationData
    # puts "my_translate: first lookup: key = #{key}, scope = " + scope.join(',')
    begin
      translate(key, options)
    rescue I18n::MissingTranslationData
      # puts "I18n::MissingTranslationData. e = #{e.to_s}"
      # second lookup without usertype in scope
      options.delete(:raise)
      options[:scope] = scope.delete_if { |s| s.to_s.downcase == session[:usertype] }
      # repeat translate without usertype in scope
      # puts "my_translate: second lookup: key = #{key}, scope = " + scope.join(',')
      return translate(key, options)
    end
  end
  alias :my_t :my_translate

  # format prices - user currency is used for default seperators
  def format_price (price)
    return nil unless price
    puts "format_price: @user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"
    number_with_precision(price, :precision => 2, :separator => @user_currency_separator, :delimiter => @user_currency_delimiter)
  end

  def format_user_balance (balance)
    return nil unless balance
    return nil unless balance.size > 0
    return format_price(balance[BALANCE_KEY]) if balance.size == 0
    if balance.size == 2
      other_value = balance.find { |name, value| name != BALANCE_KEY }
      return format_price(balance[BALANCE_KEY]) if balance[BALANCE_KEY] == other_value
    end
    format_price(balance[BALANCE_KEY]) + ' (' + balance.find_all { |name, value| name != BALANCE_KEY }.collect { |name,value| format_price(value) + ' ' + name }.join(', ') + ')'
  end

  # todo: add date format
  def format_date (date)
    date
  end

  # todo: add time format. use timezone from user
  def format_time (time)
    time
  end

  # english description for social dividend in database for gifttype = S (social dividend)
  # use this translate for description in other languages for social dividend
  def format_gift_description (gift)

    # problem with incompatible character encodings: UTF-8 and ASCII-8BIT
    # temporary workaround with .force_encoding('UTF-8')
    # do not known were the problem is
    return gift.description.force_encoding('UTF-8') if gift.gifttype == 'G'

    # format description with social dividend with translate
    if gift.social_dividend_from
      # format with start and end dates for period
      my_t '.social_dividend_description_1', :giver => gift.giver.short_user_name, :receiver => gift.receiver.short_user_name,
                                             :price => format_price(gift.price), :currency => gift.currency,
                                             :from => format_date(gift.social_dividend_from), :to => format_date(gift.received_at)
    else
      # format with only end date for period.
      # Used for first social dividend calculations for a new user
      my_t '.social_dividend_description_2', :giver => gift.giver.short_user_name, :receiver => gift.receiver.short_user_name,
                                             :price => format_price(gift.price), :currency => gift.currency,
                                             :to => format_date(gift.received_at)
    end
  end # format_gift_description


end # ApplicationHelper

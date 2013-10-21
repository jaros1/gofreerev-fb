require File.join(Rails.root, "lib/gofreerev_extensions.rb")

# encoding: utf-8
module ApplicationHelper

  include GofreerevExtensions

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


  # format prices - user currency is used for default seperators
  def format_price (price)
    return nil unless price
    # puts "format_price: @user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"
    number_with_precision(price, :precision => 2, :separator => @user_currency_separator, :delimiter => @user_currency_delimiter)
  end

  def format_user_balance (user, login_user)
    return nil unless user and login_user
    balance = user.balance
    return nil unless user.balance
    return nil unless balance.size > 1
    from_amount = balance[BALANCE_KEY]
    from_currency = user.currency
    to_currency = login_user.currency
    if balance.size == 2
      # short format. only one currency in balance hash. Return this without any conversion if login user currency
      return format_price(balance[to_currency]) if balance.has_key?(to_currency)
      return format_price(from_amount) if user.currency == login_user.currency
    end
    # exchange from_amount
    if from_currency == to_currency
      # puts "format_user_balance: no exchange: to_amount = from_amount = #{from_amount}"
      to_amount = from_amount
      to_currency = ''
    elsif (to_amount = ExchangeRate.exchange(from_amount, from_currency, to_currency))
      # puts "format_user_balance: exchange ok: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      to_currency = ''
    else
      # exchange rate was not ready - show original user balance with currency - exchange rate should be ready in next request
      # puts "format_user_balance: exchange rate not ready: from_amount = #{from_amount}, from_currency = #{from_currency}"
      to_amount = from_amount
      to_currency = ' ' + from_currency
    end
    # format: -0,90 (-47,77 DKK, 49,76 SEK, -0,08 USD) - to_currency will normally be blank
    format_price(to_amount) + to_currency + ' (' + balance.find_all { |name, value| name != BALANCE_KEY }.collect { |name,value| format_price(value) + ' ' + name }.join(', ') + ')'
  end # format_user_balance

  # todo: add date format
  def format_date (date)
    l date, :format => :short
  end

  # todo: add time format. use timezone from user
  def format_time (time)
    l time, :format => :short
  end

  # todo: config sanitize
  def my_sanitize (text)
    sanitize(text.to_s).gsub(/\n/, '<br/>').html_safe
  end # my_sanitize

  def my_sanitize_hash (hash)
    hash.each do |name, value|
      hash[name] = my_sanitize (value.to_s.force_encoding('utf-8'))
    end
  end # my_sanitize_hash

  # english description for social dividend in database for gifttype = S (social dividend)
  # use this translate for description in other languages for social dividend
  def format_gift_description (gift)

    return my_sanitize gift.description if gift.gifttype == 'G'

    # format description with social dividend with translate
    if gift.social_dividend_from
      # format with start and end dates for period
      my_t '.social_dividend_description_1', :giver => gift.giver.short_user_name, :receiver => gift.receiver.short_user_name,
                                             :price => format_price(gift.price), :currency => gift.currency,
                                             :from => format_date(gift.social_dividend_from), :to => format_date(gift.received_at).html_safe
    else
      # format with only end date for period.
      # Used for first social dividend calculations for a new user
      my_t '.social_dividend_description_2', :giver => gift.giver.short_user_name, :receiver => gift.receiver.short_user_name,
                                             :price => format_price(gift.price), :currency => gift.currency,
                                             :to => format_date(gift.received_at).html_safe
    end
  end # format_gift_description

  def format_direction (gift)
    if !gift.user_id_receiver
      my_t '.direction_giver', :username => gift.giver.friend?(@user) ? gift.giver.short_user_name : giver.user_name
    elsif !gift.user_id_giver
      my_t '.direction_receiver', :username => gift.receiver.friend?(@user) ? gift.receiver.short_user_name : receiver.user_name
    else
      my_t '.direction_giver_and_receiver', :givername => gift.giver.short_user_name, :receivername => gift.receiver.short_user_name
    end
  end # format_direction

  def title
    return APP_NAME unless @user
    n = @user.inbox_new_notifications
    return APP_NAME unless n > 0
    "(#{n}) #{APP_NAME}"
  end # title

  def format_gift_param (gift)
    optional_price = gift.price ? "#{my_t('.optional_price', :price => format_price(gift.price))} #{gift.currency}" : nil
    { :date           => format_date(gift.received_at || gift.created_at),
      :direction      => format_direction(gift),
      :optional_price => optional_price,
      :text           => format_gift_description(gift)
    }
  end # format_gift_param

  def invite_friends_url
    unless @user
      puts 'invite_friends_url: @user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - friend request url
        title = my_t 'shared.invite_friends.invite_friends_message_title', :appname => APP_NAME
        message = my_t 'shared.invite_friends.invite_friends_message_body'
        # no koala gem method for generation a invite friends url
        url = "https://#{Koala.config.dialog_host}/dialog/apprequests" +
            "?app_id=#{api_id}" +
            "&redirect_uri=#{CGI.escape(SITE_URL + @request_fullpath)}" +
            "&message=#{CGI.escape(message.to_str)}" +
            "&title=#{CGI.escape(title.to_str)}" +
            "&filters=" + CGI.escape("['app_non_users']")
        # puts "friend request url: url = #{url}"
        return url
      else
        ''
    end # case
  end # invite_friends_url

  def invite_friends_link
    # todo: different url for each API (FB, GP, LI etc)
    link_to my_t('.invite_friends_link_text', :app_url => FB_APP_URL), invite_friends_url
  end

end # ApplicationHelper

# encoding: utf-8
module ApplicationHelper

  # debug
  def dump_session_variables
    puts2log  "@user = #{@user}"
    puts2log  "session.to_hash = #{session.to_hash}"
  end

  # link_to helpers - used in page footer
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
    puts2log  "folder = #{folder}, partialname = #{partialname}, language = #{language}"
    language = nil if language == BASE_LANGUAGE
    unless language
      # no language or english
      return (render(:partial => "#{folder}/#{partialname}"))
    end
    # check for language specific partial
    partialname2 = "#{partialname}_#{language}"
    filename = Rails.root.join('app', 'views', folder, "_#{partialname2}.html.erb").to_s
    puts2log  "filename = #{filename}"
    partialname2 = partialname unless File.exists?(filename)
    render :partial => "#{folder}/#{partialname2}"
  end # render_application_partial

  # application layout helpers
  # active currencies to by used in page header LOV
  def currencies
    active_currencies = ExchangeRate.active_currencies
    Money::Currency.table.find_all do |a|
      !active_currencies or active_currencies.size == 0 or active_currencies.index(a[1][:iso_code]) or a[1][:iso_code] == BASE_CURRENCY
    end.collect do |a|
      [ "#{a[1][:iso_code]} #{a[1][:name]}".first(25), a[1][:iso_code] ]
    end
  end
  def selected_currency
    return [] unless @user
    a = Money::Currency.table.find { |a| a[1][:iso_code] == @user.currency }
    return [] unless a
    [ [ "#{a[1][:iso_code]} #{a[1][:name]}".first(25), a[1][:iso_code] ]]
  end

  def header_log_in_link_url
    url_for :controller => :auth, :action => :index
  end
  def header_log_out_link_url
    url_for :controller => :auth, :action => :destroy, :id => "all"
  end
  def render_page_footer
    render_partial_with_language('layouts', 'page_footer')
  end # render_page_footer


  # format prices - user currency is used for default seperators
  def format_price (price)
    return nil unless price
    # puts2log  "@user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"
    number_with_precision(price, :precision => 2, :separator => @user_currency_separator, :delimiter => @user_currency_delimiter)
  end

  def format_user_balance (user, login_users)
    # puts2log  "user = #{user.user_id}, login_users = " + login_users.collect { |user| user.user_id }.join(', ')
    return nil unless user.class == User and login_users.class == Array
    return nil if login_users.length == 0
    if user.user_combination
      # combined user accounts - sum balance for combined user accounts
      raise "todo: sum balance for combined user accounts not implemented"
    else
      # standalone user account
      balance = user.balance
    end
    return nil unless balance
    return nil unless balance.size > 1
    from_amount = balance[BALANCE_KEY]
    from_currency = 'USD'
    to_currencies = login_users.collect { |login_user| login_user.currency }.uniq
    if to_currencies.length > 1
      puts2log  "todo: error, login procedure should ensure one and only one currency for logged in users"
    end
    to_currency = to_currencies.first
    puts2log  "to_currency = #{to_currency}"
    if balance.size == 2 and user.currency == login_users.first.currency
      # short format. only one currency in balance hash. Return this without any conversion if login user currency
      return format_price(from_amount) if user.currency == login_users.first.currency
    end # æøå
    # exchange from_amount
    if from_currency == to_currency
      # puts2log  "no exchange: to_amount = from_amount = #{from_amount}"
      to_amount = from_amount
      to_currency = ''
    elsif (to_amount = ExchangeRate.exchange(from_amount, from_currency, to_currency))
      # puts2log  "exchange ok: from_amount = #{from_amount}, from_currency = #{from_currency}, to_amount = #{to_amount}, to_currency = #{to_currency}"
      to_currency = ''
    else
      # exchange rate was not ready - show original user balance with currency - exchange rate should be ready in next request
      # puts2log  "exchange rate not ready: from_amount = #{from_amount}, from_currency = #{from_currency}"
      to_amount = from_amount
      to_currency = ' ' + from_currency
    end
    # format: -0,90 (-47,77 DKK, 49,76 SEK, -0,08 USD) - to_currency will normally be blank
    format_price(to_amount) + to_currency + ' (' + balance.find_all { |name, value| name != BALANCE_KEY }.collect { |name,value| format_price(value) + ' ' + name }.join(', ') + ')'
  end # format_user_balance

  # todo: add date format
  def format_date (date)
    return nil unless date
    l date.to_date, :format => :short
  end

  # todo: add time format.
  def format_time (time)
    l time, :format => :short
  end

  # todo: config sanitize
  def my_sanitize (text)
    sanitize(text.to_s).gsub(/\n/, '<br/>').html_safe
  end # my_sanitize


  # todo: translate value for key provider.
  def my_sanitize_hash (hash)
    hash.each do |name, value|
      if name.to_s == 'provider'
        hash[name] = provider_downcase(value)
      else
        hash[name] = my_sanitize (value.to_s.force_encoding('utf-8'))
      end
    end
  end # my_sanitize_hash


  #def format_direction (api_gift)
  #  gift = api_gift.gift
  #  case gift.direction
  #    when 'giver'
  #      t 'gifts.index.direction_giver', :username => api_gift.giver.short_or_full_user_name(@user)
  #    when 'receiver'
  #      t 'gifts.index.direction_receiver', :username => api_gift.receiver.short_or_full_user_name(@user)
  #    when 'both'
  #      t 'gifts.index.direction_giver_and_receiver', :givername => api_gift.giver.short_user_name, :receivername => api_gift.receiver.short_user_name
  #    else
  #      raise "invalid direction for gift #{gift.id}"
  #  end # case
  #end # format_direction

  def inbox_new_notifications
    User.inbox_new_notifications(@users)
  end

  def title
    n = inbox_new_notifications()
    return APP_NAME unless n
    "(#{n}) #{APP_NAME}"
  end # title


  def format_gift_param (api_gift)
    gift = api_gift.gift
    optional_price = gift.price ? "#{t('.optional_price', :price => format_price(gift.price))} #{gift.currency}" : nil
    { :date           => format_date(gift.received_at || gift.created_at),
      :direction      => format_direction_with_user(api_gift),
      :optional_price => optional_price,
      :text           =>  my_sanitize(gift.description)
    }
  end # format_gift_param

  # todo: generalize
  def invite_friends_url
    unless @user
      puts2log  '@user was not found'
      return ''
    end
    case
      when @user.facebook?
        # url - friend request url
        title = t 'shared.invite_friends.invite_friends_message_title', :appname => APP_NAME
        message = t 'shared.invite_friends.invite_friends_message_body'
        # no koala gem method for generation a invite friends url
        url = "https://#{Koala.config.dialog_host}/dialog/apprequests" +
            "?app_id=#{API_ID[@user.provider]}" +
            "&redirect_uri=#{CGI.escape(SITE_URL + @request_fullpath)}" +
            "&message=#{CGI.escape(message.to_str)}" +
            "&title=#{CGI.escape(title.to_str)}" +
            "&filters=" + CGI.escape("['app_non_users']")
        # puts2log  "url = #{url}"
        return url
      else
        ''
    end # case
  end # invite_friends_url

  def invite_friends_link1
    # todo: different url for each API (FB, GP, LI etc)
    link_to t('shared.invite_friends.invite_friends_link_text1', :app_url => FACEBOOK_APP_URL), invite_friends_url
  end

  def ajax_tasks?
    Task.where("session_id = ?", session[:session_id]).count > 0
  end

  def link_to_logout
    if @request_fullpath.to_s =~ /\/cookie\//
      # problem with log out link and InvalidAuthenticityToken error (no session in cookie controller). redirect to login/logout page
      link_to t('.header_log_out_link_text'), auth_path
    else
      link_to t('.header_log_out_link_text'), header_log_out_link_url, :method => 'delete'
    end
  end

end # ApplicationHelper

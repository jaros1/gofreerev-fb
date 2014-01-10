# encoding: utf-8
require 'money/bank/google_currency'

#noinspection RubyResolve
class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :request_url_for_header
  before_filter :fetch_user
  before_action :set_locale
  before_action :get_timezone

  # render to language specific pages.
  # viewname=create, session[:language] = da => call create-da.html.erb if the page exists
  private
  def render_with_language(viewname)
    language = session[:language]
    # language = BASE_LANGUAGE # todo: remove this line
    logger.debug2  "language = #{language}"
    if !language or language == BASE_LANGUAGE
      render :action => viewname
      return
    end
    viewname2 = "#{viewname}_#{language}"
    filename = Rails.root.join('app', 'views', controller_name, "#{viewname2}.html.erb").to_s
    logger.debug2  "filename = #{filename}"
    viewname2 = viewname unless File.exists?(filename)
    render :action => viewname2
  end # render_with_language

  private
  def debug_session (msg)
    [:oauth, :language, :country, :state, :access_token, :user_id].each do |name|
      logger.debug2  "#{msg}: session[:#{name}] = #{session[name]}"
    end
  end

  private
  # used in page header for currency change
  def request_url_for_header
    @request_fullpath = request.fullpath
  end


  private
  def add_dummy_user
    if @users.size == 0
      @user = User.find_or_create_dummy_user('gofreerev')
      @users << @user
    end
  end


  # fetch user info. Used in page heading etc
  private
  def fetch_user
    # language support
    # logger.debug2  "start. sessionid = #{request.session_options[:id]}"
    logger.debug2  "I18n.locale = #{I18n.locale}"

    # cookie note in page header for the first n seconds for a new session
    # eu cookie law - also called Directive on Privacy and Electronic Communications
    # accepted cookie is a permanent cookie set if user accepts cookies
    if SHOW_COOKIE_NOTE and SHOW_COOKIE_NOTE > 0 and cookies[:cookies] != 'accepted'
      session[:created] = Time.new unless session[:created]
      cookie_note = SHOW_COOKIE_NOTE - (Time.new - session[:created])
      @cookie_note = cookie_note if cookie_note >= 0.5
    end

    # fetch user(s)
    if login_user_ids.length > 0
      @users = User.where("user_id in (?)", login_user_ids).includes(:friends).shuffle
    else
      @users = []
    end

    # check for deleted users - user(s) deleted in an other session/browser
    if login_user_ids.length != @users.length
      login_user_ids = @users.collect { |user| user.user_id }
      tokens = session[:tokens] || {}
      new_tokens = {}
      @users.each { |user| new_tokens[user.provider] = tokens[user.provider] }
      session[:user_ids] = login_user_ids
      session[:tokens] = new_tokens
    end

    # add sort_by_provider method instance method to @users array.
    # used in a few views (invite users, auth/index)
    # todo: should use provider_downcase method, but application controller methods are not available in Array class
    # todo: move provider_downcase to constant?
    @users.define_singleton_method :sort_by_provider do
      self.sort do |a, b|
        (API_CAMELIZE_NAME[a.provider] || a.provider) <=> (API_CAMELIZE_NAME[b.provider] || b.provider)
      end
    end

    # shortcut for @users.first. Random user is selected for a user with multiple provider logins
    # todo: remove @user - should only use @users array
    @user = @users.first

    # debugging
    if @users.length == 0
      logger.debug2  "found none logged in users"
    else
      @users.each do |user|
        logger.debug2  "user_id = #{user.user_id}, user_name = #{user.user_name}, currency = #{user.currency}"
      end
    end

    # check currencies. all logged in users must use same currency
    currencies = @users.collect { |user| user.currency }.uniq
    logger.debug2  "more when one currency found for logged in users: #{}" if currencies.length > 1

    # add some instance variables
    if @user
      Money.default_currency = Money::Currency.new(@user.currency)
      # todo: set decimal mark and thousands separator from language - not from currency
      @user_currency_separator = Money::Currency.table[@user.currency.downcase.to_sym][:decimal_mark]
      @user_currency_delimiter = Money::Currency.table[@user.currency.downcase.to_sym][:thousands_separator]
    end
    logger.debug2  "@user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"

    # add dummy user for page header
    add_dummy_user if @users.size == 0

    # get new exchange rates? add to task queue
    add_task 'ExchangeRate.fetch_exchange_rates', 10 if logged_in? and ExchangeRate.fetch_exchange_rates?
  end # fetch_user


  # 1. priority is locale from url - 2. priority is locale from session - 3. priority is default locale (en)
  # locale is also saved in session for language support in api provider callbacks
  private
  def set_locale
    params[:locale] = nil if params.has_key?(:locale) and request.xhr?
    session[:language] = params[:locale] if filter_locale(params[:locale])
    I18n.locale = filter_locale(params[:locale]) || filter_locale(session[:language]) || filter_locale(I18n.default_locale) || 'en'
    logger.debug2  "I18n.locale = #{I18n.locale}. params[:locale] = #{params[:locale]}, session[:language] = #{session[:language]}, "
  end

  private
  def default_url_options(options={})
    # logger.debug2  "options: #{options}."
    # logger.debug2  "I18n.locale = #{I18n.locale} (#{I18n.locale.class})"
    # logger.debug2  "I18n.default_locale = #{I18n.default_locale} (#{I18n.default_locale.class})"
    # logger.debug2  "controller = #{params[:controller]}"
    { locale: I18n.locale }
  end

  # get any pictures with invalid picture urls
  # used in gifts/index page, todo:
  # that is gifts where picture url are marked as invalid and where url lookup in /util/missing_api_picture_urls failed
  # most possible explanation is that the pictures has been deleted in api
  # but is could also be a api permission problem (gofreerev user is not allowed to see picture in api)
  # check picture url again with owner permission
  # the existing /util/missing_api_picture_urls is used to check invalid picture urls
  # done in a client js call after the page has been rendered to the user
  # see last lines in /gifts/index page
  # see onLoad tag on img
  # see js functions imgonload and report_missing_api_picture_urls
  private
  def get_missing_api_picture_urls
    logger.debug2 "login_user_ids = #{login_user_ids}"
    return 'missing_api_picture_urls = [] ;' unless login_user_ids.size > 0
    # all api gifts with @users as giver or receiver
    api_gifts = ApiGift.where("(user_id_giver in (?) or user_id_receiver in (?)) and " +
                                  "api_picture_url_on_error_at is not null and " +
                                  "(deleted_at_api is null or deleted_at_api = 'N')",
                       login_user_ids, login_user_ids).includes(:gift)
    # remove api gift where @users are not creator of gift
    api_gifts.delete_if do |api_gift|
      user_id_created_by = api_gift.gift.created_by == 'giver' ? api_gift.user_id_giver : api_gift.user_id_receiver
      !login_user_ids.index(user_id_created_by)
    end # delete_if
    if api_gifts.size == 0
      'missing_api_picture_urls = [] ;'
    else
      'missing_api_picture_urls = [' + api_gifts.collect { |ag| ag.id }.join(', ') + '] ;'
    end
  end # get_missing_api_picture_urls

  # check get-more-rows ajax request for errors before fetching users or gifts
  # called in start of gifts/index, users/index and users/show and before calling get_next_set_of_rows
  # last_low_id must be correct - max one get-more-rows ajax request every GET_MORE_ROWS_INTERVAL seconds
  private
  def get_next_set_of_rows_error?(last_row_id)
    raise "get_next_set_of_rows: session[:last_row_id] was not found" unless session[:last_row_id]
    raise "get_next_set_of_rows: session[:last_row_at] was not found" unless session[:last_row_at]
    # max one get-more-rows request once every GET_MORE_ROWS_INTERVAL seconds
    new_last_row_at = Time.new.to_f
    dif = new_last_row_at - session[:last_row_at]
    if last_row_id != session[:last_row_id]
      # wrong last_row_id received in get-more-rows ajax request. Must be an error a javascript/ajax error
      msg = "problem with get-more-rows ajax request. expected #{session[:last_row_id]}. found #{last_row_id}."
      if debug_ajax?
        raise msg
      else
        logger.debug2  msg
      end
      # return dummy row with correct last_row_id to client x
      return true
    elsif dif < GET_MORE_ROWS_INTERVAL - 1
      # client should only send get-more-rows once every GET_MORE_ROWS_INTERVAL seconds. Must be an javascript/ajax error.
      # it should be client that waits between get-more-rows ajax requests - not server
      # todo: problem with GET_MORE_ROWS_INTERVAL delay in javascript and in rails.
      #       dif < GET_MORE_ROWS_INTERVAL gives too many "Max one get-more-rows ajax request" errors
      #       javascript code in /shared/show_more_rows partial. 3 seconds wait in JS and in rails should work
      msg = "Max one get-more-rows ajax request every #{GET_MORE_ROWS_INTERVAL} seconds. session[:last_row_at_debug] = #{session[:last_row_at_debug]}. Time.new = #{Time.new}. Wait for #{GET_MORE_ROWS_INTERVAL-dif} seconds"
      if debug_ajax?
        logger.debug2  msg
        logger.debug2  msg
        logger.debug2  msg
      else
        logger.debug2  msg
        sleep(GET_MORE_ROWS_INTERVAL-dif) # there mst be error in javascript wait between get-more-rows ajax requests
      end
      # return dummy row with correct last_row_id to client
      return true
    else
      # normal ajax response with next set of gifts or users
      return false
    end
  end # get_next_set_of_rows_error?

  # used in ajax expanding pages (gifts/index, users/index and users/show pages)
  private
  def get_next_set_of_rows (rows, last_row_id, no_rows=nil)
    logger.debug2  "last_row_id = #{last_row_id}"
    ajax_request = (last_row_id != nil)
    no_rows = ajax_request ? 10 : 1 unless no_rows # default - return 1 row in first http request - return 10 rows in ajax requests
    total_no_rows = rows.size
    if ajax_request
      # ajax request
      # check if last_row_id is valid - row could have been deleted between two requests
      # logger.debug2  "ajax request - check if last_row_id still is valid"
      from = rows.index { |u| u.last_row_id == last_row_id }
      if !from
        logger.debug2  "invalid last_row_id - or row is no longer in rows - ignore error and return first 10 rows"
        last_row_id = nil
      end
      last_row_id = nil unless from # invalid last_row_id - deleted row or changed permissions - ignore error and return first 10 rows
    end
    rows = rows[from+1..-1] if from # valid ajax request - ignore first from rows - already in client page
    if rows.size > no_rows
      rows = rows.first(no_rows)
      last_row_id = rows.last.last_row_id # return next 10 rows in next ajax request
    else
      last_row_id = nil # last row - no more ajax requests
    end
    logger.debug2  "returning next #{rows.size} of #{total_no_rows} rows . last_row_id = #{last_row_id}"
    # keep last_row_id and timestamp - checked in get_next_set_of_rows_error? before calling this method
    session[:last_row_id] = last_row_id # control - is checked in next ajax request
    session[:last_row_at] = Time.new.to_f
    session[:last_row_at_debug] = Time.new
    logger.debug2  "last_row_at_debug = #{session[:last_row_at_debug]}"
    session[:last_row_at] = GET_MORE_ROWS_INTERVAL.seconds.ago.to_f unless ajax_request # first http request at startup - ajax request for the next 10 rows in a split second
    [ rows, last_row_id]
  end # get_next_set_of_rows

  # Check price - allow decimal comma/point, max 2 decimals. Thousands separators not allowed
  # used in gifts and comments controller
  # should be identical to JS function csv_invalid_price (csv = client side validation)
  private
  def invalid_price? (price)
    price = price.to_s.strip
    return false if price == ""
    r = Regexp.new '^[0-9]*((\.|,)[0-9]{0,2})?$'
    return true if (!r.match(price) || (price == '.') || (price == ','))
    false
  end # invalid_price?

  # provider helpers

  # list of valid providers from /config/initializers/omniauth.rb
  private
  def valid_provider? (provider)
    User.valid_provider?(provider)
  end
  helper_method "valid_provider?"

  # provider name used in text (error messages, mouse over titles etc) - normal lowercase
  private
  def provider_downcase (provider)
    return provider if !valid_provider?(provider) # unknown provider or already translated
    API_DOWNCASE_NAME[provider] || provider
  end
  helper_method :provider_downcase

  # formal provider name - used in views
  private
  def provider_camelize (provider)
    return provider if !valid_provider?(provider) # unknown provider or already translated
    API_CAMELIZE_NAME[provider] || provider
  end
  helper_method :provider_camelize

  # redirect urls used in views and controllers
  private
  def provider_url (provider)
    return nil if !valid_provider?(provider) # unknown provider or already translated
    API_URL[provider]
  end
  helper_method :provider_url


  private
  def add_task (task, priority=5)
    Task.add_task(session[:session_id], task, priority)
  end

  private
  def debug_ajax?
    DEBUG_AJAX
  end
  helper_method "debug_ajax?"

  # helper methods to return ajax (error) messages
  private
  def format_ajax_response
    respond_to do |format|
      format.js {}
    end
    nil
  end
  private
  def add_error_and_format_ajax_resp (error)
    @errors << error
    format_ajax_response
  end

  private
  def logged_in?
    (login_user_ids.length > 0)
  end
  helper_method "logged_in?"

  private
  def login_required
    return true if logged_in?
    flash[:notice] = t 'gifts.index.not_logged_in_flash'
    redirect_to :controller => :auth, :action => :index
  end # login_required

  private
  def login (options)
    # get params
    provider = options[:provider]
    token = options[:token]
    uid = options[:uid]
    name = options[:name]
    image = options[:image]
    country = options[:country]
    language = options[:language]
    profile_url = options[:profile_url]
    # create/update user from information received from login provider
    # returns user (ok) or an array with translate key and options for error message
    user = User.find_or_create_user :provider => provider,
                                    :token => token,
                                    :uid => uid,
                                    :name => name,
                                    :image => image,
                                    :country => country,
                                    :language => language,
                                    :profile_url => profile_url
    return user unless user.class == User
    # user login ok
    # save user and access token - multiple login allows - one for each login provider
    login_user_ids = login_user_ids().clone
    login_user_ids.delete_if { |user_id2| user_id2.split('/').last == provider }
    login_user_ids << user.user_id
    tokens = session[:tokens] || {}
    tokens[provider] = token
    session[:user_ids] = login_user_ids
    session[:tokens] = tokens
    # save language for translate
    session[:language] = language if !filter_locale(session[:language]) and filter_locale(language)
    set_locale
    # check currency after new login - keep current currency
    @users = User.where('user_id in (?)', login_user_ids)
    if @users.collect { |user2| user2.currency }.uniq.length > 1
      old_user = @users.find { |user2| user2.user_id != user.user_id }
      user.currency = old_user.currency
      user.save!
    end
    # schedule post login tasks.

    if image.to_s != ""
      if image =~ /^http/ and !image.index("''") and !image.index('"')
        # todo: other characters to filter? for example characters with a special os function
        # facebook: profile picture from login is not used - profile picture from koala request in post_login_facebook is used
        add_task "User.update_profile_image('#{user.user_id}', '#{image}')", 5
      else
        logger.debug2 "invalid picture received from #{provider}. image = #{image}"
      end
    end
    post_login_task_provider = "post_login_#{provider}" # private method in UtilController
    if UtilController.new.private_methods.index(post_login_task_provider.to_sym)
      add_task post_login_task_provider, 5
    else
      logger.debug2  "Warning. No post login task was found for #{provider}. No #{provider} friend information will be downloaded"
    end
    # enable file upload button if new user can write on api wall
    add_task "disable_enable_file_upload", 5
    # refresh user(s) balance
    today = Date.parse(Sequence.get_last_exchange_rate_date)
    if !user.balance_at or user.balance_at != today
      add_task "recalculate_user_balance(#{user.id})", 5
    end
    # ok
    nil
  end # login

  def logout (provider=nil)
    if !provider
      session.delete(:user_ids)
      session.delete(:tokens)
      @users = []
      add_dummy_user
      return
    end
    login_user_ids = login_user_ids().clone
    login_user_ids.delete_if { |user_id| user_id.split('/').last == provider}
    tokens = session[:tokens]
    tokens.delete(provider)
    session[:user_ids] = login_user_ids
    session[:tokens] = tokens
    @users = User.where('user_id in (?)', login_user_ids)
    add_dummy_user if @users.size == 0
    # check if file upload button should be disabled - last user with write access to api wall logs out
    add_task "disable_enable_file_upload", 5
  end # logout





  # protection from Cross-site Request Forgery
  # state is set before calling login provider
  # state is checked when returning from login provider
  # used in FbController
  # todo: ajax set state in links (request status_update and read_stream) so
  #       that old pages (used has used back bottom in browser) still is working
  def set_state (context)
    state = session[:state].to_s
    state = session[:state] = String.generate_random_string(30) unless state.length == 30
    "#{state}-#{context}"
  end
  def clear_state
    session.delete(:state)
    get_linkedin_client() if logged_in?
  end
  def invalid_state?
    state = params[:state].to_s
    return true unless state =~ /^[a-zA-Z0-9]{30}-/
    return true unless state.length > 31
    return true unless session[:state].to_s == state.first(30)
    false
  end

  # save/get linkedin oauth client
  # save is called after gifts/create and LinkedIn::Errors::AccessDeniedError from linkedin - post in linkedin wall not allowed
  # get is called from linkedin/index when user returns from linkedin after allowing write access to linkedin wall
  private
  def save_linkedin_client (client)
    task_name = 'linkedin_rw_nus'
    t = Task.find_by_session_id_and_task(session[:session_id], task_name)
    t.destroy if t
    t = Task.new
    t.session_id = session[:session_id]
    t.task = task_name
    t.priority = 5
    t.ajax = 'N'
    t.task_data = client.to_yaml
    t.save!
  end # save_linkedin_client
  def get_linkedin_client
    task_name = 'linkedin_rw_nus'
    t = Task.where("session_id = ? and task = ? and created_at > ?", session[:session_id], task_name, 10.minutes.ago).first
    return nil unless t
    client = YAML::load(t.task_data)
    t.destroy
    client
  end # get_linkedin_client

  private
  def login_user_ids
    session[:user_ids] || []
  end
  helper_method :login_user_ids

  private
  def filter_locale (locale)
    available_locales = Rails.application.config.i18n.available_locales.collect { |locale| locale.to_s }
    return nil unless available_locales.index(locale.to_s)
    locale
  end

  # set timezone used in views
  private
  def get_timezone
    Time.zone = session[:timezone] if session[:timezone]
  end

  # save timezone received from JS or from login provider
  private
  def set_timezone(timezone)
    timezone = "#{timezone}.0" unless timezone.to_s.index('.')
    timezones = ActiveSupport::TimeZone.all.collect { |tz| (tz.tzinfo.current_period.utc_offset / 60.0 / 60.0).to_s }.uniq
    if !timezones.index(timezone)
      logger.debug2  "unknown timezome #{timezone}"
      return
    end
    logger.debug2  "timezone = #{timezone}"
    Time.zone = session[:timezone] = timezone.to_f
  end

  # used in api posts
  private
  def format_direction_without_user (api_gift)
    gift = api_gift.gift
    case gift.direction
      when 'giver'
        t 'gifts.index.direction_giver_prompt' # Offers:
      when 'receiver'
        t 'gifts.index.direction_receiver_prompt' # Seeks:
      else
        ""
    end # case
  end # format_direction

  # used in gifts/index
  private
  def format_direction_with_user (api_gift)
    gift = api_gift.gift
    case gift.direction
      when 'giver'
        t 'gifts.api_gift.direction_giver', :username => api_gift.giver.short_or_full_user_name(@user)
      when 'receiver'
        t 'gifts.api_gift.direction_receiver', :username => api_gift.receiver.short_or_full_user_name(@user)
      when 'both'
        t 'gifts.api_gift.direction_giver_and_receiver', :givername => api_gift.giver.short_user_name, :receivername => api_gift.receiver.short_user_name
      else
        raise "invalid direction for gift #{gift.id}"
    end # case
  end # format_direction
  helper_method :format_direction_with_user

  private
  def deep_link?
    deep_link = (params[:controller] == 'gifts' and params[:action] == 'show' and params[:id].to_s =~ /^[a-zA-Z0-9]{30}$/) ? true : false
    # logger.debug2 "deep_link = #{deep_link}, controller = #{params[:controller]}, action = #{params[:action]}, id = #{params[:id]}"
    deep_link
  end
  helper_method "deep_link?"

end # ApplicationController

# encoding: utf-8
require 'money/bank/google_currency'

#noinspection RubyResolve
class ApplicationController < ActionController::Base

  before_filter :setup_errors
  before_filter :request_start_time

  # protect cookie information on public web servers
  force_ssl if: :ssl_configured?

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :request_url_for_header
  before_filter :fetch_users
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
  # get start time for request for show-more-rows check
  def request_start_time
    @request_start_time = Time.new.seconds_since_midnight
  end

  private
  def add_dummy_user
    @users << User.find_or_create_dummy_user('gofreerev') if @users.size == 0
  end


  # friends information is used many different places
  # cache friends information once and for all in @users array (user.friends_hash)
  # friends categories:
  # 1) logged in user
  # 2) mutual friends         - show detailed info
  # 3) follows (F)            - show few info
  # 4) stalked by (S)         - show few info
  # 5) deselected api friends - show few info
  # 6) friends of friends     - show few info
  # 7) others                 - not clickable user div - for example comments from other login providers
  private
  def cache_friend_info (users)
    return if users.size == 0
    user_ids = users.collect { |u| u.user_id}
    # get friends. split in 4 categories. Y: mutual friends, F: follows, S: Stalked by, N: not app friend
    logger.debug2 "get friends. user_ids = #{user_ids.join(', ')}"
    users_app_friends = { 'Y' => [], 'F' => [], 'S' => [], 'N' => []}
    friends = Friend.where("user_id_giver in (?)", user_ids)
    friends.each do |f|
      users_app_friends[f.app_friend || f.api_friend] << f.user_id_receiver # save userids in Y, F, S and N arrays
    end
    logger.debug2 "get friends of mutual friends"
    friends_of_friends_ids = Friend.
        where('user_id_giver in (?)', users_app_friends['Y']).
        find_all { |f| (f.app_friend || f.api_friend) == 'Y' }.
        collect { |f| f.user_id_receiver }
    friends_hash = {}
    users.each do |user|
      friends_hash[user.provider] = {}
    end
    # loop for each friend category
    [ [1, user_ids], [2, users_app_friends['Y']], [3, users_app_friends['F']], [4, users_app_friends['S']],
      [5, users_app_friends['N']], [6, friends_of_friends_ids] ].each do |x|
      friends_category, friends_user_ids = x
      friends_user_ids.each do |user_id|
        provider = user_id.split('/').last
        friends_hash[provider][user_id] = friends_category unless friends_hash[provider].has_key?(user_id)
      end # friends_user_ids
    end
    # copy friends_hash to users array
    users.each do |user|
      user.friends_hash = friends_hash[user.provider]
    end
    users
  end # cache_friend_info


  # fetch user info. Used in page heading etc
  private
  def fetch_users
    # language support
    # logger.debug2  "start. sessionid = #{request.session_options[:id]}"
    # logger.debug2  "I18n.locale = #{I18n.locale}"

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
      @users = User.where("user_id in (?)", login_user_ids)
    else
      @users = []
    end

    # check for deleted users - user(s) deleted in an other session/browser
    if login_user_ids.length != @users.length
      login_user_ids_tmp = @users.collect { |user| user.user_id }
      tokens = session[:tokens] || {}
      new_tokens = {}
      @users.each { |user| new_tokens[user.provider] = tokens[user.provider] }
      session[:user_ids] = login_user_ids_tmp
      session[:tokens] = new_tokens
    end

    # friends information is used many different places
    # cache friends information once and for all in @users array (user.friends_hash)
    # friends categories:
    # 1) logged in user
    # 2) friends                - show detailed info
    # 3) deselected api friends - show few info
    # 4) friends of friends     - show few info
    # 5) others                 - not clickable user div - for example comments from other login providers
    cache_friend_info(@users)

    # add sort_by_provider method instance method to @users array.
    # used in a few views (invite users, auth/index)
    # todo: should use provider_downcase method, but application controller methods are not available in Array class
    # todo: move provider_downcase to constant?
    @users.define_singleton_method :sort_by_provider do
      self.sort do |a, b|
        (API_CAMELIZE_NAME[a.provider] || a.provider) <=> (API_CAMELIZE_NAME[b.provider] || b.provider)
      end
    end

    # add remove_deleted_users
    @users.define_singleton_method :remove_deleted_users do
      self.delete_if { |u| u.deleted_at }
    end
    user = @users.first

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
    if user
      Money.default_currency = Money::Currency.new(user.currency)
      # todo: set decimal mark and thousands separator from language - not from currency
      @user_currency_separator = Money::Currency.table[user.currency.downcase.to_sym][:decimal_mark]
      @user_currency_delimiter = Money::Currency.table[user.currency.downcase.to_sym][:thousands_separator]
    end
    logger.debug2  "@user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"

    # add dummy user for page header
    add_dummy_user if @users.size == 0

    # get new exchange rates? add to task queue
    add_task 'fetch_exchange_rates', 10 if logged_in? and ExchangeRate.fetch_exchange_rates?
  end # fetch_user


  # 1. priority is locale from url - 2. priority is locale from session - 3. priority is default locale (en)
  # locale is also saved in session for language support in api provider callbacks
  private
  def set_locale
    params[:locale] = nil if params.has_key?(:locale) and request.xhr?
    session[:language] = params[:locale] if filter_locale(params[:locale])
    I18n.locale = filter_locale(params[:locale]) || filter_locale(session[:language]) || filter_locale(I18n.default_locale) || 'en'
    # logger.debug2  "I18n.locale = #{I18n.locale}. params[:locale] = #{params[:locale]}, session[:language] = #{session[:language]}, "
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
    # logger.debug2 "login_user_ids = #{login_user_ids}"
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
    if !get_last_row_id()
      logger.error2 "get_next_set_of_rows: session[:last_row_id] was not found"
      add_error_key 'shared.show_more_rows.last_row_id_missing'
      return true
    end
    if !get_last_row_at()
      logger.error2 "get_next_set_of_rows: session[:last_row_at] was not found"
      add_error_key 'shared.show_more_rows.last_row_at_missing'
      return true
    end
    # max one get-more-rows request once every GET_MORE_ROWS_INTERVAL seconds
    new_last_row_at = Time.new.seconds_since_midnight
    dif = new_last_row_at - get_last_row_at()
    dif += 1.day if dif < 0
    if last_row_id != get_last_row_id()
      # wrong last_row_id received in get-more-rows ajax request. Must be an error a javascript/ajax error
      logger.warn2  "problem with get-more-rows ajax request. expected #{get_last_row_id()}. found #{last_row_id}."
      add_error_key 'shared.show_more_rows.last_row_id_invalid', :expected => get_last_row_id(), :found => last_row_id
      # return dummy row with correct last_row_id to client x
      return true
    elsif dif < GET_MORE_ROWS_INTERVAL - 0.1
      # client must only send get-more-rows once every GET_MORE_ROWS_INTERVAL seconds.
      # Must be an javascript/ajax error. See my.js show_more_rows_scroll
      # best if client waits between requests - server should not spend time sleeping
      wait = GET_MORE_ROWS_INTERVAL-dif
      logger.warn2 "last_row_at = #{get_last_row_at()}, now = #{new_last_row_at}, dif = #{dif}"
      msg = "Max one get-more-rows ajax request every #{GET_MORE_ROWS_INTERVAL} seconds. " +
          "Time.new = #{Time.new}. Wait for #{wait} seconds"
      logger.warn2  msg
      if debug_ajax?
        logger.warn2  msg
        logger.warn2  msg
      end
      sleep(wait)
      add_error_key 'shared.show_more_rows.invalid_interval', :interval => GET_MORE_ROWS_INTERVAL, :sleep => wait
      return false
    else
      # normal ajax response with next set of gifts or users
      return false
    end
  end # get_next_set_of_rows_error?

  # used in ajax expanding pages (gifts/index, users/index and users/show pages)
  private
  def get_next_set_of_rows (rows, last_row_id, no_rows=nil)
    logger.debug2  "last_row_id (input) = #{last_row_id}"
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
    set_last_row_id(last_row_id) # control - is checked in next ajax request
    if ajax_request
      set_last_row_at(@request_start_time)
    else
      set_last_row_at(@request_start_time-GET_MORE_ROWS_INTERVAL)
    end
    logger.debug2  "last_row_id (output) = #{last_row_id}"
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
    return t 'shared.providers.blank' if provider.to_s == '' # generic provider text
    return provider if !valid_provider?(provider) # unknown provider or already translated
    API_DOWNCASE_NAME[provider] || provider
  end
  helper_method :provider_downcase

  # formal provider name - used in views
  private
  def provider_camelize (provider)
    return t 'shared.providers.blank' if provider.to_s == '' # generic provider text
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
      # fix for ie8/ie9 error:
      #  "to help protect your security internet explorer blocked this site from downloading files to your computer"
      # (x.js.erb response is being downloaded instead of being executed)
      # only a problem in remote forms (new gifts and new comments)
      format.js { render :content_type => "text/plain" }
      # format.js {  }
    end
    nil
  end

  private
  def logged_in?
    (login_user_ids.length > 0)
  end
  helper_method "logged_in?"

  # note that login_required? check filter is skipped in many ajax requests
  # ( customized error messages for not logged in users )
  private
  def login_required
    return true if logged_in?
    if !request.xhr?
      save_flash 'shared.not_logged_in.redirect_flash'
      redirect_to :controller => :auth, :action => :index
      return
    end
    # ajax request and not logged in.
    table = nil
    tasks_errors = 'tasks_errors'
    controller = params[:controller]
    action = params[:action]
    logger.debug2 "controller = #{controller}, action = #{action}"
    # todo: add case with controller and actions to be handled here
    #case controller
    #  when 'gifts'
    #    case action
    #      when  'create'
    #        table = tasks_errors
    #    end # case action gifts controller
    #end # case controller
    key = 'shared.not_logged_in.ajax_' + (request.get? ? 'get' : 'post')
    if table
      add_error_key key, :id => table
    else
      logger.error2 "not logged in ajax response not implemented for controller = #{params[:controller]}, action = #{params[:action]}"
      save_flash key
      redirect_to :controller => :auth, :action => :index
      # JS error: ....: "SyntaxError: syntax error. check server log for more information"
    end
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
    return user unless user.class == User # error: key + options
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

    return nil if user.deleted_at # no post login tasks for delete marked users

    # check currency after new login - keep current currency
    @users = User.where('user_id in (?)', login_user_ids)
    if @users.collect { |user2| user2.currency }.uniq.length > 1
      old_user = @users.find { |user2| user2.user_id != user.user_id }
      user.currency = old_user.currency
      user.save!
    end

    if image.to_s != ""
      if image =~ /^http/ and !image.index("''") and !image.index('"')
        # todo: other characters to filter? for example characters with a special os function
        # facebook: profile picture from login is not used - profile picture from koala request in post login task is used
        # see util_controller.post_login_update_friends / facebook api client gofreerev_get_user instance method
        add_task "User.update_profile_image('#{user.user_id}', '#{image}')", 5 unless provider == 'facebook'
      else
        logger.debug2 "invalid picture received from #{provider}. image = #{image}"
      end
    end
    post_login_task_provider = "post_login_#{provider}" # private method in UtilController
    if UtilController.new.private_methods.index(post_login_task_provider.to_sym)
      add_task post_login_task_provider, 5
    else
      add_task "generic_post_login('#{provider}')", 5
      logger.debug2 "no post_login_#{provider} method was found in util controller - using generic post login task"
      ## write error message in log and ajax inject error message in gifts/index page
      ## there must be a post_login_<provider> method to download friend list from login provider
      #logger.error2  "No post login task was found for #{provider}. No #{provider} friend information will be downloaded"
      #add_task "post_login_not_found('#{provider}')"
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
    tokens = session[:tokens] || {}
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
  # used in LinkedInController
  # todo: ajax set state in links (request status_update and read_stream) so
  #       that old pages (used has used back bottom in browser) still is working
  # three methods that saves state in session cookie store
  private
  def set_state_cookie_store (context)
    state = session[:state].to_s
    state = session[:state] = String.generate_random_string(30) unless state.length == 30
    logger.debug2 "session[:session_id] = #{session[:session_id]}, session[:state] = #{session[:state]}"
    "#{state}-#{context}"
  end
  def clear_state_cookie_store
    logger.debug2 "clear state"
    session.delete(:state)
    get_linkedin_api_client() if logged_in?
  end
  def invalid_state_cookie_store?
    logger.debug2 "session[:session_id] = #{session[:session_id]}, session[:state] = #{session[:state]}, params[:state] = #{params[:state]}"
    state = params[:state].to_s
    return true unless session[:state].to_s == state.first(30)
    false
  end


  # special store for state when login starts from facebook (facebook/create => facebok/autologin => .. => facebook/index )
  # the problem is that for example IE10 does not update session cookie before redirection to facebook for login
  # save state in tasks table with sessionid and a simple device fingerprint (user agent + ip adr)
  private
  def set_state_tasks_store (context)
    task_name = 'facebook_state'
    t = Task.find_by_session_id_and_task(session[:session_id], task_name)
    t.destroy if t
    t = Task.new
    t.session_id = session[:session_id]
    t.task = task_name
    t.priority = 5
    t.ajax = 'N'
    state = String.generate_random_string(30)
    t.task_data = { :user_agent => request.user_agent, :remote_ip => request.remote_ip, :state => state }.to_yaml
    t.save!
    "#{state}-#{context}"
  end # set_state_tasks_store
  def invalid_state_tasks_store?
    task_name = 'facebook_state'
    t = Task.find_by_session_id_and_task(session[:session_id], task_name)
    t.destroy if t
    return true unless t
    return true if t.created_at < 1.minute.ago
    task_data = YAML::load(t.task_data)
    logger.debug2 "task_data = #{task_data}"
    logger.debug2 "params[:state] = #{params[:state]}, user agent = #{request.user_agent}, remote_ip = #{request.remote_ip}"
    return true unless task_data[:state].to_s.first(30) == params[:state].to_s.first(30)
    return true unless task_data[:user_agent].to_s == request.user_agent.to_s
    return true unless task_data[:remote_ip].to_s == request.remote_ip.to_s
    false
  end # invalid_state_tasks_store?



  # save/get flickr oauth client
  # save is called after gifts/create and todo: exception from flickr - post in flickr wall not allowed
  # get is called from flickr/index when user returns from flickr after allowing write access to flickr wall
  private
  def save_flickr_api_client (client, token)
    task_name = 'flickr_write'
    t = Task.find_by_session_id_and_task(session[:session_id], task_name)
    t.destroy if t
    t = Task.new
    t.session_id = session[:session_id]
    t.task = task_name
    t.priority = 5
    t.ajax = 'N'
    t.task_data = [client, token].to_yaml
    t.save!
  end # save_flickr_client
  def get_flickr_api_client
    task_name = 'flickr_write'
    t = Task.where("session_id = ? and task = ? and created_at > ?", session[:session_id], task_name, 10.minutes.ago).first
    return nil unless t
    client = YAML::load(t.task_data)
    t.destroy
    client
  end # get_flickr_client


  # save/get linkedin oauth client
  # save is called after gifts/create and LinkedIn::Errors::AccessDeniedError from linkedin - post in linkedin wall not allowed
  # get is called from linkedin/index when user returns from linkedin after allowing write access to linkedin wall
  private
  def save_linkedin_api_client (client)
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
  def get_linkedin_api_client
    task_name = 'linkedin_rw_nus'
    t = Task.where("session_id = ? and task = ? and created_at > ?", session[:session_id], task_name, 10.minutes.ago).first
    return nil unless t
    client = YAML::load(t.task_data)
    t.destroy
    client
  end # get_linkedin_client


  # save/get "state" -
  private

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

  
  # session get/set methods
  # session cookie store is used now, but there is problems with session updates and multiple ajax requests
  # for example last_row_id set is updated in one ajax request and reset to old value in an other ajax request
  # maybe move some session variable to a db table
  
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
    return add_error_key '.unknown_timezone', :timezone => timezone unless timezones.index(timezone)
    logger.debug2  "timezone = #{timezone}"
    Time.zone = session[:timezone] = timezone.to_f
  end

  # get/set last_row_id
  # has been moved from cookie session store to sessions table
  # ( problem with concurrent ajax requests and session store update )
  private
  def set_last_row_id (last_row_id)
    session.delete(:last_row_id) if session.has_key?(:last_row_id)
    s = Session.find_by_session_id(session[:session_id])
    if !s
      s = Session.new
      s.session_id = session[:session_id]
    end
    s.last_row_id = last_row_id
    s.save!
    last_row_id
  end
  def get_last_row_id
    set_last_row_id(session[:last_row_id]) if session.has_key?(:last_row_id)
    s = Session.find_by_session_id(session[:session_id])
    return nil unless s
    s.last_row_id
  end

  # get/set last_row_at 
  # has been moved from cookie session store to sessions table
  # ( problem with concurrent ajax requests and session store update )
  private
  def set_last_row_at (last_row_at)
    logger.debug "last_row_at = #{last_row_at}"
    session.delete(:last_row_at) if session.has_key?(:last_row_at)
    s = Session.find_by_session_id(session[:session_id])
    if !s
      s = Session.new
      s.session_id = session[:session_id]
    end
    s.last_row_at = last_row_at
    s.save!
    logger.debug2 "last_row_at = #{last_row_at}, Time.new.seconds_since_midnight = #{Time.new.seconds_since_midnight}, session_id = #{session[:session_id]}"
    last_row_at
  end
  def get_last_row_at
    set_last_row_at(session[:last_row_at]) if session.has_key?(:last_row_at)
    s = Session.find_by_session_id(session[:session_id])
    last_row_at = s.last_row_at if s
    logger.debug2 "last_row_at = #{last_row_at}, Time.new.seconds_since_midnight = #{Time.new.seconds_since_midnight}, session_id = #{session[:session_id]}"
    last_row_at
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
        t 'gifts.api_gift.direction_giver', :username => api_gift.giver.short_or_full_user_name(@users)
      when 'receiver'
        t 'gifts.api_gift.direction_receiver', :username => api_gift.receiver.short_or_full_user_name(@users)
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

  private
  def open_graph_title_and_desc(api_gift)
    text = "#{format_direction_without_user(api_gift)}#{api_gift.gift.description}"
    title_lng = API_OG_TITLE_SIZE[api_gift.provider] || 70
    desc_lng = API_OG_DESC_SIZE[api_gift.provider] || 200
    if text.length <= title_lng
      # short gift text - get generic description from gifts.show.og_def_desc_<provider>
      title = text
      on_error_desc = "Help each other and the environment. Share your resources. #{APP_NAME} is a play with some concepts (gift network, free money and negative interest) from Charles Eisensteins book Sacred Economics."
      og_desc_key = "gifts.show.og_def_desc_#{api_gift.provider}"
      begin
        description = t og_desc_key, api_gift.app_and_apiname_hash.merge(:raise => I18n::MissingTranslationData)
      rescue I18n::MissingTranslationData => e
        logger.error2 "Error in translate key #{og_desc_key}"
        logger.error2 "#{e.message} (#{e.class})"
        description = on_error_desc
      rescue I18n::MissingInterpolationArgument => e
        logger.error2 "Error in translate key #{og_desc_key}"
        logger.error2 "#{e.message} (#{e.class})"
        description = on_error_desc
      end
      return [title, description, nil]
    end
    # long gift - split gift in title and description
    to = text.first(title_lng).rindex(' ')
    if (to)
      [text.first(to), text.from(to+1).first(desc_lng), text.from(to+1).from(desc_lng) ]
    else
      [text.first(title_lng), text.from(title_lng).first(desc_lng), text.from(title_lng).from(desc_lng)]
    end
  end # open_graph_title_and_desc


  # define api clients. There must be one init_api_client_<provider> method for each provider
  # structure: initialize api_client, add one or more gofreerev_xxx instance methods, return api_client
  # instance method gofreerev_get_friends is required (download friend list)
  # instance method gofreerev_post_on_wall is required if provider should support post on api wall
  # instance method gofreerev_get_user can be added if user info. should be updated after login (facebook)

  private
  def init_api_client_facebook (token)
    provider = 'facebook'
    # create facebook api client
    api_client = Koala::Facebook::API.new(token)
    # add helper methods to facebook api client
    # get a few login user fields that was not updated doing login
    api_client.define_singleton_method :gofreerev_get_user do |logger|
      user_hash = {}
      key, options = nil
      # get user information - permissions and picture
      api_request = 'me?fields=permissions,picture.width(100).height(100)'
      logger.debug2  "api_request = #{api_request}"
      api_response = api_client.get_object api_request
      logger.debug2  "api_response = #{api_response}"
      user_hash[:permissions] = api_response['permissions']['data'][0]
      user_hash[:permissions] = {} if user_hash[:permissions] == []
      image = api_response['picture']['data']['url'] if api_response['picture'] and api_response['picture']['data']
      user_hash[:api_profile_picture_url] = image if image
      # return user_hash to generic_post_login - see also user.update_api_user_from_hash
      [user_hash, key, options]
    end
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get facebook friends list (name and url for profile picture for each facebook friend)
      # note that some friends may have privacy settings that prevent client from pulling friends information from API
      # ( not all friends are returned )
      api_request = 'me/friends?fields=name,id,picture.width(100).height(100)'
      # logger.debug2  "api_request = #{api_request}"
      friends = self.get_object api_request
      # logger.debug2  "friends = #{friends}"
      # copy friends from api to friends_hash
      friends_hash = {}
      friends.each do |friend|
        # logger.debug2 "friend = #{friend}"
        friend_user_id = friend["id"] + '/facebook'
        name = friend["name"].force_encoding('UTF-8')
        if friend["picture"] and friend["picture"]["data"]
          api_profile_picture_url = friend["picture"]["data"]["url"]
        else
          api_profile_picture_url = nil
        end
        friends_hash[friend_user_id] = {:name => name,
                                        :api_profile_picture_url => api_profile_picture_url }
      end # each
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends
    # add gofreerev_post_on_wall - used in post_on_<provider> / generic_post_on_wall
    # cache facebook login user - used in gofreerev_post_on_wall error handling
    login_user = @users.find { |user| user.provider == provider }
    api_client.define_singleton_method :gofreerev_post_on_wall do |options|
      # get params
      api_gift = options[:api_gift]
      logger = options[:logger]
      picture = options[:picture]
      direction = options[:direction] # offers / seeks
      open_graph = options[:open_graph]
      gift = api_gift.gift
      deep_link = " - #{api_gift.deep_link}"

      # have not found FB documentation about max message length
      message_max_lng = API_MAX_TEXT_LENGTHS[:facebook][:message] if API_MAX_TEXT_LENGTHS[:facebook]
      message_max_lng = 47950 unless message_max_lng
      description_max_lng = message_max_lng - deep_link.size
      message = gift.description.first(description_max_lng) + deep_link

      begin
        if picture
          # logger.debug2 'status post with picture'
          filetype = picture.split('.').last
          content_type = "image/#{filetype}"
          api_response = api_client.put_picture(picture, content_type, {:message => message})
          # api_response = {"id"=>"1396226023933952", "post_id"=>"100006397022113_1396195803936974"} (Hash)
          api_gift_id = api_response['post_id']
        else
          # logger.debug2 'status post without picture'
          # gift.description = "#{gift.description} - #{link}" # link only as text
          # gift.description = "<a href='#{link}'>#{gift.description}</a>" # html code as text
          api_response = api_client.put_connections('me', 'feed', :message => message)
          # api_response = {"id"=>"100006397022113_1396235850599636"}
          api_gift_id = api_response['id']
        end
        logger.debug2 "api_response = #{api_response} (#{api_response.class.name})"
      rescue Koala::Facebook::ClientError => e
        e.logger = logger
        e.puts_exception("#{__method__}: ")
        if e.fb_error_type == 'OAuthException' && e.fb_error_code == 506
          # delete gift and ignore error OAuthException, code: 506, message: (#506) Duplicate status message [HTTP 400]
          # gift_posted_on_wall_api_wall = 4 # Gift posted in here but not on your facebook wall. Duplicate status message on facebook wall.
          # error should not happen any longer as deep link now is included in message
          raise DupPostOnWall
        elsif e.fb_error_type == 'OAuthException' && e.fb_error_code == 200
          # e.response_body = {"error":{"message":"(#200) The user hasn't authorized the application to perform this action","type":"OAuthException","code":200}}
          # check if permission to post i api wall has been removed
          error = e.to_s
          login_user.get_permissions_facebook(api_client)
          if !login_user.post_on_wall_authorized?
            # permission to post on api wall has been removed.
            # show request_post_gift_priv_link link in gifts/index page
            raise PostNotAllowed
          else
            # permission to post on api wall has NOT been removed. Unknown error
            # gift_posted_on_wall_api_wall = 1 # unknown error. no translation
            api_gift.clear_deep_link
            raise
          end
        elsif e.fb_error_type == 'OAuthException' && e.fb_error_code == 190
          # user has deauthorized gofreerev / removed gofreerev in facebook app setting page
          # Koala::Facebook::ClientError
          # fb_error_type    = OAuthException (String)
          # fb_error_code    = 190 (Fixnum)
          # fb_error_subcode = 458 (Fixnum)
          # fb_error_message = Error validating access token: The user has not authorized application 193177257554775. (String)
          # http_status      = 400 (Fixnum)
          # response_body    = {"error":{"message":"Error validating access token: The user has not authorized application 193177257554775.","type":"OAuthException","code":190,"error_subcode":458}}
          # logout and return error message to user
          # logout(provider)
          # gift_posted_on_wall_api_wall = 8
          raise AppNotAuthorized
        else
          # unhandled exceptions
          gift_posted_on_wall_api_wall = 1 # unknown error. no translation
          error = e.to_s
          api_gift.clear_deep_link
          raise
        end
      rescue Koala::Facebook::ServerError => e
        e.logger = logger
        e.puts_exception("#{__method__}: ")
        api_gift.clear_deep_link
        raise
      end # rescue
      # ok
      [ api_gift_id, nil ] # api_gift_url will be looked up in generic_post_on_wall
    end
    # return api client
    api_client
  end # init_api_client_facebook

  private
  def init_api_client_flickr (token)
    provider = 'flickr'
    # create flickr api client
    FlickRaw.api_key = API_ID[provider]
    FlickRaw.shared_secret = API_SECRET[provider]
    api_client = flickr
    api_client.access_token = token[0]
    api_client.access_secret = token[1]
    # add helper methods to flickr api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get flickr friends (follows)
      friends = self.contacts.getList
      # copy follows into friends_hashs
      friends_hash = {}
      friends.each do |contact|
        logger.debug2 "contact = #{contact} (#{contact.class})"
        # copy friend to friends_hash
        friend_user_id = "#{contact.nsid}/#{provider}"
        friend_name = (contact.realname == '' ? contact.username : contact.realname).force_encoding('UTF-8')
        friend_api_profile_url = "#{API_URL[:flickr]}people/#{contact.nsid}"
        if contact.iconfarm.to_s == '0' and contact.iconserver.to_s == '0'
          friend_api_profile_picture_url = nil
        else
          friend_api_profile_picture_url = "http://farm#{contact.iconfarm}.static.flickr.com/#{contact.iconserver}/buddyicons/#{contact.nsid}.jpg"
        end
        friends_hash[friend_user_id] = {:name => friend_name,
                                        :api_profile_url => friend_api_profile_url,
                                        :api_profile_picture_url => friend_api_profile_picture_url}
      end
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends

    # add gofreerev_post_on_wall - used in post_on_<provider> / generic_post_on_wall
    api_client.define_singleton_method :gofreerev_post_on_wall do |options|
      # get params
      api_gift = options[:api_gift]
      logger = options[:logger]
      picture = options[:picture]
      direction = options[:direction] # offers / seeks
      open_graph = options[:open_graph]
      gift = api_gift.gift
      deep_link = api_gift.deep_link
      # always post with picture on flickr. API_TEXT_TO_PICTURE[:flickr] == 0
      # todo: add title? For example title from OG - max 255 characters
      # todo: no max length for flickr description?
      begin
        api_gift_id = self.upload_photo picture, :description => "#{gift.description} - #{deep_link}"
      rescue FlickRaw::OAuthClient::FailedResponse => e
        logger.debug2 "exception: #{e.message} (#{e.message.class})"
        # logger.debug2 "e.methods = #{e.methods.sort.join(', ')}"
        if e.message == 'token_rejected'
          # user has deauthorized app in app settings page http://www.flickr.com/services/auth/list.gne
          raise AppNotAuthorized
        end
        # other unhandled errors
        raise
      end
      api_gift_url = "#{API_URL[provider]}photos/gofreerev/#{api_gift_id}/"
      [api_gift_id, api_gift_url]
    end # gofreerev_post_on_wall

    # return api client
    api_client
  end # init_api_client_flickr

  private
  def init_api_client_foursquare (token)
    provider = 'foursquare'
    # create foursquare api client
    api_client = Foursquare2::Client.new(:oauth_token => token)
    # add helper methods to foursquare api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get foursquare friends
      friends = self.user_friends 'self', :v => '20140214'
      # copy friends list to hash
      friends_hash = {}
      friends["items"].each do |friend|
        logger.debug2 "friend = #{friend}"
        friend_user_id = "#{friend.id}/#{provider}"
        name = "#{friend.firstName} #{friend.lastName}".force_encoding('UTF-8')
        api_profile_url = "#{API_URL[provider]}/user/#{friend.id}"
        api_profile_picture_url = "#{friend.photo.prefix}100x100#{friend.photo.suffix}"
        friends_hash[friend_user_id] = {:name => name,
                                        :api_profile_url => api_profile_url,
                                        :api_profile_picture_url => api_profile_picture_url }
      end # each
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends
    # return api client
    api_client
  end # init_api_client_foursquare

  private
  def init_api_client_google_oauth2 (token)
    provider = 'google_oauth2'
    # create google+ api client
    api_client = Google::APIClient.new(
        :application_name => 'Gofreerev',
        :application_version => '0.1'
    )
    api_client.authorization.client_id = API_ID[provider]
    api_client.authorization.client_secret = API_SECRET[provider]
    api_client.authorization.access_token = token
    # add helper methods to google+ api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get methods for google+ api calls
      plus = self.discovered_api('plus')
      # find people in login user circles
      # https://developers.google.com/api-client-library/ruby/guide/pagination
      friends_hash = {}
      request = {:api_method => plus.people.list,
                 :parameters => {'collection' => 'visible', 'userId' => 'me'}}
      # loop for all google+ friends - one or more pages with friends
      loop do
        # get first/next page of google+ follows
        result = self.execute(request)
        # logger.debug2  "result = #{result}"
        # logger.debug2  "result.error_message.class = #{result.error_message.class}"
        # logger.debug2  "result.error_message = #{result.error_message}"
        # known errors from Google API
        return ['.google_access_not_configured', {:provider => provider}] if result.error_message.to_s == 'Access Not Configured'
        return ['.google_insufficient_permission', {:provider => provider}] if result.error_message.to_s == 'Insufficient Permission'
        # other errors from Google API
        return ['.google_other_errors', {:provider => provider, :error => result.error_message}] if !result.data.total_items

        # copy friends to hash.
        # logger.debug2  "result.data.items = #{result.data.items}"
        # todo: check friend.kind = plus#person - maybe ignore rows with friend.kind != plus#person
        # todo: returns profile picture urls with size 50 x 50 (?sz=50) - replace with ?sz=100 ?
        for friend in result.data.items do
          # logger.debug2  "friend = #{friend} (#{friend.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          friends_hash[friend_user_id] = { :name => friend.display_name.force_encoding('UTF-8'),
                                           :api_profile_url => friend.url,
                                           :api_profile_picture_url => friend.image.url }
        end # item
        # next page - get more friends if any
        break unless result.next_page_token
        request = result.next_page
      end # loop for all google+ friends
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends
    # return api client
    api_client
  end # init_api_client_google_oauth2

  private
  def init_api_client_instagram (token)
    provider = 'instagram'
    # create instagram api client
    Instagram.configure do |config|
      config.client_id = API_ID[provider]
      config.client_secret = API_SECRET[provider]
    end
    api_client = Instagram.client(:access_token => token)
    # add helper methods to instagram api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get arrays with follows and followers
      follows = self.user_follows
      followed_by = self.user_followed_by
      # api_friend: Y: mutual friends, F follows, S Stalked by = followed_by
      api_friends = {}
      follows.each { |f| api_friends[f.id] = 'F' }
      followed_by.delete_if { |f| api_friends[f.id] = api_friends.has_key?(f.id) ? 'Y' : 'S' ; api_friends[f.id] == 'Y' }
      # initialise friends_hash for Friend.update_api_friends_from_hash request
      friends_hash = {}
      (follows + followed_by).each do |friend|
        logger.debug2 "friend = #{friend} (#{friend.class})"
        # copy friend to friends_hash
        friend_user_id = "#{friend.id}/#{provider}"
        friend_name = (friend.full_name.to_s == '' ? friend.username : friend.full_name).force_encoding('UTF-8')
        friends_hash[friend_user_id] = { :name => friend_name,
                                         :api_profile_url => "#{API_URL[:instagram]}#{friend.username}#",
                                         :api_profile_picture_url => friend.profile_picture,
                                         :api_friend => api_friends[friend.id] }
      end # each friend
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends
    # return api client
    api_client
  end # init_api_client_instagram

  private
  def init_api_client_linkedin (token)
    provider = 'linkedin'
    # create linkedin api client
    api_client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
    api_client.authorize_from_access token[0], token[1] # token and secret
    # add helper methods to linkedin api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get array with linkedin connections
      # http://developer.linkedin.com/documents/profile-fields#profile
      # fields = %w(id,first-name,last-name,public-profile-url,picture-url,num-connections)
      fields = %w(id first-name last-name public-profile-url picture-url num-connections)
      friends = self.connections(:fields => fields).all
      # logger.debug2 "friends = #{friends}"
      # copy array with linkedin connections into gofreerev friends_hash
      friends_hash = {}
      friends.each do |connection|
        # logger.debug2 "connection = #{connection} (#{connection.class})"
        # logger.debug2 "connection.public_profile_url = #{connection.public_profile_url}"
        # copy friend to friends_hash
        friend_user_id = "#{connection.id}/#{provider}"
        friend_name = "#{connection.first_name} #{connection.last_name}".force_encoding('UTF-8')
        friends_hash[friend_user_id] = {:name => friend_name,
                                        :api_profile_url => connection.public_profile_url,
                                        :api_profile_picture_url => connection.picture_url,
                                        :no_api_friends => connection.num_connections}
      end # connection loop
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends

    # add gofreerev_post_on_wall - used in post_on_<provider> / generic_post_on_wall
    api_client.define_singleton_method :gofreerev_post_on_wall do |options|
      # get params
      api_gift = options[:api_gift]
      logger = options[:logger]
      picture = options[:picture]
      direction = options[:direction] # offers / seeks
      open_graph = options[:open_graph] # array - post text in title, description and remainder
      gift = api_gift.gift
      deep_link = api_gift.deep_link
      begin

        # http://stackoverflow.com/questions/15183107/rails-linked-post-message
        # http://developer.linkedin.com/documents/share-api#toggleview:id=ruby
        # Node                Parent Node    Value 	Notes
        # comment             share          Text of member's comment.        Post must contain comment and/or (content/title and content/submitted-url).
        #                                                                     Max length is 700 characters.
        # content             share          Parent node for information on shared document
        # title               share/content  Title of shared document         Post must contain comment and/or (content/title and content/submitted-url).
        #                                                                     Max length is 200 characters.
        # submitted-url       share/content  URL for shared content           Post must contain comment and/or (content/title and content/submitted-url).
        # submitted-image-url share/content  URL for image of shared content  Invalid without (content/title and content/submitted-url).
        # description         share/content  Description of shared content    Max length of 256 characters.
        # note that linkedin uses meta property="og:description as default description
        # todo: check layout with and without picture
        # todo: check description length. <= 256 use only description. length <= 700. Use only comment. Length between 700 and 956 use comment and description
        # my test says: title 60, description 245 and comment 600 characters
        logger.debug2 "picture = #{picture}"
        image_url = Picture.url :full_os_path => picture if picture
        # logger.debug2 "image_url = #{image_url}"
        image_url = SITE_URL + image_url.from(1) if image_url and image_url.first == '/'
        logger.debug2 "image_url = #{image_url}"
        text = "#{direction} #{gift.description}"
        # logger.debug2 "picture = #{api_gift.picture?}, text.length = #{text.length}, image_url = #{image_url}"

        # max

        comment = nil
        content = {"submitted-url" => deep_link}
        content["title"], content["description"], comment = open_graph
        comment = comment.to_s.first(700)
        comment = nil if comment == ''
        content["submitted-image-url"] = image_url if api_gift.picture?
        #if api_gift.picture?
        #  # title (max 200 characters) required for post with image.
        #  content["submitted-image-url"] = image_url
        #  # layout rules for post with image on linkedin:
        #  case
        #    when text.length <= 200
        #      content["title"] = text
        #      content["description"] = '.'
        #    when text.length <= 456
        #      content["title"] = text.first(200)
        #      content["description"] = text.from(200)
        #    else
        #      raise "linkedin post with picture and text length > 456 is not implemented"
        #  end
        #else
        #  case
        #    when text.length <= 700
        #      comment = text
        #    else
        #      raise "linkedin post without picture and text length > 700 is not implemented"
        #  end
        #end
        logger.debug2 "content = #{content}, comment = #{comment}"
        x = self.add_share :content => content, :comment => comment
      rescue LinkedIn::Errors::AccessDeniedError => e
        logger.debug2 "LinkedIn::Errors::AccessDeniedError"
        logger.debug2 "e.message = #{e.message}"
        api_gift.clear_deep_link
        if e.message.to_s =~ /^\(403\)/
          # e.message = (403): Access to posting shares denied
          # inject link in tasks_errors table in gifts/index page to allow user to grant missing write permission
          raise PostNotAllowed
        end
        raise
      rescue LinkedIn::Errors::UnauthorizedError => e
        logger.debug2 "LinkedIn::Errors::UnauthorizedError"
        logger.debug2 "e.message = #{e.message}"
        api_gift.clear_deep_link
        if e.message.to_s =~ /^\(401\)/
          # e.message =  (401): [unauthorized]. The token used in the OAuth request is not valid.
          # user has removed app from app settings page https://www.linkedin.com/secure/settings?userAgree=&goback=.nas_*1_*1_*1
          raise AppNotAuthorized
        end
        raise
      end

      # check response from client.add_share request
      if x.class != Net::HTTPCreated
        api_gift.clear_deep_link
        logger.debug2 "no exception from client.add_share, but post was not created"
        logger.debug2 "x = #{x} (#{x.class})"
        logger.debug2 "x.body = #{x.body} (#{x.body.class})"
        raise x.body
        # return ['.gift_posted_1_html', {:apiname => provider, :error => x.body}]
      end

      # post on linkedin ok
      logger.debug2 "x = #{x} (#{x.class})"
      # logger.debug2 "x.methods = #{x.methods.sort.join(', ')}"
      logger.debug2 "x.body = #{x.body} (#{x.body.class})"
      #post_on_linkedin: x.body = {
      #    "updateKey": "UNIU-310307710-5824797827771314176-SHARE",
      #    "updateUrl": "http://www.linkedin.com/updates?discuss=&scope=310307710&stype=M&topic=5824797827771314176&type=U&a=omJz"
      #}

      # extract update post id and post url - url for image is not relevant for linkedin - picture is stored at gofreerev
      # todo: update_url redirects to linkedin login page
      update_key = $1 if x.body.to_s =~ /"updateKey": "(.*?)"/
      update_url = $1 if x.body.to_s =~ /"updateUrl": "(.*?)"/
      logger.debug2 "update key = #{update_key}, update_url = #{update_url}"
      api_gift_id = update_key
      api_gift_url = update_url # note that post on linkedin wall is created in a batch process. Will work in one or 2 minutes
      [api_gift_id, api_gift_url]
    end

    # return api client
    api_client
  end # init_api_client_linkedin

  private
  def init_api_client_twitter (token)
    provider = 'twitter'
    # logger.debug2  "token = #{token.join(', ')}"
    # create twitter api client
    api_client = Twitter::REST::Client.new do |config|
    # api_client = Twitter::Client.new do |config|
      config.consumer_key        = API_ID[provider]
      config.consumer_secret     = API_SECRET[provider]
      config.access_token        = token[0]
      config.access_token_secret = token[1]
    end
    # add helper methods to twitter api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get array with twitter friends (follows)
      friends = self.friends.to_a
      # logger.debug2 "friends = #{friends}"
      # copy vk friends hash array into gofreerev friends_hash
      friends_hash = {}
      begin
        friends.each do |friend|
          # logger.debug2 "friend.url = #{friend.url} (#{friend.url.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend.id}/#{provider}"
          friend_name = friend.name.dup.force_encoding('UTF-8')
          friends_hash[friend_user_id] = { :name => friend_name,
                                           :api_profile_url => friend.url.to_s,
                                           :api_profile_picture_url => friend.profile_image_url.to_s,
                                           :no_api_friends => friend.friends_count }
        end # connection loop
      end
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends

    # add gofreerev_post_on_wall - used in post_on_<provider> / generic_post_on_wall
    api_client.define_singleton_method :gofreerev_post_on_wall do |options|
      # get params
      api_gift = options[:api_gift]
      logger = options[:logger]
      picture = options[:picture]
      direction = options[:direction] # offers / seeks
      open_graph = options[:open_graph]
      gift = api_gift.gift
      deep_link = api_gift.deep_link

      # twitter has some special restrictions on tweet length
      # max tweet length 140 characters
      # always reserve 23+1 characters for deep link (space + link)
      # reserve 23 characters for picture link if attached image in tweet
      if FORCE_SSL
        # must be a public web server - twitter shorten deep link to 23 characters
        deep_link_lng = 24 # space + link
      else
        # must be an internal web server (localhost) - twitter does not shorten deep_link url
        deep_link_lng = deep_link.size + 1
      end
      picture_link_lng = picture ? 23 : 0 # picture link
      text_max_lng = 140 - deep_link_lng - picture_link_lng

      # make tweet. keep tags and truncate non tag text if text is too long
      text = "#{direction}#{gift.description}"
      text =  Gift.truncate_twitter_text text, text_max_lng
      tweet = "#{text} #{deep_link}"

      # post tweet
      x = nil
      begin
        if picture
          # http://rubydoc.info/github/jnunemaker/twitter/Twitter/Client:update_with_media
          logger.debug2 "update_with_media: tweet.length = #{tweet.length}, bytesize = #{tweet.bytesize}"
          logger.debug2 "picture = #{picture}"
          x = self.update_with_media(tweet, File.new(picture))
        else
          logger.debug2 "update: tweet.length = #{tweet.length}, bytesize = #{tweet.bytesize}"
          x = self.update(tweet)
        end
      rescue Twitter::Error::Unauthorized => e
        # # user has removed app from app settings page - https://twitter.com/settings/applications
        logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
        raise AppNotAuthorized if e.message == 'Invalid or expired token'
        raise
      rescue Twitter::Error::Forbidden => e
        # Unable to verify your credentials (Twitter::Error::Forbidden)
        logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
        if e.message == 'Unable to verify your credentials'
          # could be expired access token - force log out + log in
          raise AccessTokenExpired
        end
        raise
      rescue Twitter::Error, Timeout::Error => e
        # maybe a problem with timeout for twitter post.
        # https://github.com/sferik/twitter/issues/516
        # https://github.com/sferik/twitter/issues/401
        # todo: Could return warning to user and repeat post on twitter a few times
        logger.debug2  "Exception: #{e.message.to_s} (#{e.class})"
        logger.debug2  "Backtrace: " + e.backtrace.join("\n")
        raise
      end
      raise Twitter::Error.new "Expected Twitter::Tweet. Found #{x.class}" if x.class != Twitter::Tweet

      # save post id and picture url
      # api_picture_url = x.media.first.media_url.to_s if api_gift.picture?
      # todo: add api_picture_url to return?
      api_gift_id  = x.id.to_s
      api_gift_url = x.url.to_s
      [api_gift_id, api_gift_url]
    end
    # return api client
    api_client
  end # init_api_client_twitter

  private
  def init_api_client_vkontakte (token)
    provider = 'vkontakte'
    login_user = @users.find { |u| u.provider == provider }
    # create vkontakte api client
    Vkontakte.setup do |config|
      config.app_id = API_ID[:vkontakte]
      config.app_secret = API_SECRET[:vkontakte]
      config.format = :json
      config.debug = true
      config.logger = nil # File.open(Rails.root.join('log', "#{Rails.env}.log").to_s, 'a')
    end
    api_client = Vkontakte::App::User.new(login_user.uid, :access_token => token)
    # add helper methods to vkontakte api client
    # add gofreerev_get_friends - used on post_login_<provider>
    api_client.define_singleton_method :gofreerev_get_friends do |logger|
      # get array with vkontakte friends
      # VK also have follows/followers but information is not available for web site api
      # http://vk.com/developers.php?oid=-17680044&p=friends.get
      friends = self.friends.get :fields => "photo_medium,screen_name"
      # logger.debug2 "friends = #{friends}"
      # copy vk friends hash array into gofreerev friends_hash
      friends_hash = {}
      begin
        friends.each do |friend|
          # logger.debug2 "friend.url = #{friend.url} (#{friend.url.class})"
          # copy friend to friends_hash
          friend_user_id = "#{friend['uid']}/#{provider}"
          friend_name = "#{friend['first_name']} #{friend['last_name']}".force_encoding('UTF-8')
          friends_hash[friend_user_id] = { :name => friend_name,
                                           :api_profile_url => "#{API_URL[:vkontakte]}#{friend['screen_name']}",
                                           :api_profile_picture_url => friend['photo_medium'] }
        end # connection loop
      end
      # return friends has to post_login_<provider> - see also Friend.update_api_friends_from_hash
      [friends_hash, nil, nil]
    end # gofreerev_get_friends
    # add gofreerev_post_on_wall - used in post_on_<provider> / generic_post_on_wall
    api_client.define_singleton_method :gofreerev_post_on_wall do |options|
      # false: post to Gofreerev album, true: post to VK wall.
      api_gift = options[:api_gift]
      logger = options[:logger]
      picture = options[:picture]
      direction = options[:direction] # offers / seeks
      open_graph = options[:open_graph]
      wall = false # no errors but is do not looks like upload to VK wall is working. todo: check from a smartphone
      # find/create album with gofreerev pictures
      # http://vk.com/developers.php?oid=-17680044&p=photos.getAlbums
      begin
        albums = self.photos.getAlbums
      rescue Vkontakte::App::VkException => e
        if e.message_options.class == HTTParty::Response and
            e.message_options['error'] and
            e.message_options['error']['error_code'] == 5 and
            e.message_options['error']['error_msg'].to_s =~ /expired/
          logger.debug2 'access token has expired'
          # todo: should log user out of vkontakte
          raise AccessTokenExpired.new(provider)
        end
        logger.debug2 "exception: #{e.message} (#{e.class})"
        logger.debug2 "e.message_options = #{e.message_options} (#{e.message_options.class})"
        raise VkontakteAlbumMissing.new "#{e.class}: #{e.message}"
      rescue Exception => e
        raise VkontakteAlbumMissing.new "#{e.class}: #{e.message}"
      end
      # logger.debug2 "albums = #{albums}"
      album = albums.find { |a| a["title"] == APP_NAME }
      if !album
        # http://vk.com/developers.php?oid=-17680044&p=photos.createAlbum
        begin
          album = self.photos.createAlbum :title => APP_NAME, :description => SITE_URL
        rescue Exception => e
          raise VkontakteCreateAlbum.new "#{e.class}: #{e.message}"
        end
        if album.class != Hash or !album.has_key?('aid')
          raise VkontakteCreateAlbum.new "album = #{album}"
        end
      end
      # logger.debug2 "album = #{album}"
      aid = album['aid']
      if aid.to_s == ''
        logger.debug2 "album = #{album}"
        raise VkontakteAlbumMissing.new "#{APP_NAME} album not found"
      end
      logger.debug2 "aid = #{aid}"
      # get full os path for image
      gift = api_gift.gift
      # get upload server
      begin
        if wall
          # http://vk.com/developers.php?oid=-17680044&p=photos.getWallUploadServer
          uploadserver = self.photos.getWallUploadServer
        else
          # http://vk.com/developers.php?oid=-17680044&p=photos.getUploadServer
          uploadserver = self.photos.getUploadServer :aid => aid
        end
      rescue Exception => e
        raise VkontakteUploadserver.new "#{e.class}: #{e.message}"
      end
      if uploadserver.class != Hash or !uploadserver.has_key?('upload_url')
        raise VkontakteUploadserver.new "uploadserver = #{uploadserver} (#{uploadserver.class})"
      end
      logger.debug2 "uploadserver = #{uploadserver}"
      logger.debug2 "uploadserver.class = #{uploadserver.class}"
      url = uploadserver['upload_url']
      logger.debug2 "url = #{url}"
      # upload - maybe vkontakte gem has a method for this?!
      # http://vk.com/developers.php?oid=-17680044&p=Uploading_Files_to_the_VK_Server_Procedure
      begin
        upload_res1 = RestClient.post url, :file1 => File.new(picture)
      rescue Exception => e
        raise VkontaktePhotoPost.new "#{e.class}: #{e.message}"
      end
      if upload_res1.code.to_s != '200'
        raise VkontaktePhotoPost.new "response code #{upload_res1.code}. body = #{upload_res1.body}"
      end
      # check yml upload response
      begin
        upload_res2 = YAML::load(upload_res1.body)
      rescue Exception => e
        logger.debug2 "upload_res1.class = #{upload_res1.class}"
        logger.debug2 "upload_res1.body = #{upload_res1.body}"
        raise VkontaktePhotoPost.new "#{e.class}: #{e.message}. Excepted yaml response"
      end
      # save uploaded photo in album
      if !upload_res2.has_key?('server') or !upload_res2.has_key?('hash')
        logger.debug2 "upload_res2 = #{upload_res2}"
        logger.debug2 "upload_res2.class = #{upload_res2.class}"
        raise VkontaktePhotoPost.new "upload_res2 = #{upload_res2}"
      end
      if wall and !upload_res2.has_key?('photo') or !wall and !upload_res2.has_key?('photos_list')
        logger.debug2 "upload_res2 = #{upload_res2}"
        logger.debug2 "upload_res2.class = #{upload_res2.class}"
        raise VkontaktePhotoPost.new "upload_res2 = #{upload_res2}"
      end
      # save uploaded photo on wall or in gofreerev album
      # http://vk.com/developers.php?oid=-17680044&p=photos.save
      server = upload_res2['server']
      photo = upload_res2['photo']
      photos_list = upload_res2['photos_list']
      hash = upload_res2['hash']
      description_max_length = 475 - api_gift.deep_link.length - 3 # 400 Bad Request + JSON::ParserError if length > 475
      description = "#{gift.description.first(description_max_length)} - #{api_gift.deep_link}"
      logger.debug2 "description = #{description} (#{description.length})"
      begin
        if wall
          # http://vk.com/developers.php?oid=-17680044&p=photos.saveWallPhoto
          save_res = self.photos.saveWallPhoto :server => server, :photo => photo, :hash => hash
        else
          # http://vk.com/developers.php?oid=-17680044&p=photos.save
          save_res = self.photos.save :aid => aid, :server => server, :photos_list => photos_list, :hash => hash, :caption => description
        end
      rescue exception => e
        raise VkontaktePhotoSave.new "#{e.class}: #{e.message}"
      end
      if save_res.class != Array or save_res.length != 1
        raise VkontaktePhotoSave.new "Expected array with one photo. save_res = #{save_res} (#{save_res.class})"
      end
      logger.debug2 "save_res = #{save_res} (#{save_res.class})"
      logger.debug2 "save_res.length = #{save_res.length})"
      save_res = save_res.first
      if !save_res.has_key?('owner_id') or !save_res.has_key?('pid')
        raise VkontaktePhotoSave.new "Expected hash with owner_id and pid. save_res = #{save_res}"
      end
      # ok response
      api_gift_id = "#{save_res['owner_id']}_#{save_res['pid']}"
      api_gift_url = "#{API_URL[provider]}photo#{api_gift_id}"
      [ api_gift_id, api_gift_url ]
    end # gofreerev_post_on_wall
    # return api client
    api_client
  end # init_api_client_vkontakte

  private
  def init_api_client (provider, token)
    method = "init_api_client_#{provider}".to_sym
    return ['util.do_tasks.init_api_client_missing', :provider => provider] unless private_methods.index(method)
    send(method, token)
  end


  # define grant write links
  # a grant write link is a link that is ajax injected into gifts/index page to request write permission to api wall
  # there must be a grant write link for each api provider where post on wall is implemented
  # link is ajax injected into tasks_errors table in page header
  # injected text should have a mouse over text, a prompt, a grant write link and a hide link
  # normally grant write link is a link to api provider authorize dialog box
  # can also be link to a JS confirm dialog box if read/write privs. are handled within Gofreerev

  # return [key, options] with @errors ajax to grant write access to facebook wall
  # link is injected in tasks_errors table in page header
  private
  def grant_write_link_facebook
    logger.debug2 "start"
    provider = 'facebook'
    oauth = Koala::Facebook::OAuth.new(API_ID[provider], API_SECRET[provider], API_CALLBACK_URL[provider])
    url = oauth.url_for_oauth_code(:permissions => 'status_update', :state => set_state_cookie_store('status_update'))
    hide_url = "/util/hide_grant_write?provider=#{provider}"
    ['.gift_posted_3_html', {:apiname => provider_downcase(provider),
                             :url => url,
                             :provider => provider,
                             :appname => APP_NAME,
                             :hide_url => hide_url}]
  end # grant_write_link_facebook

  # return [key, options] with @errors ajax to grant write access to facebook wall
  # link is injected in tasks_errors table in page header
  private
  def grant_write_link_flickr
    provider = 'flickr'
    # https://github.com/hanklords/flickraw#authentication
    scope = 'write'
    # can not use init_api_client_flickr here
    # we are setting up a new flickr login link with extended permissions
    FlickRaw.api_key = API_ID[:flickr]
    FlickRaw.shared_secret = API_SECRET[:flickr]
    api_client = flickr
    request_token = api_client.get_request_token :oauth_callback => API_CALLBACK_URL[provider]
    logger.debug2 "request_token = #{request_token}"
    url = api_client.get_authorize_url(request_token['oauth_token'], :perms => scope)
    hide_url = "/util/hide_grant_write?provider=#{provider}"
    # save client - client object is used for authorization when/if user returns from flickr with write permission to flickr wall
    # too big for session cookie - to saved in task_data
    save_flickr_api_client(api_client, request_token)
    # ajax inject link in gifts/index page
    ['.gift_posted_3_html', { :appname => APP_NAME,
                              :apiname => provider_downcase(provider),
                              :provider => provider,
                              :url => url,
                              :hide_url => hide_url}]
  end # grant_write_link_flickr

  # return [key, options] with @errors ajax to grant write access to linkedin wall
  # link is injected in tasks_errors table in page header
  private
  def grant_write_link_linkedin
    provider = 'linkedin'
    # http://railscarma.com/blog/rails-3/how-to-use-linkedin-api-in-rails-applications/
    scope = 'r_basicprofile r_network rw_nus'
    # can not use init_api_client_linkedin here
    # we are setting up a new linkedin login link with extended permissions
    api_client = LinkedIn::Client.new API_ID[provider], API_SECRET[provider]
    request_token = api_client.request_token({:oauth_callback => API_CALLBACK_URL[provider]}, :scope => scope)
    api_client.authorize_from_access(request_token.token, request_token.secret)
    url = api_client.request_token.authorize_url
    hide_url = "/util/hide_grant_write?provider=#{provider}"
    # save client - client object is used for authorization when/if user returns from linkedin with write permission to linkedin wall
    # too big for session cookie - to saved in task_data
    save_linkedin_api_client(api_client)
    # ajax inject link in gifts/index page
    ['.gift_posted_3_html', { :appname => APP_NAME,
                              :apiname => provider_downcase(provider),
                              :provider => provider,
                              :url => url,
                              :hide_url => hide_url}]
  end # grant_write_link_linkedin

  # return [key, options] with @errors ajax to grant write access to twitter wall
  # link is injected in tasks_errors table in page header
  # read/write authorization in twitter is a gofreerev concept - omniauth login is with write permission to twitter wall
  private
  def grant_write_link_twitter
    provider = 'twitter'
    url = '/util/grant_write_twitter'
    confirm = t 'util.do_tasks.confirm_grant_write', :apiname => provider_downcase(provider)
    hide_url = "/util/hide_grant_write?provider=#{provider}"

    # ajax inject link in gifts/index page
    return ['util.to_tasks.gift_posted_3b_html',
            { :appname => APP_NAME,
              :apiname => provider_downcase(provider),
              :provider => provider,
              :url => url, :confirm => confirm,
              :hide_url => hide_url}]
  end # grant_write_link_twitter

  # return [key, options] with @errors ajax to grant write access to vkontakte wall
  # link is injected in tasks_errors table in page header
  # read/write authorization in vkontakte is a gofreerev concept - omniauth login is with write permission to vkontakte wall
  private
  def grant_write_link_vkontakte
    provider = 'vkontakte'
    url = '/util/grant_write_vkontakte'
    confirm = t 'util.do_tasks.confirm_grant_write', :apiname => provider_downcase(provider)
    hide_url = "/util/hide_grant_write?provider=#{provider}"

    # ajax inject link in gifts/index page
    return ['util.do_tasks.gift_posted_3b_html',
            { :appname => APP_NAME,
              :apiname => provider_downcase(provider),
              :provider => provider,
              :url => url, :confirm => confirm,
              :hide_url => hide_url}]
  end # grant_write_link_vkontakte

  private
  def grant_write_link (provider)
    # API_GIFT_PICTURE_STORE: nil (no picture/readonly api), :api (use api picture url) or :local (keep local copy of picture)
    return nil unless [:local, :api].index(API_GIFT_PICTURE_STORE[provider])
    method = "grant_write_link_#{provider}".to_sym
    # logger.debug2 "private_methods = #{private_methods.join(', ')}"
    return ['.grant_write_link_missing', :provider => provider, :apiname => provider_downcase(provider)] unless private_methods.index(method)
    key, options = send(method)
    logger.debug2 "key = #{key}, options = #{options}"
    [key, options]
  end # grant_write_link


  # use flash table to prevent CookieOverflow for big flash messages when using session cookie
  # use save_flash before redirect
  # use add_error_key or add_error_text for flash messages in page header without redirect
  private
  def save_flash (key, options = {})
    # delete old flash
    flash_id = session[:flash_id]
    if flash_id
      flash = Flash.find_by_id(flash_id)
      flash.destroy if flash
      session.delete(:flash_id)
    end
    # create new flash
    flash = Flash.new
    flash.message = t key, options
    flash.save!
    session[:flash_id] = flash.id
  end

  private
  def get_flash
    flash_id = session[:flash_id]
    return nil unless flash_id
    flash = Flash.find_by_id(flash_id)
    session.delete(:flash_id)
    return nil unless flash
    message = flash.message
    flash.destroy!
    message
  end
  helper_method :get_flash


  # generic error methods add_error_key, add_error_text, format_response, format_response_key and format_response_text
  # all errors and messages are stored on @errors array with { :id => id, :msg => msg}
  # html request errors and messages are returned in notification div in page header as a "flash" message
  # ajax errors are injected in tasks_errors table in page header or error tables within page (:table option)
  # ( see layouts/application.js.erb and JS method move_tasks_errors2 method (my.js) )
  # add_error_xxx adds error to @errors. format_response_xxx adds any error to @errors and format js or html response
  # note that all ajax calls must set format and datatype: :remote => true, :data => { :type => :script }, :format => :js
  private
  def add_error_key (key, options = {})
    table = options.delete(:table) || 'tasks_errors'
    options[:raise] = I18n::MissingTranslationData if request.xhr? # force stack dump
    @errors << { :msg => t(key, options), :id => table }
    nil
  end

  private
  def add_error_text (text, options = {})
    table = options.delete(:table) || 'tasks_errors'
    @errors << { :msg => text, :id => table }
    nil
  end

  private
  def format_response (key = nil, options = {})
    action = options.delete(:action) if options
    action = params[:action] unless action
    respond_to do |format|
      if request.xhr?
        # fix for ie8/ie9 error:
        #  "to help protect your security internet explorer blocked this site from downloading files to your computer"
        # (x.js.erb response is being downloaded instead of being executed)
        # only a problem in remote forms (new gifts and new comments)
        logger.debug2 "format.js: action = #{action}"
        format.js {render action, :content_type => "text/plain" }
      else
        # delete any old flash
        flash_id = session[:flash_id]
        if flash_id
          flash = Flash.find_by_id(flash_id)
          flash.destroy if flash
          session.delete(:flash_id)
        end
        if @errors.size > 0
          # create new flash
          flash = Flash.new
          flash.message = @errors.collect { |x| x[:msg] }.join('<br>')
          flash.save!
          session[:flash_id] = flash.id
          @errors = []
        end
        format.html unless request.xhr?
      end
    end
    nil
  end # format_response

  private
  def format_response_key (key = nil, options = {})
    add_error_key(key, options) if key
    format_response options
  end # format_response

  private
  def format_response_text (text = nil, options = {})
    add_error_text(text, options) if text
    format_response options
  end # format_response

  # protect cookie information on public web servers
  private
  def ssl_configured?
    FORCE_SSL
  end

  # use @errors array to report ajax errors
  private
  def setup_errors
    # logger.debug2 "request.xhr? = #{request.xhr?}, HTTP_X_REQUESTED_WITH = #{request.headers['HTTP_X_REQUESTED_WITH']}"
    @errors = []
  end

end # ApplicationController

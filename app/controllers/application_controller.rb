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

  # Facebook API information is defined as OS environment variable
  private
  def api_id
    ENV['GOFREEREV_FB_APP_ID']
  end
  helper_method :api_id
  def api_secret
    ENV['GOFREEREV_FB_APP_SECRET']
  end
  helper_method :api_secret

  # render to language specific pages.
  # viewname=create, session[:language] = da => call create-da.html.erb if the page exists
  private
  def render_with_language(viewname)
    language = session[:language]
    # language = BASE_LANGUAGE # todo: remove this line
    puts "render_with_language: language = #{language}"
    if !language or language == BASE_LANGUAGE
      render :action => viewname
      return
    end
    viewname2 = "#{viewname}_#{language}"
    filename = Rails.root.join('app', 'views', controller_name, "#{viewname2}.html.erb").to_s
    puts "render_with_language: filename = #{filename}"
    viewname2 = viewname unless File.exists?(filename)
    render :action => viewname2
  end # render_with_language

  private
  def debug_session (msg)
    [:oauth, :language, :country, :state, :access_token, :user_id].each do |name|
      puts "#{msg}: session[:#{name}] = #{session[name]}"
    end
  end

  private
  # used in page header for currency change
  def request_url_for_header
    @request_fullpath = request.fullpath
  end



  # fetch user info. Used in page heading etc
  private
  def fetch_user
    # language support
    # puts "fetch_user: start. sessionid = #{request.session_options[:id]}"
    I18n.locale = session[:language] if session[:language]
    puts "I18n.locale = #{I18n.locale}"
    # cookie note in page header for the first 30 seconds for a new session
    session[:created] = Time.new unless session[:created]
    @cookie_note = true if Time.new - session[:created] < 30

    # fetch user(s)
    user_ids = session[:user_ids] || []
    if user_ids.length > 0
      @users = User.where("user_id in (?)", user_ids).includes(:friends).shuffle
    else
      @users = []
    end

    # check for deleted users
    if user_ids.length != @users.length
      # remove deleted users from session
      puts "fetch_user. found #{user_ids.length} user(s) in session. found #{@users.length} user(s) in db. Must be deleted users. cleanup session"
      tokens = session[:tokens] || {}
      user_ids = user_ids.find_all do |user_id|
        if !@users.find_all { |user| user.user_id == user_id }.first
          # user found in session but not in database. Must be an old session with a deleted user account
          provider = user_id.split('/').last
          tokens.delete(provider)
          false
        else
          true
        end
      end # find_all
      session[:user_ids] = user_ids
      session[:tokens] = tokens
    end
    # shortcut for @users.first. Random user is selected for a user with multiple provider logins
    @user = @users.first

    # debugging
    if @users.length == 0
      puts "fetch_user: found none logged in users"
    else
      @users.each do |user|
        puts "fetch_user: user_id = #{user.user_id}, user_name = #{user.user_name}, currency = #{user.currency}"
      end
    end

    # todo: check currencies. all logged in users must use same currency

    # add some instance variables
    if @user
      Money.default_currency = Money::Currency.new(@user.currency)
      # Money.default_bank = Money::Bank::GoogleCurrency.new # todo: move to config
      @user_currency_separator = Money::Currency.table[@user.currency.downcase.to_sym][:decimal_mark]
      @user_currency_delimiter = Money::Currency.table[@user.currency.downcase.to_sym][:thousands_separator]
    end
    puts "fetch_user: @user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"

    # get new exchange rates? send to ajax task queue
    add_ajax_task 'ExchangeRate.fetch_exchange_rates', 0 if ExchangeRate.fetch_exchange_rates?
  end # fetch_user


  # check for code from facebook - create/update user
  # fetch user info. Used in page heading etc
  private
  def old_fetch_user
    raise "todo: delete old_fetch_user"
    # language support
    # puts "fetch_user: start. sessionid = #{request.session_options[:id]}"
    I18n.locale = session[:language] if session[:language]
    puts "I18n.locale = #{I18n.locale}"
    # cookie note in page header for the first 30 seconds for a new session
    session[:created] = Time.new unless session[:created]
    @cookie_note = true if Time.new - session[:created] < 30
    # Cross-site Request Forgery check
    if params[:state] != session[:state] and params[:code].to_s != ''
      # Possible Cross-site Request Forgery - ignore code from facebook
      puts "fetch_user: Possible csrf: params[:state] = #{params[:state]}, session[:state] = #{session[:state]}, params[:code] = #{params[:code]}"
      params[:code] = nil
    end

    includes_friends = true
    if params[:code].to_s != '' and session[:oauth]
      # exchange code for access_token
      current_url = "#{request.protocol}#{request.host_with_port}#{request.fullpath}/"

      oauth = session[:oauth]
      # todo: catch
      #       Koala::Facebook::OAuthTokenRequestError in FbController#index
      #       type: OAuthException, code: 100, message: This authorization code has been used. [HTTP 400]
      #       should redirect to /fb/cross_site_forgery page
      # todo: rename cross_site_forgery to login_error
      begin
        access_token = oauth.get_access_token(params[:code])
      rescue Koala::Facebook::ClientError, Koala::Facebook::OAuthTokenRequestError => e
        puts 'fetch_user: Koala::Facebook::ClientError'
        puts "e.fb_error_type = #{e.fb_error_type}"
        puts "e.fb_error_code = #{e.fb_error_code}"
        puts "e.fb_error_subcode = #{e.fb_error_subcode}"
        puts "e.fb_error_message = #{e.fb_error_message}"
        puts "e.http_status = #{e.http_status}"
        puts "e.response_body = #{e.response_body}"
        puts "e.fb_error_type.class.name = #{e.fb_error_type.class.name}"
        puts "e.fb_error_code.class.name = #{e.fb_error_code.class.name}"
        if e.fb_error_type == 'OAuthException' && e.fb_error_code == 100
          reset_session
          redirect_to FB_APP_URL
          return
        else
          raise
        end
      end

      if access_token
        session[:access_token] = access_token

        # authorization ok (first login, following login or return from new priv.dialog)
        # get user id, name, permissions, profile picture and friends

        # 1) create/update user info (name and permissions)
        puts 'fetch_user: get user id and name'
        api = Koala::Facebook::API.new(session[:access_token])
        api_request = 'me?fields=name,permissions,friends,picture,timezone'
        puts "fetch_user: api_request = #{api_request}"
        api_response = api.get_object api_request
        puts "fetch_user: api_response = #{api_response.to_s}"
        user_id = "#{api_response['id']}/facebook"
        user_name = ERB::Util.html_escape(api_response['name'])
        user_name = "#{user_name}"
        puts "fetch_user: user_name = #{user_name} (#{user_name.class.name})"
        u = User.find_by_user_id(user_id)
        u = User.new unless u
        u.user_id = user_id
        u.user_name = user_name
        if api_response['friends']
          u.no_api_friends = api_response['friends']['data'].size
        else
          u.no_api_friends = 0
        end
        u.timezone = api_response['timezone']
        if u.new_record?
          # set currency and balance for new user.
          puts 'fetch_user: new user'
          country = session[:country] || 'US' #  Default USD
          u.currency = Country[country].currency.code
          u.balance = { BALANCE_KEY => 0.0 }
          u.balance_at = Date.today
        end
        u.permissions = api_response['permissions']['data'][0]
        u.permissions = {} if u.permissions == []
        api_profile_picture_url = api_response['picture']['data']['url']
        u.profile_picture_name = (String.generate_random_string(10) + '.' + api_profile_picture_url.split('.').last).last(10).downcase
        u.save!

        # login ok - user created/updated - set session[:user_id]
        puts "fetch_user: login ok: user_id = #{session[:user_id]}"
        session[:user_id] = user_id
        flash[:notice] = t 'gifts.index.welcome_msg_after_login', :appname => APP_NAME, :username => u.short_user_name

        # do not cache friends info - friends info. are sync. after login has finished
        includes_friends = false

        # sync friend information and profile picture download takes some time and is done batch
        # long sync friend is a problem for new gofreerev users with many friends
        User.fork_with_new_connection do

          begin
            # sync friend information after login so that new users with many friends don't have to wait
            sleep(2)

            #necessary to manage activerecord connections since we are forking
            ActiveRecord::Base.connection.reconnect!

            # 2) update friends (insert/delete Friend)
            # compare Friend model data with friends array from API
            # only friends using Gofreerev are relevant
            # friends not using Gofreerev are ignored
            old_friends_list = Friend.where('user_id_giver = ?', u.user_id).includes(:friend)
            if api_response.has_key?('friends')
              api_friends_list = api_response['friends']['data']
            else
              api_friends_list = [] # no api friends
            end
            # merge friend info from db and fb before db update
            friends_hash = {}
            (0..(old_friends_list.size-1)).each do |i|
              old_friend = old_friends_list[i]
              old_friend.friend.user_name = old_friend.friend.user_name.force_encoding('UTF-8')
              user_id = old_friend.user_id_receiver
              friends_hash[user_id] = { :user => old_friend.friend, :old_name => old_friend.friend.user_name, :new_name => old_friend.friend.user_name, :old_api_friend => old_friend.api_friend, :new_api_friend => 'N', :new_record => false }
            end
            api_friends_list.each do |friend|
              user_id = friend["id"] + '/facebook'
              friend["name"] = friend["name"].force_encoding('UTF-8')
              if friends_hash.has_key?(user_id)
                # OK - user already in hash
                nil
              else
                # new facebook friend
                if !(user = User.where("user_id = ?", user_id).first)
                  # create unknown user - create user with minimal user information (user id and name)
                  user = User.new
                  user.user_id = user_id
                  user.user_name = friend["name"]
                  user.save!
                end
                friends_hash[user_id] = { :user => user, :old_name => user.user_name, :old_api_friend => 'N', :new_record => true }
              end
              friends_hash[user_id][:new_name] = friend["name"]
              friends_hash[user_id][:new_api_friend] = 'Y'
            end # each
            # update user names
            friends_hash.each do |user_id, hash|
              next if hash[:old_name] == hash[:new_name]
              # puts "fetch_user: update user names: old name = #{hash[:old_name]}, new name = #{hash[:new_name]}"
              user = hash[:user]
              user.user_name = hash[:new_name].force_encoding('UTF-8')
              user.save!
            end # each
            # update api_fiend
            friends_hash.each do |user_id, hash|
              if hash[:new_record]
                # new friend entries
                # puts "new friend entries"
                Friend.add_friend(session[:user_id], user_id)
              else
                # old friend entry
                # puts "old friend entry, name = #{hash[:new_name]}, old api friend = #{hash[:old_api_friend]}, new api friend = #{hash[:new_api_friend]}"
                next if hash[:old_api_friend] == hash[:new_api_friend] # no change in api friend status
                                                                       # api friend status changed
                f1 = Friend.where("user_id_giver = ? and user_id_receiver = ?", session[:user_id], user_id).first
                f2 = Friend.where("user_id_giver = ? and user_id_receiver = ?", user_id, session[:user_id]).first
                if (f1 == nil or f1.app_friend == nil) and (f2 == nil or f2.app_friend == nil)
                  # Default app_friend status - just delete
                  # puts "Default app_friend status - just delete"
                  Friend.remove_friend(session[:user_id], user_id)
                  next
                end
                                                                       # non default app_friend status - update - do not delete
                if !f1
                  # create missing friend (error)
                  f1 = Friend.new
                  f1.user_id_giver = session[:user_id]
                  f1.user_id_receiver = user_id
                  f1.app_friend = nil
                end
                if !f2
                  # create missing friend (error)
                  f2 = Friend.new
                  f1.user_id_giver = user_id
                  f1.user_id_receiver = session[:user_id]
                  f2.app_friend = nil
                end
                f1.api_friend = f2.api_friend = hash[:new_api_friend]
                                                                       # puts "before save"
                                                                       # puts "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
                                                                       # puts "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
                f1.save!
                f2.save!
                                                                       # puts "after save"
                f1.reload
                f2.reload
                                                                       # puts "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
                                                                       # puts "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
                raise "api_friend status was not updated" unless f1.api_friend == hash[:new_api_friend] and f2.api_friend == hash[:new_api_friend]
              end # if
            end # each
            # update balance
            u.recalculate_balance if u.balance_at != Date.today
          rescue Exception => e
            puts "application_controller: User.fork_with_new_connection"
            puts "Error when post login processing api user info for #{u.user_id} #{u.user_name}"
            puts "Exception: #{e.message.to_s}"
            puts "Backtrace: " + e.backtrace.join("\n")
          end # begin

        end # fork_with_new_connection

        # puts "fetch_user: after fork"

        # 3) download profile picture
        FileUtils.mkdir_p u.profile_picture_os_folder
        system("wget #{api_profile_picture_url} -O #{u.profile_picture_os_filename}")

      end
      params[:code] = nil
      session.delete(:oauth)
    end

    # fetch user after create/update
    if session[:user_id]
      if includes_friends
        @user = User.where("user_id = ?", session[:user_id]).includes(:friends).first
      else
        # new login - sync friend info can take some time
        @user = User.where("user_id = ?", session[:user_id]).first
      end
    end

    if @user
      puts "fetch_user: user_id = #{@user.user_id}, user_name = #{@user.user_name}"
    else
      puts "fetch_user: user with user_id #{session[:user_id]} was not found"
    end

    # add some instance variables
    if @user
      session[:provider] = @user.provider
      Money.default_currency = Money::Currency.new(@user.currency)
      # Money.default_bank = Money::Bank::GoogleCurrency.new # todo: move to config
      @user_currency_separator = Money::Currency.table[@user.currency.downcase.to_sym][:decimal_mark]
      @user_currency_delimiter = Money::Currency.table[@user.currency.downcase.to_sym][:thousands_separator]
    else
      session[:provider] = nil
    end
    puts "fetch_user: @user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"

    # get new exchange rates? send to ajax task queue
    add_ajax_task 'ExchangeRate.fetch_exchange_rates', 0 if ExchangeRate.fetch_exchange_rates?
  end # old_fetch_user


  private
  def set_locale
    I18n.locale = session[:language] || I18n.default_locale
  end

  private
  def login_required
    return true if session[:user_id]
    flash[:notice] = t 'gifts.index.not_logged_in_flash'
    redirect_to :controller => :gifts, :action => :index
  end # login_required

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
  # see js functions check_api_picture_url and report_missing_api_picture_urls
  private
  def get_missing_api_picture_urls
    return nil unless @user
    api_gifts = ApiGift.where("(user_id_giver = ? or user_id_receiver = ?) and api_picture_url_on_error_at is not null and (deleted_at_api is null or deleted_at_api = 'N')",
                       @user.user_id, @user.user_id)
    api_gifts.delete_if do |api_gift|
      user_id_created_by = api_gift.api_gift_id.split('_')[0] + '/facebook'
      (user_id_created_by != @user.user_id)
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
    raise "get_next_set_of_rows: session[:last_row_id] was not found" unless  session[:last_row_id]
    raise "get_next_set_of_rows: session[:last_row_at] was not found" unless  session[:last_row_at]
    # max one get-more-rows request once every GET_MORE_ROWS_INTERVAL seconds
    new_last_row_at = Time.new.to_f
    dif = new_last_row_at - session[:last_row_at]
    if last_row_id != session[:last_row_id]
      # wrong last_row_id received in get-more-rows ajax request. Must be an error a javascript/ajax error
      msg = "get_next_set_of_rows. problem with get-more-rows ajax request. expected #{session[:last_row_id]}. found #{last_row_id}."
      if debug_ajax?
        raise msg
      else
        puts msg
      end
      # return dummy row with correct last_row_id to client x
      return true
    elsif dif < GET_MORE_ROWS_INTERVAL - 1
      # client should only send get-more-rows once every GET_MORE_ROWS_INTERVAL seconds. Must be an javascript/ajax error.
      # it should be client that waits between get-more-rows ajax requests - not server
      # todo: problem with GET_MORE_ROWS_INTERVAL delay in javascript and in rails.
      #       dif < GET_MORE_ROWS_INTERVAL gives too many "Max one get-more-rows ajax request" errors
      #       javascript code in /shared/show_more_rows partial. 3 seconds wait in JS and in rails should work
      msg = "get_next_set_of_rows. Max one get-more-rows ajax request every #{GET_MORE_ROWS_INTERVAL} seconds. session[:last_row_at_debug] = #{session[:last_row_at_debug]}. Time.new = #{Time.new}. Wait for #{GET_MORE_ROWS_INTERVAL-dif} seconds"
      if debug_ajax?
        puts msg
        puts msg
        puts msg
      else
        puts msg
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
    puts "last_row_id = #{last_row_id}"
    ajax_request = (last_row_id != nil)
    no_rows = ajax_request ? 10 : 1 unless no_rows # default - return 1 row in first http request - return 10 rows in ajax requests
    total_no_rows = rows.size
    if ajax_request
      # ajax request
      # check if last_row_id is valid - row could have been deleted between two requests
      # puts "ajax request - check if last_row_id still is valid"
      from = rows.index { |u| u.last_row_id == last_row_id }
      if !from
        puts "invalid last_row_id - or row is no longer in rows - ignore error and return first 10 rows"
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
    puts "get_next_set_of_rows: returning next #{rows.size} of #{total_no_rows} rows . last_row_id = #{last_row_id}"
    # keep last_row_id and timestamp - checked in get_next_set_of_rows_error? before calling this method
    session[:last_row_id] = last_row_id # control - is checked in next ajax request
    session[:last_row_at] = Time.new.to_f
    session[:last_row_at_debug] = Time.new
    puts "last_row_at_debug = #{session[:last_row_at_debug]}"
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

  private
  def valid_provider? (provider)
    OmniAuth::Builder.providers.index(provider)
  end
  helper_method "valid_provider?"

  private
  def my_provider (provider)
    return provider if !valid_provider?(provider) # unknown provider or already translated
    t "shared.providers.#{provider}"
  end
  helper_method :my_provider

  private
  def add_ajax_task (task, priority=5)
    AjaxTask.add_task(session[:session_id], task, priority)
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

  # do same post login tasks - save user and token in session hash and schedule ajax tasks




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
    # create/update user from information received from login provider
    # returns user (ok) or an array with translate key and options for error message
    user = User.find_or_create_user :provider => provider,
                                    :token => token,
                                    :uid => uid,
                                    :name => name,
                                    :image => image,
                                    :country => country,
                                    :language => language
    return user unless user.class == User
    # user login ok
    # save user and access token - multiple login allows - one for each login provider
    timezone = params[:timezone]
    user_ids = session[:user_ids] || []
    user_ids.delete_if { |user_id2| user_id2.split('/').last == provider }
    user_ids << user.user_id
    tokens = session[:tokens] || {}
    tokens[provider] = token
    session[:user_ids] = user_ids
    session[:tokens] = tokens
    # save language for translate
    session[:language] = language if language
    # schedule post login ajax tasks
    # todo: validate timezone. Must be a valid number between ...
    add_ajax_task "User.update_timezone('#{user.user_id}', #{timezone})" if timezone # timezone from client/javascript
    add_ajax_task "User.download_profile_image('#{user.user_id}', '#{image}')" if image =~ /^http/ and !image.index("''")
    post_login_task_provider = "post_login_#{provider}" # private method in UtilController
    if UtilController.new.private_methods.index(post_login_task_provider.to_sym)
      add_ajax_task post_login_task_provider
    else
      puts "Warning. No post login task was found for #{provider}. No #{provider} friend information will be downloaded"
    end
    # currencies for logged in users must be identical
    if user_ids.length > 1
      currencies = User.where('user_id in (?)', user_ids).collect { |user2| user2.currency }.uniq
      add_ajax_task 'post_login_fix_currency' if currencies.length > 1
    end
    nil
  end # login

  def logout (provider=nil)
    if !provider
      session.delete(:user_ids)
      session.delete(:tokens)
      return
    end
    user_ids = session[:user_ids] || []
    user_ids.delete_if { |user_id| user_id.split('/').last == provider}
    tokens = session[:tokens]
    tokens.delete(provider)
    session[:user_ids] = user_ids
    session[:tokens] = tokens
  end # logout


  # protection from Cross-site Request Forgery
  # state is set before calling login provider
  # state is checked when returning from login provider
  def set_state (context)
    state = session[:state].to_s
    state = session[:state] = String.generate_random_string(30) unless state.length == 30
    "#{state}-#{context}"
  end
  def clear_state
    session.delete(:state)
  end
  def invalid_state?
    state = params[:state].to_s
    return true unless state =~ /^[a-zA-Z0-9]{30}-/
    return true unless state.length > 31
    return true unless session[:state].to_s == state.first(30)
    false
  end


end # ApplicationController

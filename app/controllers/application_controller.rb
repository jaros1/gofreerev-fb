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
      from = rows.index { |u| u.id == last_row_id }
      if !from
        puts "invalid last_row_id - or row is no longer in rows - ignore error and return first 10 rows"
        last_row_id = nil
      end
      last_row_id = nil unless from # invalid last_row_id - deleted row or changed permissions - ignore error and return first 10 rows
    end
    rows = rows[from+1..-1] if from # valid ajax request - ignore first from rows - already in client page
    if rows.size > no_rows
      rows = rows.first(no_rows)
      last_row_id = rows.last.id # return next 10 rows in next ajax request
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

end # ApplicationController

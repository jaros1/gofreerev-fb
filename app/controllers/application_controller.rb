# encoding: utf-8
require 'money/bank/google_currency'
require File.join(Rails.root, "lib/gofreerev_extensions.rb")

#noinspection RubyResolve
class ApplicationController < ActionController::Base

  include GofreerevExtensions

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
    # language = 'en' # todo: remove this line
    puts "render_with_language: language = #{language}"
    if !language or language == 'en'
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



  # check for code from FB - create/update user
  # fetch user info. Used in page heading etc
  private
  def fetch_user
    # language support
    puts "fetch_user: start"
    I18n.locale = session[:language] if session[:language]
    puts "I18n.locale = #{I18n.locale}"
    # Cross-site Request Forgery check
    if params[:state] != session[:state] and params[:code].to_s != ''
      # Possible Cross-site Request Forgery - ignore code from FB
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
        user_id = "#{User.facebook_user_prefix}#{api_response['id']}"
        user_name = ERB::Util.html_escape(api_response['name'])
        user_name = "#{user_name}"
        puts "fetch_user: user_name = #{user_name} (#{user_name.class.name})"
        u = User.find_by_user_id(user_id)
        u = User.new unless u
        u.user_id = user_id
        u.user_name = user_name
        u.no_api_friends = api_response['friends']['data'].size
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

        # do not cache friends info - friends info. are sync. after login has finished
        includes_friends = false

        # sync friend information and profile picture download takes some time and is done batch
        # long sync friend is a problem for new gofreerev users with many friends
        User.fork_with_new_connection do

          # sync friend information after login so that new users with many friends don't have to wait
          sleep(2)

          #necessary to manage activerecord connections since we are forking
          ActiveRecord::Base.connection.reconnect!

          # 2) update friends (insert/delete Friend)
          # compare Friend model data with friends array from API
          # only friends using Gofreerev are relevant
          # friends not using Gofreerev are ignored
          # todo: batch update for new users with many friends
          old_friends_list = Friend.where('user_id_giver = ?', u.user_id).includes(:friend)
          api_friends_list = api_response['friends']['data']
          # merge friend info from db and fb before db update
          friends_hash = {}
          (0..(old_friends_list.size-1)).each do |i|
            old_friend = old_friends_list[i]
            old_friend.friend.user_name = old_friend.friend.user_name.force_encoding('UTF-8')
            user_id = old_friend.user_id_receiver
            friends_hash[user_id] = { :user => old_friend.friend, :old_name => old_friend.friend.user_name, :new_name => old_friend.friend.user_name, :old_api_friend => old_friend.api_friend, :new_api_friend => 'N', :new_record => false }
          end
          api_friends_list.each do |friend|
            user_id = User.facebook_user_prefix + friend["id"]
            friend["name"] = friend["name"].force_encoding('UTF-8')
            if friends_hash.has_key?(user_id)
              # OK - user already in hash
              nil
            else
              # new FB friend
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
            puts "fetch_user: update user names: old name = #{hash[:old_name]}, new name = #{hash[:new_name]}"
            user = hash[:user]
            user.user_name = hash[:new_name].force_encoding('UTF-8')
            user.save!
          end # each
          # update api_fiend
          friends_hash.each do |user_id, hash|
            if hash[:new_record]
              # new friend entries
              Friend.add_friend(session[:user_id], user_id)
            else
              # old friend entry
              next if hash[:old_api_friend] == hash[:new_api_friend] # no change in api friend status
              # api friend status changed
              f1 = Friend.where("user_id_giver = ? and user_id_receiver = ?", session[:user_id], user_id).first
              f2 = Friend.where("user_id_giver = ? and user_id_receiver = ?", user_id, session[:user_id]).first
              if (f1 == nil or f1.app_friend == nil) and (f2 == nil or f2.app_friend == nil)
                # Default app_friend status - just delete
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
                f2.user_id_giver = session[:user_id]
                f2.api_friend = user_id
                f2.app_friend = nil
              end
              f1.api_friend = f2.api_friend = hash[:new_api_friend]
              transaction do
                f1.save!
                f2.save!
              end # transaction
            end # if
          end # each

        end # fork_with_new_connection

        puts "fetch_user: after fork"

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
      @usertype = session[:usertype] = @user.usertype
      Money.default_currency = Money::Currency.new(@user.currency)
      # Money.default_bank = Money::Bank::GoogleCurrency.new # todo: move to config
      @user_currency_separator = Money::Currency.table[@user.currency.downcase.to_sym][:decimal_mark]
      @user_currency_delimiter = Money::Currency.table[@user.currency.downcase.to_sym][:thousands_separator]
    else
      @usertype = session[:usertype] = nil
    end
    puts "fetch_user: @user_currency_separator = #{@user_currency_separator}, @user_currency_delimiter = #{@user_currency_delimiter}"
  end # fetch_user



  private
  def set_locale
    I18n.locale = session[:language] || I18n.default_locale
  end


  private
  def login_required
    return true if session[:user_id]
    flash[:notice] = my_t 'gifts.index.not_logged_in_flash'
    redirect_to :controller => :gifts, :action => :index
  end # login_required


end # ApplicationController

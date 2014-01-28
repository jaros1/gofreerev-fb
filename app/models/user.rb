# require 'open4'

class User < ActiveRecord::Base

  FRIEND_REQUEST_NOTI_KEY = 'request_for_app_friendship_v1'
=begin
  create_table "users", force: true do |t|
    t.string   "user_id",    limit: 20
    t.text     "user_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "currency"
    t.text     "balance"
    t.date     "balance_at"
  end
=end


  # relations
  has_many :offers, :class_name => 'ApiGift', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :wishes, :class_name => 'ApiGift', :primary_key => :user_id, :foreign_key => :user_id_receiver, :dependent => :destroy
  has_many :friends, :class_name => 'Friend', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :sent_notifications, :class_name => 'Notification', :primary_key => :user_id, :foreign_key => :from_user_id, :dependent => :destroy
  has_many :received_notifications, :class_name => 'Notification', :primary_key => :user_id, :foreign_key => :to_user_id, :dependent => :destroy
  has_many :comments, :class_name => 'Comment', :primary_key => :user_id, :foreign_key => :user_id, :dependent => :destroy
  has_many :gift_likes, :class_name => 'GiftLike', :primary_key => :user_id, :foreign_key => :user_id, :dependent => :destroy


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  crypt_keeper :user_name, :currency, :balance, :permissions, :no_api_friends, :negative_interest,
               :api_profile_url, :api_profile_picture_url, :encryptor => :aes, :key => ENCRYPT_KEYS[0]


  ##############
  # attributes #
  ##############

  # 1) user_id. required unique USER id, fx. 1234567890/facebook. Not encrypted. PK and user in encryption
  validates_presence_of :user_id
  attr_readonly :user_id
  def user_id=(new_user_id)
    return self['user_id'] if self['user_id']
    self['user_id'] = new_user_id
  end # user_id=

  # 2) user_name. User name. String in model. Encrypted text in db. required. is updated when the user logs in.
  validates_presence_of :user_name
  def user_name
    return nil unless (extended_user_name = read_attribute(:user_name))
    encrypt_remove_pre_and_postfix(extended_user_name, 'user_name', 9)
  end # user_name
  def user_name=(new_user_name)
    if new_user_name
      # logger.debug2  "new_user_name = #{new_user_name} (#{new_user_name.class.name})"
      check_type('user_name', new_user_name, 'String')
      write_attribute :user_name, encrypt_add_pre_and_postfix(new_user_name, 'user_name', 9)
    else
      write_attribute :user_name, nil
    end
  end # user_name=
  alias_method :user_name_before_type_cast, :user_name
  def user_name_was
    return user_name unless user_name_changed?
    return nil unless (extended_user_name = attribute_was(:user_name))
    encrypt_remove_pre_and_postfix(extended_user_name, 'user_name', 9)
  end # user_name_was

  # 3) currency. Required. String in model. Encrypted text in db.
  # validates_presence_of :currency # todo: only required for gofreerev users / not required for friends not using gofreerev
  def currency
    return nil unless (extended_currency = read_attribute(:currency))
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 10)
  end
  def currency=(new_currency)
    if new_currency
      check_type('currency', new_currency, 'String')
      write_attribute :currency, encrypt_add_pre_and_postfix(new_currency, 'currency', 10)
    else
      write_attribute :currency, nil
    end
  end # currency
  alias_method :currency_before_type_cast, :currency
  def currency_was
    return currency unless currency_changed?
    return nil unless (extended_currency = attribute_was(:currency))
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 10)
  end # currency_was

  # 4) balance. Balance. Required. Multi-currency Hash in model. Encrypted text in db
  # Keys is ISO code for currency USD, EUR, GBP etc.
  # Key BALANCE is sum of all currencies exchanged to users actual currency
  # validates_presence_of :balance # todo: only required for gofreerev users / not required for friends not using gofreerev
  def balance
    return nil unless (temp_extended_balance = read_attribute(:balance))
    # logger.debug2  "temp_extended_balance = #{temp_extended_balance}"
    temp_balance = YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance, 'balance', 11)
    temp_balance[BALANCE_KEY] = nil unless temp_balance.has_key?(BALANCE_KEY)
    temp_balance
  end # balance
  def balance=(new_balance)
    if new_balance
      check_type('balance', new_balance, 'Hash')
      write_attribute :balance, encrypt_add_pre_and_postfix(new_balance.to_yaml, 'balance', 11)
    else
      write_attribute :balance, nil
    end
  end # balance=
  alias_method :balance_before_type_cast, :balance
  def balance_was
    return balance unless balance_changed?
    return nil unless (temp_extended_balance = attribute_was(:balance))
    temp_balance = YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance, 'balance', 11)
    temp_balance[BALANCE_KEY] = nil unless temp_balance.has_key?(BALANCE_KEY)
    temp_balance
  end # balance_was

  # 5) balance_at. Date. Not encrypted. Date for last balance calculation. Normally today.
  # validates_presence_of :balance_at # todo: only required for gofreerev users / not required for friends not using gofreerev

  # 6) permissions. Optional. Any Ruby type in model (hash with privs. for facebook users). Encrypted text in db
  # facebook: hash with grants privs {"installed"=>1, "basic_info"=>1, "bookmarked"=>1}
  # google+: empty - readonly api - any priv. error will be reported at login
  # linkedin: r_basicprofile,r_network (default/first login) or r_basicprofile,r_network,rw_nus (second login with rw_nus priv)
  # google+: todo
  # permissions is fetched at login and checked before operations (post to api wall)
  def permissions
    return nil unless (extended_permissions = read_attribute(:permissions))
    YAML::load(encrypt_remove_pre_and_postfix(extended_permissions, 'permissions', 12))
  end # permissions
  def permissions=(new_permissions)
    if new_permissions
      write_attribute :permissions, encrypt_add_pre_and_postfix(new_permissions.to_yaml, 'permissions', 12)
    else
      write_attribute :permissions, nil
    end
  end # permissions
  alias_method :permissions_before_type_cast, :permissions
  def permissions_was
    return permissions unless permissions_changed?
    return nil unless (extended_permissions = attribute_was(:permissions))
    YAML::load(encrypt_remove_pre_and_postfix(extended_permissions, 'permissions', 12))
  end # permissions_was
  
  # 7) no_api_friends. Fixnum in Model. Encrypted text in db.
  # for example number of facebook friends for a facebook user
  def no_api_friends
    return nil unless (temp_extended_no_api_friends = read_attribute(:no_api_friends))
    encrypt_remove_pre_and_postfix(temp_extended_no_api_friends, 'no_api_friends', 13).to_i
  end # balance
  def no_api_friends=(new_no_api_friends)
    if new_no_api_friends
      check_type('no_api_friends', new_no_api_friends, 'Fixnum')
      write_attribute :no_api_friends, encrypt_add_pre_and_postfix(new_no_api_friends.to_s, 'no_api_friends', 13)
    else
      write_attribute :no_api_friends, nil
    end
  end # balance=
  alias_method :no_api_friends_before_type_cast, :no_api_friends
  def no_api_friends_was
    return no_api_friends unless no_api_friends_changed?
    return nil unless (temp_extended_no_api_friends = attribute_was(:no_api_friends))
    encrypt_remove_pre_and_postfix(temp_extended_no_api_friends, 'no_api_friends', 13).to_i
  end # no_api_friends_was

  # 10) negative_interest. Required. Multi-currency Hash in model. Encrypted text in db
  # Keys is ISO code for currency USD, EUR, GBP etc.
  # Key BALANCE is sum of all currencies exchanged to users actual currency
  # validates_presence_of :negative_interest # todo: uncomment this
  def negative_interest
    return nil unless (temp_ext_neg_interest = read_attribute(:negative_interest))
    # logger.debug2  "temp_ext_neg_interest = #{temp_ext_neg_interest}"
    temp_negative_interest = YAML::load encrypt_remove_pre_and_postfix(temp_ext_neg_interest, 'negative_interest', 14)
    temp_negative_interest[BALANCE_KEY] = nil unless temp_negative_interest.has_key?(BALANCE_KEY)
    temp_negative_interest
  end # negative_interest
  def negative_interest=(new_neg_int)
    if new_neg_int
      check_type('negative_interest', new_neg_int, 'Hash')
      write_attribute :negative_interest, encrypt_add_pre_and_postfix(new_neg_int.to_yaml, 'negative_interest', 14)
    else
      write_attribute :negative_interest, nil
    end
  end # negative_interest=
  alias_method :negative_interest_before_type_cast, :negative_interest
  def negative_interest_was
    return negative_interest unless negative_interest_changed?
    return nil unless (temp_ext_neg_interest = attribute_was(:negative_interest))
    temp_negative_interest = YAML::load encrypt_remove_pre_and_postfix(temp_ext_neg_interest, 'negative_interest', 14)
    temp_negative_interest[BALANCE_KEY] = nil unless temp_negative_interest.has_key?(BALANCE_KEY)
    temp_negative_interest
  end # negative_interest_was

  # 11) user_combination - unencrypted integer - connect user balance across login providers
  
  # 12) api_profile_url - user profile url - used for some API's with special url not derived from uid - for example linkedin
  # String in model - Encrypted text in db
  def api_profile_url
    return nil unless (temp_api_profile_url = read_attribute(:api_profile_url))
    # logger.debug2  "temp_api_profile_url = #{temp_api_profile_url}"
    encrypt_remove_pre_and_postfix(temp_api_profile_url, 'api_profile_url', 39)
  end # api_profile_url
  def api_profile_url=(new_api_profile_url)
    if new_api_profile_url
      check_type('api_profile_url', new_api_profile_url, 'String')
      write_attribute :api_profile_url, encrypt_add_pre_and_postfix(new_api_profile_url, 'api_profile_url', 39)
    else
      write_attribute :api_profile_url, nil
    end
  end # api_profile_url=
  alias_method :api_profile_url_before_type_cast, :api_profile_url
  def api_profile_url_was
    return api_profile_url unless api_profile_url_changed?
    return nil unless (temp_api_profile_url = attribute_was(:api_profile_url))
    encrypt_remove_pre_and_postfix(temp_api_profile_url, 'api_profile_url', 39)
  end # api_profile_url_was

  # 12) api_profile_picture_url - url to user profile picture
  # picture store for profile pictures is either :api or :local. See array constant API_PROFILE_PICTURE_STORE
  # String in model - Encrypted text in db
  def api_profile_picture_url
    return nil unless (temp_api_profile_picture_url = read_attribute(:api_profile_picture_url))
    # logger.debug2  "temp_api_profile_picture_url = #{temp_api_profile_picture_url}"
    encrypt_remove_pre_and_postfix(temp_api_profile_picture_url, 'api_profile_picture_url', 40)
  end # api_profile_picture_url
  def api_profile_picture_url=(new_api_profile_picture_url)
    if new_api_profile_picture_url
      check_type('api_profile_picture_url', new_api_profile_picture_url, 'String')
      write_attribute :api_profile_picture_url, encrypt_add_pre_and_postfix(new_api_profile_picture_url, 'api_profile_picture_url', 40)
    else
      write_attribute :api_profile_picture_url, nil
    end
  end # api_profile_picture_url=
  alias_method :api_profile_picture_url_before_type_cast, :api_profile_picture_url
  def api_profile_picture_url_was
    return api_profile_picture_url unless api_profile_picture_url_changed?
    return nil unless (temp_api_profile_picture_url = attribute_was(:api_profile_picture_url))
    encrypt_remove_pre_and_postfix(temp_api_profile_picture_url, 'api_profile_picture_url', 40)
  end # api_profile_picture_url_was
  
  # 13) post_on_wall_yn - allow post on api wall - default is Y unless readonly API (google+)
  # string in model and db
  validates_presence_of :post_on_wall_yn
  validates_inclusion_of :post_on_wall_yn, :allow_blank => true, :in => %w(Y N)
  
  # change currency in page header.
  attr_accessor :new_currency

  # cache inbox_new_notifications in @users.first - do not look up number of new notifications twice
  attr_accessor :cache_new_notifications


  ##################
  # helper methods #
  ##################

  ## removed - used for migration from old to new user ids
  #def self.new_user_id (old_user_id)
  #  return nil unless old_user_id
  #  old_prefix = old_user_id.first(2)
  #  uid = old_user_id.from(3)
  #  provider = case old_prefix
  #                  when 'fb' then 'facebook'
  #                  when 'gp' then 'google'
  #                  when 'li' then 'linkedin'
  #                  when 'tw' then 'twitter'
  #                end # case
  #  "#{uid}/#{provider}"
  #end # self.new_user_i
  #def self.old_user_id (new_user_id)
  #  return nil unless new_user_id
  #  provider = new_user_id.split("/").last
  #  uid = new_user_id.first(new_user_id.size-provider.size-1)
  #  prefix = case provider
  #             when 'facebook' then 'fb-'
  #             when 'google' then 'gp-'
  #             when 'linkedin' then 'li-'
  #             when 'twitter' then 'tw-'
  #           end
  #  "#{prefix}#{uid}"
  #end # self.new_user_i

  # for ajax show-more-rows functionality
  public
  def last_row_id
    id
  end


  public
  def self.open4 (command, dir = nil)
    pid, stdin, stdout, stderr = Open4::popen4 "sh"
    stdin.puts  "cd #{dir}" if dir
    stdin.puts  command
    stdin.close
    ignored, status = Process::waitpid2 pid
    return [ stdout.read, stderr.read, status.exitstatus ]
  end # open4


  # list of valid providers from /config/initializers/omniauth.rb
  def self.valid_provider? (provider)
    OmniAuth::Builder.providers.index(provider.to_s)
  end


  def self.find_or_create_dummy_user (provider)
    user_id = "gofreerev/#{provider}"
    user = User.find_by_user_id(user_id)
    return user if user
    user = User.new
    user.user_id = user_id
    if provider =~ /^google/
      user.user_name = "#{APP_NAME} Google"
    else
      user.user_name = "#{APP_NAME} #{provider.camelize}"
    end
    user.currency = BASE_CURRENCY
    # user.profile_picture_name = "#{provider}.png"
    user.api_profile_picture_url = "#{SITE_URL}/images/#{provider}.png".gsub('//images', '/images')
    user.balance = { BALANCE_KEY => 0.0 }
    user.post_on_wall_yn = 'N'
    user.save!
    user
  end # self.find_or_create_dummy_user


  # find and create or update user from hash
  # options: :provider, :token, :uid, :name, :image, :country, :language
  # called from login methods (authController.create, FbController.index, etc)
  # returns user if ok
  # returns key or key + options if not ok (for translate)
  def self.find_or_create_user (options)
    # missing provider, unknown provider, missing token, uid or user_name are fatal errors.
    provider = options[:provider].to_s
    return '.callback_provider_missing' if provider == ""
    return ['.callback_unknown_provider', { :provider => provider } ] unless User.valid_provider?(provider)
    token = options[:token].to_s
    return ['.callback_token_missing', { :provider => provider } ] if token == ""
    uid = options[:uid].to_s
    return ['.callback_uid_missing', { :provider => provider }] if uid == ""
    return ['.callback_gofreerev_uid', { :provider => provider }] if uid == 'gofreerev' # reserved uid used for dummy users
    user_name = options[:name].to_s
    # todo: should escape username - ERB::Util.html_escape(user_name) does not work from activemodel
    return '.callback_user_name_missing_google' if user_name == "" and provider.first(6) == 'google'
    return ['.callback_user_name_missing',  { :provider => provider } ] if user_name == ""
    # missing profile image is a minor problem - only check here - profile image information is updated in a post login task
    # facebook: profile image from omniauth login is not used (wrong dimensions) -
    #           profile image from koala request in post_login_facebook is used
    image = options[:image].to_s
    logger.debug2 "no profile picture received from login provider #{provider}" if image == "" and provider != 'facebook'
    logger.debug2 "profile image url #{image}" unless image == ""
    # missing or invalid profile url is a minor problem
    profile_url = options[:profile_url].to_s
    if profile_url == ""
      logger.debug2 "no profile url was received from login provider #{provider}"
      profile_url = nil
    elsif profile_url !~ /^https?/
      logger.debug2 "invalid profile url '#{profile_url}' was received from login provider #{provider}"
      profile_url = nil
    end
    user_id = "#{uid}/#{provider}"
    user = User.find_by_user_id(user_id)
    user = User.new unless user
    user.user_id = user_id
    user.user_name = user_name
    # setup efault permissions after login (read = read user profile and friends information)
    case
      when provider == 'facebook'
        # facebook permissions is returned in koala api request me?fields=permissions in util.post_login_facebook
        # facebook permissions is also updated in facebook/index when user returns with status_update or read_stream permission from facebook
        nil
      when API_DEFAULT_PERMISSIONS[provider].to_s != ''
        # use default permission setup from /config/initializers/omniauth.rb
        # - update_status and read_stream is requested after login if required
        # linkedin:
        # - starts with r_basicprofile,r_network.
        # - is changed in linkedin controller to r_basicprofile,r_network,rw_nus when user returns with rw_nus priv from linkedin
        # google+: always read - readonly api
        # twitter: authorization with write, but only read is used until user allows post on twitter
        user.permissions = API_DEFAULT_PERMISSIONS[provider]
      else
        user.permissions = 'read'
        logger.warn2 "Default permission setup is missing for #{provider}."
        logger.warn2 "plase check API_DEFAULT_PERMISSIONS in /config/initializers/omniauth.rb"
    end # case
    user.api_profile_url = profile_url if profile_url
    if user.new_record?
      # initialize currency from country - for example google and twitter
      country_code = options[:country].to_s
      if country_code == ''
        # provider dod not return country code (google and twitter).
        # Try to get country code from language code
        language_code = options[:language].to_s
        countries = []
        Country.countries.each do |a|
          country_code2 = a[1]
          country2 = Country[country_code2]
          countries << country_code2 if country2.languages.index(language_code)
        end unless language_code == ""
        if countries.size == 1
          country_code = countries.first
        else
          country_code = BASE_COUNTRY
        end
      end # inner if
      c = Country[country_code]
      if !c
        currency = BASE_CURRENCY
      else
        currency = c.currency.code
      end
      active_currencies = ExchangeRate.active_currencies
      currency = BASE_CURRENCY if active_currencies.size > 0 and !active_currencies.index(currency)
      user.currency = currency
      user.balance = { BALANCE_KEY => 0.0 }
      user.balance_at = Date.parse(Sequence.get_last_exchange_rate_date)
      user.post_on_wall_yn = API_POST_PERMITTED[provider] ? 'Y' : 'N'
    end # outer if
    user.save!
    # check/add dummy friend row for user (user_id_giver == user_id_receiver)
    friend = Friend.where('user_id_giver = ? and user_id_receiver = user_id_giver', user.user_id).first
    if !friend
      friend = Friend.new
      friend.user_id_giver = user.user_id
      friend.user_id_receiver = user.user_id
    end
    friend.api_friend = 'Y'
    friend.app_friend = nil
    friend.save!
    # cleanup any old flash message - there should never be any
    Flash.where("created_at < ?", 1.minute.ago).delete_all
    # user find/create ok - continue with login
    user
  end # find_or_create_user


  # task from task queue - download and save profile picture from provider after login
  # called from util.do_tasks after login process has completed
  # return nil if ok
  # return array with translate key and options if warning or error
  def self.update_profile_image (user_id, url)
    begin
      user = User.find_by_user_id(user_id)
      if !user
        logger.error2 "error: invalid user id"
        return ['.profile_image_invalid_user', {:user_id => user_id}]
      end
      return nil if user.deleted_at # ignore deleted marked users
      if url.to_s == ""
        logger.warn2 "error: no image received from provider / post_login ajax request"
        return ['.profile_image_blank', {:provider => user.provider}]
      end
      if url !~ /https?\:\/\//
        logger.warn2 "error: invalid image #{url} received from provider / post_login ajax request"
        return ['.profile_image_invalid_url', {:provider => user.provider, :image => url}]
      end
      # check image type
      image_type = FastImage.type(url).to_s
      if image_type.to_s == ''
        logger.error2 "profile picture url #{url} with blank image type. provider #{user.provider}"
        return ['.profile_image_invalid_type', {:provider => user.provider, :image => url, :image_type => image_type}]
      end
      if !%w(gif jpeg png jpg bmp).index(image_type)
        logger.error2 "profile picture url #{url} with unsupported image type #{image_type}. provider #{user.provider}"
        return ['.profile_image_invalid_type', {:provider => user.provider, :image => url, :image_type => image_type}]
      end
      # check image store for profile pictures (:api or :local)
      picture_store = API_PROFILE_PICTURE_STORE[user.provider] || :api
      if picture_store == :api
        # preferred choice - profile pictures not downloaded - use profile picture url from provider as it is
        Picture.delete_if_app_url(user.api_profile_picture_url)
        user.api_profile_picture_url = url
        user.update_attribute('api_profile_picture_url', user.api_profile_picture_url) if user.api_profile_picture_url_changed?
        return nil
      end
      if picture_store != :local
        logger.fatal2 "unknown profile picture store #{picture_store} for login provider #{user.provider}"
        logger.fatal2 "please check array constant API_PROFILE_PICTURE_STORE (/config/initializers/omniauth.rb"
        return ['.profile_image_unsupported_store', {:provider => user.provider}]
      end

      # download profile pictures from server to local picture store

      if user.api_profile_picture_url
        # ignore old api profile picture url - will be replaced with an app profile picture url after download
        user.api_profile_picture_url = nil unless Picture.app_url?(user.api_profile_picture_url)
      end
      old_image_type = Picture.find_picture_type(user.api_profile_picture_url) if user.api_profile_picture_url
      # 3 cases:
      #  1) first profile picture download (new path)
      #  2) profile picture with unchanged image type (unchanged path - overwrite old picture)
      #  3) profile picture with new image type (changed path - delete old picture and download new picture)
      if !user.api_profile_picture_url or old_image_type != image_type
        # case 1) and 3) get new picture location
        case_no = user.api_profile_picture_url ? 3 : 1
        old_api_profile_picture_url = user.api_profile_picture_url
        rel_path = Picture.new_perm_rel_path image_type
      else
        # case 2) reuse old picture location
        rel_path = Picture.rel_path(user.api_profile_picture_url)
        case_no = 2
      end
      # create temp dir for picture download
      tmp_dir_full_os_path = Picture.create_tmp_dir :rel_path => rel_path
      # download image to temp dir
      stdout, stderr, status = User.open4("wget \"#{url}\" --no-check-certificate", tmp_dir_full_os_path)
      if status != 0
        # download failed
        logger.warn2 "image download failed: wget: stdout = #{stdout}, stderr = #{stderr}, status = #{status} (#{status.class})"
        Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
        return ['.profile_image_wget_failed', {:provider => user.provider, :image => url, :error => error}]
      end
      # check download
      files = Dir.entries(tmp_dir_full_os_path).delete_if { |x| ['.', '..'].index(x) }
      if files.size != 1
        logger.error2 "image download failed. expected 1 image. found #{files.size} images"
        Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
        return ['.profile_image_count_failed', {:provider => user.provider, :image => url, :count => files.size}]
      end
      new_image_file_full_os_path = "#{tmp_dir_full_os_path}/#{files.first}"
      if case_no == 2
        # 2) overwrite old profile picture - backup before overwrite
        from = Picture.full_os_path :url => old_api_profile_picture_url
        to = "#{new_image_file_full_os_path}.old"
        cmd = "cp #{from} #{to}"
        if status != 0
          logger.debug2 "case #{case_no}"
          logger.debug2 "cp1: cmd = #{cmd}"
          logger.error2 "cp1: stdout = #{stdout}, stderr = #{stderr}, status = #{status} (#{status.class})"
          error = stderr.to_s.split("\n").last
          Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
          return ['.profile_image_cp1_failed', {:provider => user.provider, :image => url, :error => error}]
        end
        # backup ok
      end
      # copy
      from = new_image_file_full_os_path
      to = Picture.full_os_path :rel_path => rel_path
      cmd = "cp #{from} #{to}"
      stdout, stderr, status = User.open4(cmd)
      if status != 0
        # copy failed
        logger.debug2 "case #{case_no}"
        logger.debug2 "cp2: cmd = #{cmd}"
        logger.error2 "cp2: stdout = #{stdout}, stderr = #{stderr}, status = #{status} (#{status.class})"
        error1 = stderr.to_s.split("\n").last
        if case_no == 2
          # restore backup
          from = "#{new_image_file_full_os_path}.old"
          to = Picture.full_os_path :url => old_api_profile_picture_url
          cmd = "cp #{from} #{to}"
          stdout, stderr, status = User.open4(cmd)
          if status != 0
            logger.debug2 "case #{case_no}"
            logger.debug2 "cp3: cmd = #{cmd}"
            logger.error2 "cp3: stdout = #{stdout}, stderr = #{stderr}, status = #{status} (#{status.class})"
            error2 = stderr.to_s.split("\n").last
            error = "#{error1} - #{error2}"
            Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
            return ['.profile_image_cp3_failed', {:provider => user.provider, :image => url, :error => error}]
          end
          # backup restored
        end
        # copy failed
        Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
        return ['.profile_image_cp2_failed', {:provider => user.provider, :image => url, :error => error1}]
      end
      # copied
      # download and copy ok
      user.reload
      user.api_profile_picture_url = Picture.url :rel_path => rel_path
      user.update_attribute('api_profile_picture_url', user.api_profile_picture_url) if user.api_profile_picture_url_changed?
      # cleanup
      Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
      Picture.delete :url => old_api_profile_picture_url if case_no == 3
      nil
    rescue Exception => e
      logger.error2 "Exception: #{e.message.to_s}"
      logger.error2 "Backtrace: " + e.backtrace.join("\n")
      # picture cleanup - any problems are only written to log
      begin
        if tmp_dir_full_os_path and File.exists?(tmp_dir_full_os_path)
          begin
            # always remove tmp dir if tmp dir exists
            Picture.delete_tmp_dir :full_os_path => tmp_dir_full_os_path
          rescue Exception => e
            logger.error2 "Error in tmp dir cleanup after exception. Error = #{e.message}"
          end
        end
        if case_no and [1, 3].index(case_no) and rel_path
          begin
            # new picture location - remove picture if picture exists
            to = Picture.full_os_path :rel_path => rel_path
            FileUtils.rm(to) if File.exists(to)
          rescue Exception => e
            logger.error2 "Error in tmp dir cleanup after exception. Error = #{e.message}"
          end
        end
      rescue Exception => e
        logger.error2 "Error in picture cleanup after exception. Error = #{e.message}"
      end
    end
  end # self.download_profile_image

  #def usertype
  #  return nil unless user_id
  #  user_id.first(2)
  #end

  # return uid part of user_id
  def uid
    return nil unless user_id
    user_id.split('/').first
  end
  # return provider part of user_id - facebook, google_oauth2, linkedin or twitter - see OmniAuth::Builder.providers
  def provider
    return nil unless user_id
    user_id.split('/').last
  end

  # true if dummy user
  # gofreerev/gofreerev or gofreerev/<provider>
  # dummy user is used for dummy page header, deep links and unmatched providers when closing deal between two users
  def dummy_user?
    user_id.split('/').first == 'gofreerev'
  end
  def self.dummy_users? (login_users)
    raise "invalid call" unless login_users.class == Array and login_users.size > 0
    login_users.each do |login_user|
      return false unless login_user.dummy_user?
    end
    true
  end

  def facebook?
    return false unless user_id
    provider == 'facebook'
  end # facebook
  def google_plus?
    return false unless user_id
    provider == 'google'
  end # facebook
  def linkedin?
    return false unless user_id
    provider == 'linkedin'
  end

  def short_user_name
    a = user_name.split(' ')
    "#{a.first} #{a.last.first(1)}"
  end
  def short_or_full_user_name (login_users)
    friend?(login_users) ? short_user_name : user_name
  end # short_or_full_user_name
  def debug_info
    "#{user_id} #{short_user_name}"
  end
  def self.debug_info (users)
    users.collect { |u| u.debug_info }.join(', ')
  end


  def apiname
    API_DOWNCASE_NAME[provider] || provider
  end

  def apiname_with_brackets
    "(#{apiname})"
  end


  # add login api to user name
  def user_name_with_api
    "#{user_name} #{apiname_with_brackets}"
  end # user_name_with_api

  # used in many translates
  def app_and_apiname_hash
    { :appname => APP_NAME,
      :apiname => apiname }
  end


  def currency_with_text
    return nil unless currency
    m = Money::Currency.table.find { |a| a[0] == currency.downcase.to_sym }
    return nil unless m
    "#{m[1][:iso_code]} #{m[1][:name]}".first(25)
  end # currency_with_text

  # has user granted app privs wall postings?
  def post_on_wall_authorized?
    permissions = self.permissions
    case provider
      when "facebook"
        if !permissions
          logger.debug2 "Found #{provider} user without permissions. post_login_#{provider} method must have failed"
          return false
        end
        # looks like permission status_update has been replaced with publish_actions
        # publish_actions is added when requesting status_update priv.
        permissions['status_update'] == 1 or permissions["publish_actions"] == 1
      when 'google_oauth2'
        # readonly API
        false
      when "linkedin"
        permissions.to_s.split(',').index('rw_nus') != nil
      when 'twitter'
        permissions.to_s == 'write'
      else
        logger.warn2  "post_on_wall? not implemented for #{provider}"
        false
    end # case
  end # post_on_wall_authorized?
  def self.post_on_wall_authorized? (users)
    return false unless users.class == Array and users.length > 0
    users.each do |user|
      next unless API_POST_PERMITTED[user.provider]
      return true if user.post_on_wall_authorized?
    end
    false
  end # self.post_on_wall_authorized?

  # has user authorized and enabled post on wall?
  def post_on_wall_allowed?
    post_on_wall_yn == 'Y' and post_on_wall_authorized?
  end
  def self.post_on_wall_allowed? (login_users)
    return false if login_users.size == 0 or login_users.size == 1 and login_users.first.dummy_user?
    login_users.each do |login_user|
      return true if login_user.post_on_wall_allowed?
    end
    return false
  end


  def self.post_image_allowed? (login_users)
    (Picture.find_picture_store(login_users) != nil)
  end # post_image_allowed?

  # "permissions"=>{"data"=>[{"installed"=>1, "basic_info"=>1, "read_stream"=>1, "status_update"=>1, "photo_upload"=>1, "video_upload"=>1, "create_note"=>1 ...
  def read_gifts_allowed?
    permissions = self.permissions
    case
      when facebook?
        permissions['read_stream'] == 1
      else
        logger.debug2  "read_wall_allowed? not implemented for #{user_id.first(2)} users"
        false
    end
  end  # read_gifts_allowed?

  # write on api wall helpers
  WRITE_ON_WALL_YES = 1
  WRITE_ON_WALL_NO = 2
  WRITE_ON_WALL_MISSING_PRIVS = 3

  def get_write_on_wall_action
    # check user privs before post in provider wall
    # that is user.permissions and user.post_on_wall_yn settings
    if post_on_wall_authorized?
      # user has authorized post on provider wall
      if post_on_wall_yn != 'Y'
        logger.debug2 "User has authorized post on #{provider} but has selected not to post on #{provider} wall"
        return User::WRITE_ON_WALL_NO
      end
      # write priv ok - continue with post on provider wall
      return User::WRITE_ON_WALL_YES
    else
      # user has not authorized post on provider wall
      if post_on_wall_yn == 'Y'
        # inject link to authorize post on provider wall
        return User::WRITE_ON_WALL_MISSING_PRIVS
      else
        logger.debug2 "Ignore post_on_#{provider}. User has not authorzed post on #{provider} wall and has also selected not to post on #{provider} wall"
        return User::WRITE_ON_WALL_NO
      end
    end
  end # check_write_on_wall_privs

  # relation helpers
  def offers
    ApiGift.where('user_id_giver = ? and provider = ?', user_id, provider).includes(:gift)
  end
  def wishes
    ApiGift.where('user_id_receiver = ? and provider = ?', user_id, provider).includes(:gift)
  end
  def gifts_given
    offers.find_all { |ag| (ag.user_id_receiver and ag.gift.price and ag.gift.price != 0.00 and !ag.gift.deleted_at) }
  end # gifts_given
  def gifts_received
    wishes.find_all { |ag| (ag.user_id_giver and ag.gift.price and ag.gift.price != 0.00 and !ag.gift.deleted_at) }
  end
  #def gifts_received_with_sign
  #  gifts_received.collect do |g|
  #    g.new_price = -g.new_price
  #    g
  #  end # collect
  #end # gifts_received_with_sig
  def gifts_given_and_received
    gifts_given + gifts_received
  end

  # find app friends. instance method for actual user and class method for logged in users
  def app_friends
    Friend.where("user_id_giver = ?", user_id).includes(:friend).find_all do |f|
      # logger.debug2  "user_id_receiver = #{f.user_id_receiver}, api_friend = #{f.api_friend}, app_friend = #{f.app_friend}"
      if f.app_friend == 'Y'
        true
      elsif f.app_friend == nil and f.api_friend == 'Y'
        true
      else
        false
      end
    end # find all
  end # app_friends

  def self.all_friends (login_users)
    return [] if login_users.size == 0
    login_user_ids = login_users.collect { |login_user| login_user.user_id }
    friends = Friend.where("user_id_giver in (?)", login_user_ids).includes(:friend)
    Friend.define_sort_by_user_name(friends)
  end # self.all_friends

  def self.app_friends (login_users)
    login_users_text = login_users.collect { |u| "#{u.user_id} #{u.short_user_name}"}.join(', ')
    friends = User.all_friends(login_users).find_all do |f|
      friend = f.friend.friend?(login_users)
      logger.debug2 "#{f.friend.user_id} #{f.friend.short_user_name} is " + (friend ? '' : 'not ') + "friend with login users " + login_users_text
      friend
    end
    Friend.define_sort_by_user_name(friends)
  end # self.app_friends

  # find number of app friends. instance method for actual user and class method for logged in users
  # show special messages to user if no app friends was found
  def no_app_friends
    return @no_app_friends if @no_app_friends
    @no_app_friends = app_friends.size
  end
  def self.no_app_friends (login_users)
    User.app_friends(login_users).size
  end

  # recalculate user balance
  # currency and balance is not updated if one or more exchange rates are missing
  # missing exchange rates is put in queue for bank and looked up batch
  # batch job started at after returning actual page to user
  def recalculate_balance
    # find user(s)
    if user_combination
      # find all closed deals for this user combination
      user_ids = User.where('user_combination = ?', user_combination).collect { |user| user.user_id}
    else
      # find all closed deals for this user
      user_ids = [ user_id ]
    end
    # find closed deals
    api_gifts = ApiGift.where('user_id_giver in (?) and user_id_receiver is not null or ' +
                              'user_id_receiver in (?) and user_id_giver is not null',
                              user_ids, user_ids).includes(:gift)
    # remove closed deals without a price and remove delete marked deals
    api_gifts = api_gifts.find_all do |api_gift|
      (api_gift.user_id_giver and api_gift.gift.price and api_gift.gift.price != 0.00 and !api_gift.gift.deleted_at)
    end
    # remove closed deals with user(s) as giver AND receiver
    api_gifts = api_gifts.delete_if do |api_gift|
      (user_ids.index(api_gift.user_id_giver) and user_ids.index(api_gift.user_id_receiver))
    end
    # sort: 1 received_at, 2 id
    api_gifts = api_gifts.sort do |a,b|
      if a.gift.received_at == b.gift.received_at
        a.gift.id <=> b.gift.id
      else
        a.gift.received_at <=> b.gift.received_at
      end
    end # sort
    # delete gift doublets
    old_gift_id = -1
    api_gifts = api_gifts.delete_if do |api_gift|
      if api_gift.gift.id == old_gift_id
        true
      else
        old_gift_id = api_gift.gift.id
        false
      end
    end # delete_if

    user_balance_hash = { BALANCE_KEY => 0.0 } # BASE_CURRENCY
    user_negative_interest_hash = { BALANCE_KEY => 0.0 } # BASE_CURRENCY (USD)
    missing_exchange_rates = false
    logger.debug2  "user #{self.short_user_name}. #{api_gifts.size} gifts"
    previous_date = nil
    date = nil
    exchange_rates_hash = {} # used as help variables for exchange rate gains/losses calculation in view
    api_gifts.each do |api_gift|
      # update user.balance hash and save balance in gift.balance for documentation
      # previous balance >= 0 - use FACTOR_POS_BALANCE_PER_DAY to calculate new price
      # previous balance < 0 - use FACTOR_NEG_BALANCE_PER_DAY to calculate new price
      # note a small problem as balance in BASE_CURRENCY is a sum of different currencies and sum changes when currency rates changes
      # balance in BASE_CURRENCY can change between >= 0 and < 0 in period between two deals
      # but only previous balance is used when selection negative interest rate
      balance_doc_hash = {}
      previous_date = api_gift.gift.received_at.to_date unless previous_date
      previous_balance_hash = user_balance_hash.clone
      balance_doc_hash[:previous_balance] = previous_balance_hash
      if previous_date != api_gift.gift.received_at.to_date
        # save old exchange rates for exchange rate difference calculation
        user_balance_hash.keys.each do |balance_hash_currency|
          next if balance_hash_currency == BALANCE_KEY
          exchange_rates_hash[balance_hash_currency] = ExchangeRate.exchange(1.0, BASE_CURRENCY, balance_hash_currency, previous_date)
        end
      end
      previous_exchange_rates_hash = exchange_rates_hash.clone
      balance_doc_hash[:previous_exchange_rates] = previous_exchange_rates_hash
      # logger.debug2  "balance_doc_hash[:previous_balance] = #{balance_doc_hash[:previous_balance]}"
      balance_doc_hash[:previous_date] = previous_date.to_yyyymmdd
      # balance_doc_hash[:number_of_days] = (g.received_at.to_date - previous_date).to_i

      # step 1 - calculate negative interest from previous gift to this gift
      # use FACTOR_POS_BALANCE_PER_DAY for positive balance - 0.9998594803001535 per day <=>  5 % per year
      # use FACTOR_NEG_BALANCE_PER_DAY for negative balance - 0.9997113827109777 per day <=> 10 % per year
      balance_sum = user_balance_hash[BALANCE_KEY] # current user balance in BASE_CURRENCY (USD)
      date = previous_date
      while (date < api_gift.gift.received_at.to_date) do
        date = 1.day.since(date)
        factor = (balance_sum >= 0 ? FACTOR_POS_BALANCE_PER_DAY : FACTOR_NEG_BALANCE_PER_DAY) # 5 OR 10 % in negative interest
        balance_sum = 0.0
        user_balance_hash.keys.each do |balance_hash_currency|
          next if balance_hash_currency == BALANCE_KEY
          user_balance_hash[balance_hash_currency] *= factor
          exchange_rate = ExchangeRate.exchange(1.0, balance_hash_currency, BASE_CURRENCY, date)
          balance_sum += user_balance_hash[balance_hash_currency] * exchange_rate
          exchange_rates_hash[balance_hash_currency] = 1.0 / exchange_rate if date == api_gift.gift.received_at.to_date
        end # each
      end # while
      user_balance_hash[BALANCE_KEY] = balance_sum
      # initialize negative interest hash
      logger.debug2  "gift id #{api_gift.id}: initialize and save negative interest hash"
      gift_negative_interest_hash = {}
      user_balance_hash.keys.each do |balance_hash_currency|
        next if balance_hash_currency == BALANCE_KEY
        gift_negative_interest = (previous_balance_hash[balance_hash_currency] - user_balance_hash[balance_hash_currency]).abs
        logger.debug2  "gift id #{api_gift.id}, currency = #{balance_hash_currency}, old = #{previous_balance_hash[balance_hash_currency]}, new = #{user_balance_hash[balance_hash_currency]}, neg.int. = #{gift_negative_interest}"
        gift_negative_interest_hash[balance_hash_currency] = gift_negative_interest
        user_negative_interest_hash[balance_hash_currency] = 0.0 unless user_negative_interest_hash.has_key?(balance_hash_currency)
        user_negative_interest_hash[balance_hash_currency] += gift_negative_interest
      end
      balance_sum = 0.0
      gift_negative_interest_hash.keys.each do |balance_hash_currency|
        balance_sum += ExchangeRate.exchange(gift_negative_interest_hash[balance_hash_currency], balance_hash_currency, BASE_CURRENCY, previous_date)
      end
      gift_negative_interest_hash[BALANCE_KEY] = balance_sum
      balance_doc_hash[:exchange_rates] = exchange_rates_hash
      balance_doc_hash[:negative_interest] = gift_negative_interest_hash
      previous_date = date

      # step 2: calculate previous_balance + negative_interest hash
      # used for exchange rate gains/losses calculation in view
      #previous_balance_neg_int_hash = {}
      #previous_balance_hash.keys.each do |balance_hash_currency|
      #  next if balance_hash_currency == BALANCE_KEY
      #  previous_balance_neg_int_hash[balance_hash_currency] = previous_balance_hash[balance_hash_currency] + gift_negative_interest_hash[balance_hash_currency]
      #end
      #balance_doc_hash[:previous_balance_and_negative_interest] = previous_balance_neg_int_hash

      # step 3 - new balance with this gift
      sign = user_ids.index(api_gift.user_id_giver) ? 1 : -1
      user_balance_hash[api_gift.gift.currency] = 0.0 unless user_balance_hash.has_key?(api_gift.gift.currency)
      user_balance_hash[api_gift.gift.currency] += api_gift.gift.price * sign
      user_balance_hash[BALANCE_KEY] += ExchangeRate.exchange((api_gift.gift.price*sign), api_gift.gift.currency, BASE_CURRENCY, date)
      balance_doc_hash[:sign] = sign > 0 ? '+' : '-'
      balance_doc_hash[:balance] = user_balance_hash

      # save balance and balance documentation
      api_gift.gift.set_balance(user_ids, user_balance_hash[BALANCE_KEY], balance_doc_hash)
      # g.save
      logger.debug2  "recalculate_balance. gift.id = #{api_gift.gift.id}, gift.received_at = #{api_gift.gift.received_at}, balance_hash = #{user_balance_hash.to_s}, balance_doc_hash = #{balance_doc_hash}"
    end # each
    return false if missing_exchange_rates # error - one or more missing currency rates
    today = Date.parse(Sequence.get_last_exchange_rate_date)
    if date
      # calculate negative interest from last gift and up to "today"
      # "today" as last date with known exchange rates from default money bank
      previous_balance_hash = user_balance_hash.clone
      while (date < today) do
        date = 1.day.since(date)
        factor = (user_balance_hash[BALANCE_KEY] >= 0 ? FACTOR_POS_BALANCE_PER_DAY : FACTOR_NEG_BALANCE_PER_DAY)
        balance_sum = 0.0
        user_balance_hash.keys.each do |balance_hash_currency|
          next if balance_hash_currency == BALANCE_KEY
          user_balance_hash[balance_hash_currency] *= factor
          balance_sum += ExchangeRate.exchange(user_balance_hash[balance_hash_currency], balance_hash_currency, BASE_CURRENCY, date)
        end # each
        user_balance_hash[BALANCE_KEY] = balance_sum
      end
      user_balance_hash.keys.each do |balance_hash_currency|
        user_negative_interest_hash[balance_hash_currency] = 0.0 unless user_negative_interest_hash.has_key?(balance_hash_currency)
        user_negative_interest_hash[balance_hash_currency] += (previous_balance_hash[balance_hash_currency] - user_balance_hash[balance_hash_currency])
      end
    end
    logger.debug2  "user balance = #{user_balance_hash}"
    logger.debug2  "user negative_interest #{user_negative_interest_hash}"
    # calculation ok - all needed exchange rates was found
    self.balance = user_balance_hash
    self.balance_at = today
    self.negative_interest = user_negative_interest_hash
    # todo: catch any exception and return false if transaction fails
    Gift.check_gift_and_api_gift_rel
    transaction do
      api_gifts.each do |api_gift|
        logger.debug2 "api gift id = #{api_gift.id}"
        api_gift.gift.save!
      end
      self.save!
    end
    true
  end # recalculate_balance

  def self.recalculate_balance (login_users)
    users = login_users.sort do |a,b|
      (a.user_combination) || (0 <=> b.user_combination || 0)
    end
    # keep only one login_user for each user_combination
    old_user_combination = -1
    users = users.find_all do |user|
      if user.user_combination
        if user.user_combination == old_user_combination
          false # skip user with doublet user_combination
        else
          old_user_combination = user.user_combination
          true # keep first user for user_combination
        end
      else
        true # keep all users without user_combination
      end
    end
    # recalculate
    users.each { |user| user.recalculate_balance }
  end

  def balance_with_2_decimals
    '%0.2f' % (balance[BALANCE_KEY] || 0)
  end

  # get friend record from login users cached list of friends
  def get_friend (login_user)
    return nil unless login_user
    login_user.friends.find_all { |f| f.user_id_receiver == self.user_id }.first
  end # get_friend

  # reverse friend record is identical with friend record except for app_friend = R, P and B
  def get_reverse_friend (login_user)
    return @reverse_friend if defined?(@reverse_friend)
    @reverse_friend = Friend.where("user_id_giver = ? and user_id_receiver = ?", self.user_id, login_user.user_id).first
  end

  # simple friend check - true or false without any details
  def friend? (login_users)
    # logger.debug2  "login_users.class = #{login_users.class}"
    return false unless [Array, ActiveRecord::Relation::ActiveRecord_Relation_User].index(login_users.class) # not logged in
    # logger.debug2  "login_users.size = #{login_users.size}"
    return false if login_users.size == 0 # not logged in
    login_user = login_users.find { |user| user.provider == self.provider }
    return false unless login_user
    logger.debug2  "provider = #{self.provider}, login_user.user_id = #{login_user.user_id}"
    return false unless login_user
    return true if login_user.user_id == self.user_id
    f = get_friend(login_user)
    return false unless f
    app_friend = f.app_friend || f.api_friend
    (app_friend == 'Y')
  end # friend?

  # friend status code. "this" is friend. login_user is login user.
  #   Y - friends
  #   N - not friends
  #   A - login api friends and not app friends
  #   G - gofreerev app friends and not login api friends
  #   R - app friendship request from login user to friend
  #   P - pending app friendship request to login user from friend (todo)
  #   M - my account == friends
  #   D - my account == friends & delete account in progress
  # code is used for friend_status_text_<code> translate key
  def friend_status_code (login_user)
    return 'N' unless login_user # not logged in user
    if login_user.user_id == self.user_id
      if login_user.deleted_at
        return 'D' # my account - delete in progress
      else
        return 'M' # my account
      end
    end
    f = get_friend(login_user)
    return 'N' unless f
    if f.api_friend == 'Y'
      # api friend
      case f.app_friend
        when nil then return 'Y' # default - api friends are also app friends
        when 'Y' then return 'Y' #
        when 'N' then return 'A' # user has been deselected as app friend by login user
        when 'R' then return 'R' # pending friendship request from login user
        when 'P' then return 'P'
        when 'B' then return 'B' # friendship request has been blocked login user
      end # case
    else
      # non api friend
      case f.app_friend
        when nil then return 'N'
        when 'Y' then return 'G' # not login api friends - only friends within gofreerev app
        when 'N' then return 'N' # user has been deselected as app friend by login user
        when 'R' then return 'R' # pending friendship request from login user
        when 'P' then return 'P'
        when 'B' then return 'B' # friendship request has been blocked login user
      end # case
    end
  end

  def friend_status_translate_code (login_users)
    login_user = login_users.find { |u| u.provider == self.provider }
    if !login_user
      logger.error2 'Invalid friend_status_translate_code call. Cross provider friends are not allowed. ' +
                        "Login users = #{User.debug_info(login_users)}. user = #{debug_info}}"
      return '.friend_status_text_n'
    end
    ".friend_status_text_#{friend_status_code(login_user).downcase}"
  end # friend_status_translate_code

  def find_friend_request_noti (login_user)
    ns = Notification.where("from_user_id = ? and to_user_id = ? and noti_read = 'N'", login_user.user_id, self.user_id)
    return nil unless ns.size > 0
    n = ns.find { |n| n.noti_key == FRIEND_REQUEST_NOTI_KEY }
  end # find_friend_request_noti

  # returns list with allowed friendship actions: add_api_friend, remove_api_friend, send_app_friend_request, cancel_app_friend_request, accept_app_friend_request, ignore_app_friend_request, remove_app_friend, block_app_user, unblock_app_user
  # used in users/show page / users/friend_action_buttons partial
  # The action names is also used as keys in translate. See <language>.users.friend_action_buttons.<method>
  # first letter uppercase - confirm box before submit
  # second letter uppercase - new window (target=_blank)
  def friend_status_actions (login_user_or_login_users)
    if login_user_or_login_users.class == User
      login_user = login_user_or_login_users
    elsif login_user_or_login_users.class == Array
      login_user = login_user_or_login_users.find { |u| u.provider == self.provider}
    end
    if login_user.class != User
      logger.error2 "Invalid call. expected user or array of users. login_user_or_login_users = #{login_user_or_login_users}"
      return []
    end
    return [] if login_user.deleted_at
    case friend_status_code(login_user)
      when 'Y' then return %w(rEmove_api_friend Remove_app_friend)
      when 'N' then return %w(aDd_api_friend send_app_friend_request)
      when 'A' then return %w(rEmove_api_friend send_app_friend_request)
      when 'G' then return %w(aDd_api_friend Remove_app_friend)
      when 'R' then return %w(aDd_api_friend send_app_friend_request cancel_app_friend_request)
      when 'P' then return %w(aDd_api_friend accept_app_friend_request ignore_app_friend_request block_app_user)
      when 'B' then return %w(unblock_app_user)
    end
  end # friend_status_actions
  def allowed_friend_status_action (login_user, action)
    allowed_friend_actions = friend_status_actions(login_user).collect { |fa| fa.downcase }
    allowed = allowed_friend_actions.index(action.to_s)
    logger.debug2  "action #{action} was not allowed. Friend status code = #{friend_status_code(login_user)}, allowed actions = #{allowed_friend_actions.join(', ')}"  if  !allowed
    allowed
  end
  def add_api_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not used. no facebook api dialog to add friend"
  end
  def remove_api_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not used. no facebook api dialog to remove friend"
  end
  def send_app_friend_request (login_user)
    # set api_friend = R for login user, set api_friend = P for friend
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    if !f
      f = Friend.new
      f.user_id_giver = login_user.user_id
      f.user_id_receiver = self.user_id
      f.api_friend = 'N'
    end
    r = get_reverse_friend(login_user)
    if !r
      r = Friend.new
      r.user_id_giver = f.user_id_receiver
      r.user_id_receiver = f.user_id_giver
      r.api_friend = f.api_friend
    end
    f.app_friend = 'R'
    if r.app_friend != 'B' # friend request from blocked users is ignored silently
      r.app_friend = 'P'
      # don't add new notification if previously request_for_app_friendship has not been read
      n = find_friend_request_noti(login_user)
      if !n
        n = Notification.new
        n.to_user_id = self.user_id
        n.from_user_id = login_user.user_id
        n.internal = 'Y'
        # Be careful when renaming or deleting altering keys in noti_options hash.
        # you may run into problems displaying old and new notification format
        # Consider creating a new version of request_for_app_friendship key if you renames or deletes noti_options hash keys
        n.noti_key = FRIEND_REQUEST_NOTI_KEY
        n.noti_options = { :from_user => login_user.user_name, :from_id => login_user.id,
                             :to_user => self.user_name, :to_id => self.id,
                             :appname => APP_NAME }
        n.noti_read = 'N'
      end
    end
    f.save!
    r.save!
    n.save! if n
    true
  end # send_app_friend_request
  def cancel_app_friend_request (login_user)
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    r = get_reverse_friend(login_user)
    if f.api_friend == 'Y'
      f.app_friend = 'N'
    else
      f.app_friend = nil
    end
    if !r
      # error - r should exists - create missing record
      r = Friend.new
      r.user_id_giver = f.user_id_receiver
      r.user_id_receiver = f.user_id_giver
      r.api_friend = f.api_friend
    end
    if r.app_friend == 'P'
      if r.api_friend == 'Y'
        r.app_friend = 'N'
      else
        r.app_friend = nil
      end
    end
    n = find_friend_request_noti(login_user)
    f.save!
    r.save!
    n.destroy if n
    true
  end # cancel_app_friend_request
  def accept_app_friend_request (login_user)
    # set api_friend = Y for login user and friend
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    r = get_reverse_friend(login_user)
    raise "invalid request" if !f or !r or f.app_friend != 'P' or r.app_friend != 'R'
    f.app_friend = 'Y'
    r.app_friend = 'Y'
    n = Notification.new
    n.to_user_id = self.user_id
    n.from_user_id = login_user.user_id
    n.internal = 'Y'
    # Be careful when renaming or deleting altering keys in noti_options hash.
    # you may run into problems displaying old and new notification format
    # Consider creating a new version of app_friendship_accepted key if you renames or deletes noti_options hash keys
    n.noti_key = 'app_friendship_accepted_v1'
    n.noti_options = { :from_user => login_user.short_user_name, :from_id => login_user.id,
                         :to_user => self.short_user_name, :to_id => self.id,
                         :appname => APP_NAME }
    n.noti_read = 'N'
    f.save!
    r.save!
    n.save!
    true
  end # accept_app_friend_request
  def ignore_app_friend_request (login_user)
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    if f.api_friend == 'Y'
      f.app_friend = 'N'
    else
      f.app_friend = nil
    end
    f.save!
    true
  end
  def remove_app_friend (login_user)
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    if !f
      f = Friend.new
      f.user_id_giver = login_user.user_id
      f.user_id_receiver = self.user_id
      f.api_friend = 'N'
    end
    r = get_reverse_friend(login_user)
    if !r
      r = Friend.new
      r.user_id_giver = f.user_id_receiver
      r.user_id_receiver = f.user_id_giver
      r.api_friend = f.api_friend
    end
    f.app_friend = 'N'
    r.app_friend = 'N' unless r.app_friend == 'B'
    f.save!
    r.save!
    true
  end # remove_app_friend
  def block_app_user (login_user)
    return false unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    f.app_friend = 'B'
    f.save!
    true
  end
  def unblock_app_user (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    if f.api_friend == 'Y'
      f.app_friend = 'N'
    else
      f.app_friend = nil
    end
    f.save!
  end


  def inbox_new_notifications
    raise "debug - maybe no longer used"
    return @new_notifications if defined?(@new_notifications)
    return @new_notifications = nil if User.dummy_users?(@users)
    notifications = Notification.where("to_user_id = ? and noti_read = 'N'", self.user_id)
    # don't count notifications for deleted or delete marked gifts
    notifications = notifications.find_all do |noti|
      giftid = noti.noti_options[:giftid]
      if giftid
        # gift/comment notification. Check if gift has been deleted or delete marked.
        gift = Gift.find_by_id(giftid)
        gift and !gift.deleted_at
      else
        # other notifications
        true
      end
    end
    if notifications.length > 0
      @new_notifications = notifications.length
    else
      @new_notifications = nil
    end
  end # inbox_new_notifications

  # return nil if no notification - return number of notifications
  def self.inbox_new_notifications (login_users)
    # check cache (first user in user array)
    n = login_users.first.cache_new_notifications
    return (n == 0 ? nil : n) if n
    return nil if login_users.length == 0 # error
    return nil if login_users.first.dummy_user? # not logged in
    # lookup number of new notifications
    login_user_ids = login_users.collect { |user| user.user_id }
    notifications = Notification.where("to_user_id in (?) and noti_read = 'N'", login_user_ids)
    # don't count notifications for deleted or delete marked gifts
    notifications = notifications.find_all do |noti|
      giftid = noti.noti_options[:giftid]
      if giftid
        # gift/comment notification. Check if gift has been deleted or delete marked.
        gift = Gift.find_by_id(giftid)
        gift and !gift.deleted_at
      else
        # other notifications
        true
      end
    end
    n = login_users.first.cache_new_notifications = notifications.length
    (n == 0 ? nil : n)
  end # self.inbox_new_notifications

  # refresh user permisssions
  # called in error handling after picture upload with ApiPostNotFoundException error
  # see api_gifts/create
  def get_permissions_facebook(api_client)
    api_request = 'me?fields=permissions'
    logger.debug2  "api_request = #{api_request}"
    begin
      api_response = api_client.get_object(api_request)
    rescue Koala::Facebook::ClientError => e
      e.logger = logger
      e.puts_exception("#{__method__}: ")
      raise
    end # rescue
    logger.debug2  "api_response = #{api_response}"
    self.permissions = api_response['permissions']['data'][0]
    self.permissions = {} if self.permissions == []
    save!
    self
  end # get_api_permissions


  ## find gifts user can see. user friends must be giver or receiver of gifts
  ## params newest_gift_id and newest_status_update_at are normally 0 (for example when called from gifts/index)
  ## but is newest gift_id and status_update_at when called from util/new_messages_count (that is - ajax - get only new, updated or deleted gifts)
  #def api_gifts (options = {})
  #
  #  newest_gift_id              = options[:newest_gift_id] || 0
  #  newest_status_update_at     = options[:newest_status_update_at] || 0
  #  include_delete_marked_gifts = options[:include_delete_marked_gifts] || false
  #
  #  # initialize list of gifts
  #  # list of gifts with @user as giver or receiver + list of gifts med @user.friends as giver or receiver
  #  # where clause is used for non encrypted fields. find_all is used for encrypted fields
  #
  #  # find friends
  #  friends = app_friends.collect { |u| u.user_id_receiver }
  #  friends.push(user_id)
  #  # find api gifts
  #  if include_delete_marked_gifts
  #    # called from util.new_messages_count - include delete marked gifts in response - will be ajax replaced with invisible rows
  #    deleted = ""
  #  else
  #    # called from users or gifts controller - to not return delete mark gifts in response
  #    deleted = ' and gifts.deleted_at is null'
  #  end
  #  if newest_gift_id == 0 and newest_status_update_at == 0
  #    ags = ApiGift.where('(user_id_giver in (?) or user_id_receiver in (?)) and status_update_at < ?' + deleted,
  #                    friends, friends, 860).limit(10).references(:gifts, :api_gifts).includes(:gift, :giver, :receiver)
  #  else
  #    ags = ApiGift.where('(gifts.id > ? or status_update_at > ?) and (user_id_giver in (?) or user_id_receiver in (?))  and status_update_at < ?' + deleted,
  #                    newest_gift_id, newest_status_update_at, friends, friends, 860).limit(10).references(:gifts, :api_gifts).includes(:gift, :giver, :receiver)
  #  end
  #  # sort api gifts
  #  ags = ags.sort do |a,b|
  #    #if (a.gift.received_at || a.created_at) ==  (b.gift.received_at || b.created_at)
  #    #  b.id <=> a.id
  #    #else
  #    #  (b.gift.received_at || b.created_at) <=>  (a.gift.received_at || a.created_at)
  #    #end
  #    b.gift.status_update_at <=> a.gift.status_update_at
  #  end
  #  return ags if ags.length == 0
  #
  #  # remove any hidden gifts (show=N) from api gifts list
  #  giftids = ags.collect { |ag| ag.gift_id }
  #  hide_giftids = GiftLike.
  #      where("user_id = ? and gift_id in (?)", user_id, giftids).
  #      find_all { |gl| gl.show == 'N'}.
  #      collect { |gl| gl.gift_id }
  #  return ags if hide_giftids.length == 0
  #
  #  # remove hidden gifts
  #  ags = ags.find_all { |ag| !hide_giftids.index(ag.gift_id) }
  #
  #  ags
  #
  #end # api_gifts


  # as instance method gifts, but extended to be used for multiple provider logins
  # last_status_update_at & limit are used from gifts/index to return first row (http request) or next 10 rows (ajax request)
  # newest_gift_id, newest_status_update_at & include_delete_marked_gifts are used from util/new_messages_count to
  # return new gifts, changed gifts, delete marked gifts to gifts/index page in ajax request
  def self.api_gifts (login_users, options = {})
    # get param
    last_status_update_at       = options[:last_status_update_at] || 2147483647 # status_update_at for last gift in gifts/index page
    limit                       = options[:limit] # number of rows to return to gifts/index page (1 for http and 10 for ajax)
    newest_gift_id              = options[:newest_gift_id] || 0 # newest gift id when gifts/index page was last updated
    newest_status_update_at     = options[:newest_status_update_at] || 0 # newest status_update_at when gifts/index page was last updated
    include_delete_marked_gifts = options[:include_delete_marked_gifts] || false # used in util/new_message_count to remove deleted gifts from gifts/index page
    # dump params
    logger.debug2 "login_users.size            = #{login_users.size}"
    logger.debug2 "last_status_update_at       = #{last_status_update_at}"
    logger.debug2 "limit                       = #{limit}"
    logger.debug2 "newest_gift_id              = #{newest_gift_id}"
    logger.debug2 "newest_status_update_at     = #{newest_status_update_at}"
    logger.debug2 "include_delete_marked_gifts = #{include_delete_marked_gifts}"
    # validate params
    unless [Array, ActiveRecord::Relation::ActiveRecord_Relation_User].index(login_users.class) and
        login_users.length > 0 and
        !login_users.first.dummy_user?
      logger.error2 "Invalid call. expected array of login users"
      return [[],nil]
    end
    if limit and (newest_gift_id > 0 or newest_status_update_at > 0)
      logger.warn2 ":newest_gift_id and :newest_status_update_at are used in util.new_messages_count to get new, changed and deleted gifts"
      logger.warn2 ":limit should not be used in combination with :newest_gift_id and :newest_status_update_at"
      limit = nil
    end

    # initialize list of gifts
    # list of gifts with @user as giver or receiver + list of gifts med @user.friends as giver or receiver
    # where clause is used for non encrypted fields. find_all is used for encrypted fields

    # find friends
    friends = User.app_friends(login_users).collect { |u| u.user_id_receiver }

    # find api gifts
    if include_delete_marked_gifts
      # called from util.new_messages_count - include delete marked gifts in response - will be ajax replaced with invisible rows
      deleted = ""
    else
      # called from users or gifts controller - to not return delete mark gifts in response
      deleted = ' and gifts.deleted_at is null'
    end
    # Use a larger limit in sql statement. correct limit for multi provider login and for hidden gifts
    sql_limit = limit
    if sql_limit
      # correct for multi provider posts
      if sql_limit == 1
        sql_limit = login_users.size
      else
        # 1.50 <=> half of gift post is multi provider posts
        sql_limit = sql_limit * login_users.size * 1.50
      end
      # correct for hidden posts. 1.10 <=> 10 % hidden posts
      sql_limit = sql_limit * 1.10
      sql_limit = sql_limit.ceil
    end

    if newest_gift_id == 0 and newest_status_update_at == 0
      # called from gifts/index page - newest_gift_id and newest_status_update_at are not relevant
      ags = ApiGift.
          where('(user_id_giver in (?) or user_id_receiver in (?)) and status_update_at < ?' + deleted,
                          friends, friends, last_status_update_at).
          limit(sql_limit).
          references(:gifts, :api_gifts).
          includes(:gift, :giver, :receiver).
          order('gifts.status_update_at desc')
    else
      # called from util/new_messages_count - limit and last_status_update_at are not relevant
      ags = ApiGift.
          where('(gifts.id > ? or status_update_at > ?) and (user_id_giver in (?) or user_id_receiver in (?))' + deleted,
                          newest_gift_id, newest_status_update_at, friends, friends).
          references(:gifts, :api_gifts).
          includes(:gift, :giver, :receiver).
          order('gifts.status_update_at desc')
    end
    # execute query now
    ags = ags.to_a
    # check for eod - end of data
    if newest_gift_id == 0 and newest_status_update_at == 0
      eod = (!sql_limit or sql_limit and ags.size < sql_limit)
    else
      eod = true
    end
    logger.debug2 "sql_limit = #{sql_limit}, ags.size = #{ags.size}, eod = #{eod}"

    return [ags, nil] if ags.size == 0 # no (more) rows
    if eod
      new_last_status_update_at = nil
    else
      new_last_status_update_at = ags.last.gift.status_update_at
    end

    if login_users.size > 1
      # remove any multi provider gift doublets

      # multiple logins - find and remove any doublet gifts
      # priority:
      # 1) sort by status_update_at desc (also order by condition in select statement)
      # 2) closed gift before open gift
      # 3) api gift with picture
      # 4) api picture url with error and creator of gift in login_users - recheck picture with login user privs.
      # 5) api gift without picture
      ags = ags.sort do |a, b|
        if b.gift.status_update_at != a.gift.status_update_at
          # 1) keep sort by status_update_at desc (also order by condition in select statement)
          b.gift.status_update_at <=> b.gift.status_update_at
        elsif a.status_sort != b.status_sort
          a.status_sort <=> b.status_sort # 2) closed gift before open gift
        else
          a.picture_sort(login_users) <=> b.picture_sort(login_users) # 3, 4 and 5
        end
      end # ags sort 1

      # delete doublets if creator of gift was using multi provider login
      old_size = ags.size
      old_gift_id = -1
      ags = ags.delete_if do |ag|
        if ag.gift.id == old_gift_id
          true
        else
          old_gift_id = ag.gift.id
          false
        end
      end # delete_if
      new_size = ags.size
      logger.debug2 "removed #{old_size-new_size} doublet api gifts. old size #{old_size}. new size #{new_size}"
      # end - remove any multi provider gift doublets
    end

    # remove any hidden gifts (show=N) from api gifts list
    userids = login_users.collect { |u| u.user_id }
    giftids = ags.collect { |ag| ag.gift_id }
    hide_giftids = GiftLike.
        where("user_id in (?) and gift_id in (?)", userids, giftids).
        find_all { |gl| gl.show == 'N'}.
        collect { |gl| gl.gift_id }.
        uniq
    if hide_giftids.size > 0
      # remove hidden gifts
      logger.debug2 "remove hidden gifts: #{hide_giftids.join(', ')}"
      old_size = ags.size
      ags = ags.find_all { |ag| !hide_giftids.index(ag.gift_id) }
      new_size = ags.size
      logger.debug2 "#{old_size-new_size} hidden gifts was removed. old size = #{old_size}, new_size = #{new_size}"
    end

    return [ags, nil] if eod # no more rows from db

    while ags.size < limit and new_last_status_update_at do
      # too few rows - get more rows - stop when limit is reached or when no more rows in database
      new_limit = limit - ags.size
      logger.debug2 "too few rows. limit = #{limit}, ags.size = #{ags.size}, new limit = #{new_limit}"
      ags2, new_last_status_update_at = User.api_gifts login_users,
                                                       :last_status_update_at => new_last_status_update_at,
                                                       :limit => new_limit,
                                                       :newest_gift_id => newest_gift_id,
                                                       :newest_status_update_at => newest_status_update_at,
                                                       :include_delete_marked_gifts => include_delete_marked_gifts
      ags = ags + ags2
    end

    if ags.size > limit
      # too many rows - return first limit rows
      logger.debug2 "too many rows. limit = #{limit}, ags.size = #{ags.size}, ignore last #{ags.size-limit} rows"
      ags = ags.first(limit)
      return [ags, ags.last.gift.status_update_at]
    end

    # correct number of rows
    logger.debug2 "correct number of rows. limit = #{limit}, last_status_update_at = #{new_last_status_update_at}"
    return [ags, new_last_status_update_at]

    # done
    ags
  end # self.gifts


  # cache mutual friends lookup in @mutual_friends hash index by login_user.id
  def mutual_friends (login_users)
    raise "invalid call" unless [Array, ActiveRecord::Relation::ActiveRecord_Relation_User].index(login_users.class)
    login_user = login_users.find { |user| self.provider == user.provider }
    return {} unless login_user
    return @mutual_friends[login_user.id] if @mutual_friends and @mutual_friends.has_key?(login_user.id)
    @mutual_friends = {} unless @mutual_friends
    friends1 = app_friends.collect { |f| f.friend }
    friends2 = login_user.app_friends.collect { |f| f.friend }
    friends3 = friends1 & friends2
    logger.debug2 "user1 = #{short_user_name}, friends1 = " + friends1.collect { |u| u.short_user_name }.join(', ')
    logger.debug2 "user2 = #{login_user.short_user_name}, friends2 = " + friends2.collect { |u| u.short_user_name }.join(', ')
    logger.debug2 "friends3 = " + friends3.collect { |u| u.short_user_name }.join(', ')
    @mutual_friends[login_user.id] = friends3.collect { |u| u.short_user_name }
  end


  # ajax task. return nil or [key, options] array
  # called twice.
  # First in users/edit page when user account has been marked as deleted - delete mark gifts and comments so that gifts and comments can be ajax removed from gifts/index pages
  # Second after 6 minutes in util/new_messages_count to delete other data and user account
  def self.delete_user(id)
    begin
      user = User.find_by_id(id)
      return ['.delete_user_id_not_found', {}] unless user
      return ['.delete_user_invalid_id', {}] unless user.deleted_at

      # start logical delete
      affected_users = []
      user.update_attribute(:user_combination, nil) if user.user_combination
      # delete mark gifts
      ApiGift.where('? in (user_id_giver, user_id_receiver)', user.user_id).each do |ag|
        # delete gift or delete api gift
        # check gift has api_gifts from other login providers - ignore dummy users
        g = ag.gift
        api_gifts = g.api_gifts.find_all do |ag2|
          if ag2.id == ag.id
            false
          elsif ag2.giver and ag2.giver.dummy_user?
            false
          elsif ag2.receiver and ag2.receiver.dummy_user?
            false
          else
            true
          end
        end # find_all
        if api_gifts.size == 0
          # no other providers was found for this gift
          # marked as deleted. Will be ajax deleted in gifts/index pages within 5 minutes
          g.deleted_at = Time.new
          g.save!
        else
          # found other providers for this gift.
          # todo. No deleted_at timestamp for api_gift. Can not ajax remove api gift from gifts/index pages
          ag.destroy!
        end
        if g.received_at and g.price and g.price != 0.0
          # send notification to affected user about changed balance
          other_user_id = user.user_id == ag.user_id_giver ? ag.user_id_receiver : ag.user_id_giver
          other_user = User.find_by_user_id(other_user_id)
          if !other_user.dummy_user? and !affected_users.index(other_user_id)
            #create_table "notifications", force: true do |t|
            #  t.string   "noti_id",      limit: 20, null: false
            #  t.string   "to_user_id",   limit: 40, null: false
            #  t.string   "from_user_id", limit: 40
            #  t.string   "internal",     limit: 1,  null: false
            #  t.text     "noti_key",                null: false
            #  t.text     "noti_options"
            #  t.string   "noti_read",    limit: 1,  null: false
            #  t.datetime "created_at"
            #  t.datetime "updated_at"
            #end
            n = Notification.new
            n.to_user_id = other_user_id
            n.from_user_id = nil
            n.internal = 'Y'
            n.noti_key = 'deleted_account_v1'
            n.noti_options = user.app_and_apiname_hash.merge(:userid => other_user_id, :username => user.user_name)
            n.noti_read = 'N'
            n.save!
            affected_users << other_user_id
          end
        end

      end
      # delete mark comments
      ApiComment.where('user_id = ? and gifts.deleted_at is not null',
                       user.user_id).includes(:gift, :comment).references(:gift).each do |ac|
        c = ac.comment
        # check if comment has api_comments from other login providers
        api_comments = c.api_comments.find_all { |ac2| ac2.id != ac.id }
        if api_comments.size == 0
          # no other login provider involved for this comment
          # mark comment as deleted - will be ajax removed from gifts/index pages within 5 minutes
          c.deleted_at = Time.new
          c.save!
        else
          # other login providers found for this login provider
          # todo: cancel deal proposal if deal proposal and it was made from this and only this provider
          # todo. no deleted_at timestamp for api_comment. Can not ajax remove api comment from gifts/index page
          ac.destroy!
        end
      end
      # end logical delete

      # check for physical delete
      delete =  (Time.new - user.deleted_at > 6.minutes)
      if (delete)
        # start physical delete
        # user account has been deleted marked more than 6 minutes ago
        # physical delete all data for user account
        # repeat twice just in case that new data is created doing delete operation
        # should not happen as update operations are disabled for delete marked users
        1.upto(2) do
          AjaxComment.where('user_id = ?', user.user_id).delete_all
          GiftLike.where('user_id = ?', user.user_id).delete_all
          Notification.where('to_user_id = ? or from_user_id = ?', user.user_id, user.user_id).each do |n|
            n.api_comments.delete # delete rows in comments_notifications table - not comments
            n.delete
          end
          ApiComment.where('user_id = ?', user.user_id).each do |ac|
            ac.delete
            c = Comment.where('comment_id = ?', ac.comment_id).includes(:api_comments).first
            c.delete if c.api_comments.size == 0
          end
          ApiGift.where('user_id_giver = ? or user_id_receiver = ?', user.user_id, user.user_id).each do |ag|
            ag.delete
            g = Gift.where('gift_id = ?', ag.gift_id).includes(:api_gifts).first
            g.delete if g.api_gifts.size == 0
          end
          # delete friends information. keep information about blocked and deselected app friends
          Friend.where('user_id_giver = ?', user.user_id).delete_all
          Friend.where('user_id_receiver = ?', user.user_id).each do |f|
            f.delete unless %w(N B).index(f.app_friend)
          end
          user.delete
        end # 2 loops
        # end physical delete
      end

      # logical and/or physical delete ok
      nil

    rescue Exception => e
      logger.debug2 "Exception: #{e.message.to_s} (#{e.class})"
      logger.debug2 "Backtrace: " + e.backtrace.join("\n")
      raise
    end
  end # self.delete_user


  ##############
  # encryption #
  ##############

  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
  # overwrites non model specific methods defined in /config/initializers/active_record_extensions.rb
  protected
  def encrypt_pk
    self.user_id
  end
  def encrypt_pk=(new_encrypt_pk_value)
    self.user_id = new_encrypt_pk_value
  end
  def new_encrypt_pk
    self.user_id
  end

end # User

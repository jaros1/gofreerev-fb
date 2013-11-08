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
  has_many :offers, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :wishes, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_receiver, :dependent => :destroy
  has_many :friends, :class_name => 'Friend', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :sent_notifications, :class_name => 'Notification', :primary_key => :user_id, :foreign_key => :from_user_id, :dependent => :destroy
  has_many :received_notifications, :class_name => 'Notification', :primary_key => :user_id, :foreign_key => :to_user_id, :dependent => :destroy
  has_many :comments, :class_name => 'Comment', :primary_key => :user_id, :foreign_key => :user_id, :dependent => :destroy
  has_many :gift_likes, :class_name => 'GiftLike', :primary_key => :user_id, :foreign_key => :user_id, :dependent => :destroy


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  crypt_keeper :user_name, :currency, :balance, :permissions, :no_api_friends, :negative_interest, :encryptor => :aes, :key => ENCRYPT_KEYS[0]


  ##############
  # attributes #
  ##############

  # 1) user_id. required unique USER id, fx. fb-1234567890. Not encrypted. PK and user in encryption
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
      # puts "new_user_name = #{new_user_name} (#{new_user_name.class.name})"
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
    # puts "temp_extended_balance = #{temp_extended_balance}"
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
  # for fb users a hash with grants privs {"installed"=>1, "basic_info"=>1, "bookmarked"=>1}
  # for google+ todo:
  # permissions is fetched at login and checked before operations
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

  # 8) profile_picture_type. String in Model and db. Not encrypted.
  # profile picture is downloaded under /public/images/profiles. profile picture name is <user_id>.<profile_picture_type>

  # 9) timezone. Fixnum in model. Integer in db. Not encrypted. Used for local timestamps in views

  # 10) negative_interest. Required. Multi-currency Hash in model. Encrypted text in db
  # Keys is ISO code for currency USD, EUR, GBP etc.
  # Key BALANCE is sum of all currencies exchanged to users actual currency
  # validates_presence_of :negative_interest # todo: uncomment this
  def negative_interest
    return nil unless (temp_ext_neg_interest = read_attribute(:negative_interest))
    # puts "temp_ext_neg_interest = #{temp_ext_neg_interest}"
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


  # change currency in page header.
  attr_accessor :new_currency


  ##################
  # helper methods #
  ##################

  def self.facebook_user_prefix
    'fb-'
  end # facebook_user_prefix
  def self.google_plus_user_prefix
    'gp-'
  end # google_plus_user_prefix
  def self.linkedin_user_prefix
    'li-'
  end # linkedin_user_prefix

  def usertype
    return nil unless user_id
    user_id.first(2)
  end

  def facebook?
    return false unless user_id
    user_id.first(3) == User.facebook_user_prefix
  end # facebook
  def google_plus?
    return false unless user_id
    user_id.first(3) == User.google_plus_user_prefix
  end # facebook
  def linkedin?
    return false unless user_id
    user_id.first(3) == User.linkedin_user_prefix
  end

  def short_user_name
    a = user_name.split(' ')
    "#{a.first} #{a.last.first(1)}"
  end
  def short_or_full_user_name (login_user)
    friend?(login_user) ? short_user_name : user_name
  end # short_or_full_user_name

  def api_name_without_brackets
    case
      when facebook? then 'facebook'
      when google_plus? then 'google+'
      when linkedin? then 'linkedin'
      else nil
    end
  end

  def api_name_with_brackets
    api_name = api_name_without_brackets
    return nil unless api_name
    "(#{api_name})"
  end


  # add login api to user name
  def user_name_with_api
    "#{user_name} #{api_name_with_brackets}"
  end # user_name_with_api

  def currency_with_text
    return nil unless currency
    m = Money::Currency.table.find { |a| a[0] == currency.downcase.to_sym }
    return nil unless m
    "#{m[1][:iso_code]} #{m[1][:name]}".first(25)
  end # currency_with_text

  # has user granted app privs wall postings?
  def post_gift_allowed?
    permissions = self.permissions
    case
      when facebook?
         permissions['status_update'] == 1
      else
        puts "post_on_wall? not impleented for #{user_id.first(2)} users"
        false
    end
  end # post_gift_allowed?

  # "permissions"=>{"data"=>[{"installed"=>1, "basic_info"=>1, "read_stream"=>1, "status_update"=>1, "photo_upload"=>1, "video_upload"=>1, "create_note"=>1, "share_item"=>1, "publish_stream"=>1, "publish_actions"=>1, "bookmarked"=>1}
  def read_gifts_allowed?
    permissions = self.permissions
    case
      when facebook?
        permissions['read_stream'] == 1
      else
        puts "read_wall_allowed? not implemented for #{user_id.first(2)} users"
        false
    end
  end  # read_gifts_allowed?

  # profile picture helpers - a copy of profile picture is downloaded at login
  def profile_picture_filename
    profile_picture_name
  end
  def profile_picture_md5_path
    md5 = Digest::MD5.hexdigest(user_id).downcase
    folders = ['profiles'] + md5.scan(/.{2}/)
    folders.join('/')
  end
  def profile_picture_os_folder
    Rails.root.join('public', 'images', profile_picture_md5_path).to_s
  end
  def profile_picture_os_filename
    "#{profile_picture_os_folder}/#{profile_picture_filename}"
  end
  def profile_picture_url
    return 'no-picture.jpg' unless profile_picture_filename
    "#{profile_picture_md5_path}/#{profile_picture_filename}"
  end

  # relation helpers
  def gifts_given
    offers.find_all { |g| (g.user_id_receiver and g.price and g.price != 0.00) }
  end # gifts_given
  def gifts_received
    wishes.find_all { |g| (g.user_id_giver and g.price and g.price != 0.00) }
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

  def app_friends
    Friend.where("user_id_giver = ?", user_id).includes(:friend).find_all do |f|
      # puts "user_id_receiver = #{f.user_id_receiver}, api_friend = #{f.api_friend}, app_friend = #{f.app_friend}"
      if f.app_friend == 'Y'
        true
      elsif f.app_friend == nil and f.api_friend == 'Y'
        true
      else
        false
      end
    end # find all
  end # app_friends
  def no_app_friends
    return @no_app_friends if @no_app_friends
    @no_app_friends = app_friends.size
  end

  # recalculate user balance
  # currency and balance is not updated if one or more exchange rates are missing
  # missing exchange rates is put in queue for bank and looked up batch
  # batch job started at after returning actual page to user
  def recalculate_balance (new_currency=nil)
    new_currency = currency unless new_currency
    gifts = gifts_given_and_received.sort do |a,b|
      if a.received_at == b.received_at
        a.id <=> b.id
      else
        a.received_at <=> b.received_at
      end
    end # sort
    user_balance_hash = { BALANCE_KEY => 0.0 } # BASE_CURRENCY
    user_negative_interest_hash = { BALANCE_KEY => 0.0 } # BASE_CURRENCY (USD)
    missing_exchange_rates = false
    puts "recalculate_balance: user #{self.short_user_name}. #{gifts.size} gifts"
    previous_date = nil
    date = nil
    exchange_rates_hash = {} # used as help variables for exchange rate gains/losses calculation in view
    gifts.each do |g|
      # update user.balance hash and save balance in gift.balance for documentation
      # previous balance >= 0 - use FACTOR_POS_BALANCE_PER_DAY to calculate new price
      # previous balance < 0 - use FACTOR_NEG_BALANCE_PER_DAY to calculate new price
      # note a small problem as balance in BASE_CURRENCY is a sum of different currencies and sum changes when currency rates changes
      # balance in BASE_CURRENCY can change between >= 0 and < 0 in period between two deals
      # but only previous balance is used when selection negative interest rate
      balance_doc_hash = {}
      previous_date = g.received_at.to_date unless previous_date
      previous_balance_hash = user_balance_hash.clone
      balance_doc_hash[:previous_balance] = previous_balance_hash
      if previous_date != g.received_at.to_date
        # save old exchange rates for exchange rate difference calculation
        user_balance_hash.keys.each do |balance_hash_currency|
          next if balance_hash_currency == BALANCE_KEY
          exchange_rates_hash[balance_hash_currency] = ExchangeRate.exchange(1.0, BASE_CURRENCY, balance_hash_currency, previous_date)
        end
      end
      previous_exchange_rates_hash = exchange_rates_hash.clone
      balance_doc_hash[:previous_exchange_rates] = previous_exchange_rates_hash
      # puts "balance_doc_hash[:previous_balance] = #{balance_doc_hash[:previous_balance]}"
      balance_doc_hash[:previous_date] = previous_date.to_yyyymmdd
      # balance_doc_hash[:number_of_days] = (g.received_at.to_date - previous_date).to_i

      # step 1 - calculate negative interest from previous gift to this gift
      # use FACTOR_POS_BALANCE_PER_DAY for positive balance - 0.9998594803001535 per day <=>  5 % per year
      # use FACTOR_NEG_BALANCE_PER_DAY for negative balance - 0.9997113827109777 per day <=> 10 % per year
      balance_sum = user_balance_hash[BALANCE_KEY] # current user balance in BASE_CURRENCY (USD)
      date = previous_date
      while (date < g.received_at.to_date) do
        date = 1.day.since(date)
        factor = (balance_sum >= 0 ? FACTOR_POS_BALANCE_PER_DAY : FACTOR_NEG_BALANCE_PER_DAY) # 5 OR 10 % in negative interest
        balance_sum = 0.0
        user_balance_hash.keys.each do |balance_hash_currency|
          next if balance_hash_currency == BALANCE_KEY
          user_balance_hash[balance_hash_currency] *= factor
          exchange_rate = ExchangeRate.exchange(1.0, balance_hash_currency, BASE_CURRENCY, date)
          balance_sum += user_balance_hash[balance_hash_currency] * exchange_rate
          exchange_rates_hash[balance_hash_currency] = 1.0 / exchange_rate if date == g.received_at.to_date
        end # each
      end # while
      user_balance_hash[BALANCE_KEY] = balance_sum
      # initialize negative interest hash
      puts "gift id #{g.id}: initialize and save negative interest hash"
      gift_negative_interest_hash = {}
      user_balance_hash.keys.each do |balance_hash_currency|
        next if balance_hash_currency == BALANCE_KEY
        gift_negative_interest = (previous_balance_hash[balance_hash_currency] - user_balance_hash[balance_hash_currency]).abs
        puts "gift id #{g.id}, currency = #{balance_hash_currency}, old = #{previous_balance_hash[balance_hash_currency]}, new = #{user_balance_hash[balance_hash_currency]}, neg.int. = #{gift_negative_interest}"
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
      sign = user_id == g.user_id_giver ? 1 : -1
      user_balance_hash[g.currency] = 0.0 unless user_balance_hash.has_key?(g.currency)
      user_balance_hash[g.currency] += g.price * sign
      user_balance_hash[BALANCE_KEY] += ExchangeRate.exchange((g.price*sign), g.currency, BASE_CURRENCY, date)
      balance_doc_hash[:sign] = sign > 0 ? '+' : '-'
      balance_doc_hash[:balance] = user_balance_hash

      # save balance and balance documentation
      g.set_balance(user_id, user_balance_hash[BALANCE_KEY], balance_doc_hash)
      # g.save
      puts "recalculate_balance. g.id = #{g.id}, g.received_at = #{g.received_at}, balance_hash = #{user_balance_hash.to_s}, balance_doc_hash = #{balance_doc_hash}"
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
    puts "user balance = #{user_balance_hash}"
    puts "user negative_interest #{user_negative_interest_hash}"
    # calculation ok - all needed exchange rates was found
    self.currency = new_currency
    self.balance = user_balance_hash
    self.balance_at = today
    self.negative_interest = user_negative_interest_hash
    # todo: catch any exception and return false if transaction fails
    transaction do
      gifts.each { |g| g.save! }
      self.save!
    end
    true
  end # recalculate_balance

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
  def friend? (login_user)
    return false unless login_user # not logged in
    return true if login_user.user_id == self.user_id
    f = get_friend(login_user)
    return false unless f
    app_friend = f.app_friend || f.api_friend
    (app_friend == 'Y')
  end

  # friend status code. "this" is friend. login_user is login user.
  #   Y - friends
  #   N - not friends
  #   A - login api friends and not app friends
  #   G - gofreerev app friends and not login api friends
  #   R - app friendship request from login user to friend
  #   P - pending app friendship request to login user from friend (todo)
  def friend_status_code (login_user)
    return 'N' unless login_user # not logged in user
    return 'Y' if login_user.user_id == self.user_id
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

  def friend_status_translate_code (login_user)
    ".friend_status_text_#{friend_status_code(login_user).downcase}"
  end

  def find_friend_request_noti (login_user)
    ns = Notification.where("from_user_id = ? and to_user_id = ? and noti_read = 'N'", login_user.user_id, self.user_id)
    return nil unless ns.size > 0
    n = ns.find { |n| n.noti_key == FRIEND_REQUEST_NOTI_KEY }
  end

  # returns list with allowed friendship actions: add_api_friend, remove_api_friend, send_app_friend_request, cancel_app_friend_request, accept_app_friend_request, ignore_app_friend_request, remove_app_friend, block_app_user, unblock_app_user
  # used in users/show page / users/friend_action_buttons partial
  # The action names is also used as keys in translate. See <language>.users.friend_action_buttons.<method>
  # first letter uppercase - confirm box before submit
  # second letter uppercase - new window (target=_blank)
  def friend_status_actions (login_user)
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
    puts "action #{action} was not allowed. Friend status code = #{friend_status_code(login_user)}, allowed actions = #{allowed_friend_actions.join(', ')}"  if  !allowed
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


  def api_profile_url
    case
      when facebook? then "http://facebook.com/#{user_id[3..-1]}"
      when google_plus? then "todo:"
      else nil #error
    end
  end


  def inbox_new_notifications
    return @new_notifications if defined?(@new_notifications)
    @new_notifications = Notification.where("to_user_id = ? and noti_read = 'N'", self.user_id).size
  end

  # refresh user permisssion
  # called in error handling after picture upload with ApiPostNotFoundException error
  # see gifts/create
  def get_api_permissions(access_token)
    raise NoApiAccessTokenException unless access_token
    api = Koala::Facebook::API.new(access_token)
    api_request = 'me?fields=permissions'
    puts "api_request = #{api_request}"
    begin
      api_response = api.get_object(api_request)
    rescue Koala::Facebook::ClientError => e
      puts 'Koala::Facebook::ClientError'
      puts "e.fb_error_type = #{e.fb_error_type}"
      puts "e.fb_error_code = #{e.fb_error_code}"
      puts "e.fb_error_subcode = #{e.fb_error_subcode}"
      puts "e.fb_error_message = #{e.fb_error_message}"
      puts "e.http_status = #{e.http_status}"
      puts "e.response_body = #{e.response_body}"
      puts "e.fb_error_type.class.name = #{e.fb_error_type.class.name}"
      puts "e.fb_error_code.class.name = #{e.fb_error_code.class.name}"
      raise
    end # rescue
    puts "api_response = #{api_response}"
    self.permissions = api_response['permissions']['data'][0]
    self.permissions = {} if self.permissions == []
    save!
    self
  end # get_api_permissions


  # find gifts user can see. user friends must be giver or receiver of gifts
  # show_friends_gifts=true in users/index
  # show_friends_gifts=false in users/show gifts tab
  def gifts (newest_gift_id=0, show_friends_gifts=true)
    # initialize list of gifts
    # list of gifts with @user as giver or receiver + list of gifts med @user.friends as giver or receiver
    # where clause is used for non encrypted fields. find_all is used for encrypted fields

    if show_friends_gifts
      friends = app_friends.collect { |u| u.user_id_receiver }
      friends.push(user_id)
      gs = Gift.where('id > ? and (user_id_giver in (?) or user_id_receiver in (?))', newest_gift_id, friends, friends).includes(:giver, :receiver)
    else
      gs = Gift.where('id > ? and ? in (user_id_giver, user_id_receiver)', newest_gift_id, user_id).includes(:giver, :receiver)
    end

    # find gifts
    gs.sort! do |a,b|
      if (a.received_at || a.created_at.to_date) ==  (b.received_at || b.created_at.to_date)
        b.id <=> a.id
      else
        (b.received_at || b.created_at.to_date) <=>  (a.received_at || a.created_at.to_date)
      end
    end
    return gs if gs.length == 0

    # remove any hidden gifts (show=N) from gifts list
    giftids = gs.collect { |g| g.gift_id }
    hide_giftids = GiftLike.where("user_id = ? and gift_id in (?)", user_id, giftids).find_all { |gl| gl.show == 'N'}.collect { |gl| gl.gift_id }
    return gs if hide_giftids.length == 0

    # remove hidden gifts
    gs = gs.find_all { |g| !hide_giftids.index(g.gift_id) }

    gs

  end # gifts


  # cache mutual friends lookup in @mutual_friends hash index by login_user.id
  def mutual_friends (login_user)
    return @mutual_friends[login_user.id] if @mutual_friends and @mutual_friends.has_key?(login_user.id)
    @mutual_friends = {} unless @mutual_friends
    @mutual_friends[login_user.id] = (app_friends.collect { |f| f.friend } & login_user.app_friends.collect { |f| f.friend }).collect { |u| u.short_user_name }
  end


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

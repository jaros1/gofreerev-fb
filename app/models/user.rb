class User < ActiveRecord::Base

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


  has_many :offers, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :wishes, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_receiver, :dependent => :destroy
  has_many :friends, :class_name => 'Friend', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy

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
  end

  # 2) user_name. User name. String in model. Encrypted text in db. required. is updated when the user logs in.
  validates_presence_of :user_name
  def user_name
    return nil unless (extended_user_name = read_attribute(:user_name))
    encrypt_remove_pre_and_postfix(extended_user_name, 'user_name', 9)
  end
  def user_name=(new_user_name)
    if new_user_name
      puts "new_user_name = #{new_user_name} (#{new_user_name.class.name})"
      check_type('user_name', new_user_name, 'String')
      write_attribute :user_name, encrypt_add_pre_and_postfix(new_user_name, 'user_name', 9)
    else
      write_attribute :user_name, nil
    end
  end
  alias_method :user_name_before_type_cast, :user_name

  # 3) currency. Required. String in model. Encrypted text in db.
  validates_presence_of :currency
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

  # 4) balance. Balance. Required. Multi-currency Hash in model. Encrypted text in db
  # Keys is ISO code for currency USD, EUR, GBP etc.
  # Key BALANCE is sum of all currencies exchanged to users actual currency
  validates_presence_of :balance
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

  # 5) balance_at. Date. Not encrypted. Date for last balance calculation. Normally today.
  validates_presence_of :balance_at

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

  def short_user_name
    a = user_name.split(' ')
    "#{a.first} #{a.last.first(1)}"
  end

  def api_name_without_brackets
    case
      when facebook? then 'facebook'
      when google_plus? then 'google+'
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
    "#{profile_picture_md5_path}/#{profile_picture_filename}"
  end

  # relation helpers
  def gifts_given
    offers.find_all { |g| g.user_id_receiver }.collect { |g| g.recalculate ; g }
  end # gifts_given
  def gifts_received
    wishes.find_all { |g| g.user_id_giver }.collect { |g| g.recalculate ; g }
  end
  def gifts_received_with_sign
    gifts_received.collect do |g|
      g.new_price = -g.new_price
      g
    end # collect
  end # gifts_received_with_sig
  def gifts_given_and_received
    gifts_given + gifts_received_with_sign
  end

  # todo: initialize social dividend hash from negative_currency hash
  def social_dividend
    hash = {}
    negative_interest.each do |name, value|
      hash[name] = value / 4
    end
    hash
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
    balance_hash = { BALANCE_KEY => 0.0 }
    negative_interest_hash = { BALANCE_KEY => 0.0 }
    missing_exchange_rates = false
    gifts.each do |g|
      # update user.balance hash and save balance in gift.balance for documentation
      balance_hash[g.currency] = 0.0 unless balance_hash.has_key?(g.currency)
      balance_hash[g.currency] += g.new_price
      new_price = ExchangeRate.exchange(g.new_price, g.currency, new_currency)
      if new_price
        balance_hash[BALANCE_KEY] += new_price
        g.set_balance(user_id, balance_hash[BALANCE_KEY])
      else
        missing_exchange_rates = true
      end
      # update user.negative_interest hash
      negative_interest_hash[g.currency] = 0 unless negative_interest_hash.has_key?(g.currency)
      negative_interest_hash[g.currency] += g.negative_interest
      new_neg_int = ExchangeRate.exchange(g.negative_interest, g.currency, new_currency)
      if new_neg_int
        negative_interest_hash[BALANCE_KEY] += new_neg_int
      else
        missing_exchange_rates = true
      end
      puts "recalculate_balance. g.new_price = #{g.new_price.to_s}, new_price = #{new_price.to_s}, balance_hash = #{balance_hash.to_s} "
    end # each
    return false if missing_exchange_rates # not all exchange rates was read at this time - they should be updated in a moment
    # calculation ok - all needed exchange rates was found
    self.currency = new_currency
    self.balance = balance_hash
    self.balance_at = Date.today
    self.negative_interest = negative_interest_hash
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
    return @friend if defined?(@friend)
    @friend = login_user.friends.find_all { |f| f.user_id_receiver == self.user_id }.first
  end

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
        when 'N' then return 'N' # user has been deselected as app friend by login user or friendship request has been blocked login user
        when 'R' then return 'R' # pending friendship request from login user
        when 'P' then return 'P'
      end # case
    else
      # non api friend
      case f.app_friend
        when nil then return 'N'
        when 'Y' then return 'G' # not login api friends - only friends within gofreerev app
        when 'N' then return 'N' # user has been deselected as app friend by login user or friendship request has been blocked login user
        when 'R' then return 'R' # pending friendship request from login user
        when 'P' then return 'P'
      end # case
    end
  end

  def friend_status_translate_code (login_user)
    ".friend_status_text_#{friend_status_code(login_user).downcase}"
  end

  # returns list with allowed friendship actions: add_api_friend, remove_api_friend, add_app_friend, accept_app_friend, ignore_app_friend, remove_app_friend, block_app_friend, unblock_app_friend
  # used in users/show page / users/friend_action_buttons partial
  # The action names is also used as keys in translate. See <language>.users.friend_action_buttons.<method>
  # first letter uppercase - confirm box before submit
  # second letter uppercase - new window (target=_blank)
  def friend_status_actions (login_user)
    case friend_status_code(login_user)
      when 'Y' then return %w(rEmove_api_friend Remove_app_friend)
      when 'N' then return %w(aDd_api_friend add_app_friend)
      when 'A' then return %w(rEmove_api_friend add_app_friend)
      when 'G' then return %w(aDd_api_friend Remove_app_friend)
      when 'R' then return %w(aDd_api_friend add_app_friend)
      when 'P' then return %w(aDd_api_friend accept_app_friend ignore_app_friend Block_app_friend)
      when 'B' then return %w(unblock_app_friend)
    end
  end # friend_status_actions
  def allowed_friend_status_action (login_user, action)
    allowed_friend_actions = friend_status_actions(login_user).collect { |fa| fa.downcase }
    allowed_friend_actions(action)
  end
  def add_api_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not used. no facebook api dialog to add friend"
  end
  def remove_api_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not used. no facebook api dialog to remove friend"
  end
  def add_app_friend (login_user)
    # set api_friend = R for login user, set api_friend = P for friend
    return unless allowed_friend_status_action(login_user, __method__)
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
      n = Notification.new
      n.to_user_id = self.user_id
      n.from_user_id = login_user.user_id
      n.internal = 'Y'
      n.noti_t_key = 'request_for_app_friendship'
      n.noti_t_options = {}
      n.noti_read = 'N'
    end
    transaction do
      f.save!
      r.save!
      n.save! if n
    end
  end # add_app_friend
  def accept_app_friend (login_user)
    # set api_friend = Y for login user and friend
    return unless allowed_friend_status_action(login_user, __method__)
    f = get_friend (login_user)
    r = get_reverse_friend(login_user)
    raise "invalid request" if !f or !r or f.app_friend != 'P' or r.app_friend != 'R'
    f.app_friend = 'Y'
    r.app_friend = 'Y'
    n = Notification.new
    n.to_user_id = self.user_id
    n.from_user_id = login_user.user_id
    n.internal = 'Y'
    n.noti_t_key = 'app_friendship_accepted'
    n.noti_t_options = {}
    n.noti_read = 'N'
    transaction do
      f.save!
      r.save!
      n.save!
    end
  end # accept_app_friend
  def ignore_app_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not implemented"
  end
  def remove_app_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not implemented"
  end
  def block_app_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not implemented"
  end
  def unblock_app_friend (login_user)
    return unless allowed_friend_status_action(login_user, __method__)
    raise "not implemented"
  end


  def api_profile_url
    case
      when facebook? then "http://facebook.com/#{user_id[3..-1]}"
      when google_plus? then "todo:"
      else nil #error
    end
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

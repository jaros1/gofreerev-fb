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

  # attributes
  #   user_id    - Unique user-id - not encrypted - PK
  #                Format fb-<userid> = facebook user
  #                Format gp-<xxxxxx> = google+ user
  #   user_name  - encrypted
  #   currency   - encrypted
  #   balance    - encrypted - BigDecimal
  #   balance_at - date for last balance calculation
  #   created_at - timestamp - not encrypted
  #   updated_at - timestamp - not encrypted


  has_many :offers, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_giver, :dependent => :destroy
  has_many :gifts_received, :class_name => 'Gift', :primary_key => :user_id, :foreign_key => :user_id_receiver, :dependent => :destroy


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  crypt_keeper :user_name, :currency, :balance, :permissions, :encryptor => :aes, :key => ENCRYPT_KEYS[0]


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

  # 4) balance. Balance. Required. BigDecimal in model. Encrypted text in db
  validates_presence_of :balance
  def balance
    return nil unless (temp_extended_balance = read_attribute(:balance))
    # puts "temp_extended_balance = #{temp_extended_balance}"
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_balance, 'balance', 11)
  end # balance
  def balance=(new_balance)
    if new_balance
      check_type('balance', new_balance, 'BigDecimal')
      write_attribute :balance, encrypt_add_pre_and_postfix(new_balance.to_s, 'balance', 11)
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
    return user_id.first(2)
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
         permissions["status_update"] == 1
      else
        puts "post_on_wall? not impleented for #{user_id.first(2)} users"
        false
    end
  end # post_gift_allowed?

  # profile picture helpers - a copy of profile picture is downloaded at login
  def profile_picture_filename
    "#{id}.#{profile_picture_type}"
  end
  def profile_picture_md5_path
    md5 = Digest::MD5.hexdigest(user_id).downcase
    folders = ["profiles"] + md5 = md5.scan(/.{2}/)
    folders.join('/')
  end
  def profile_picture_os_folder
    Rails.root.join('public', "images", profile_picture_md5_path).to_s
  end
  def profile_picture_os_filename
    "#{profile_picture_os_folder}/#{profile_picture_filename}"
  end
  def profile_picture_url
    "#{profile_picture_md5_path}/#{profile_picture_filename}"
  end

  def gifts_given
    offers.find_all { |g| g.user_id_receiver }.collect { |g| g.recalculate ; g }
  end
  def gifts_received_with_sign
    gs = gifts_received.collect { |g| g.recalculate ; g.new_price = -g.new_price ; g }
  end
  def gifts_given_and_received
    gifts_given + gifts_received_with_sign
  end

  def recalculate_balance (new_currency=nil)
    new_currency = currency unless new_currency
    # recalculate balance in new currency
    # currency and balance is not recalculated if exchange rates are missing
    new_balance = BigDecimal.new "0"
    missing_exchange_rates = false
    gifts_given_and_received.each do |g|
      new_price = ExchangeRate.exchange(g.new_price, g.currency, new_currency)
      puts "recalculate_balance. "
      if new_price.currency.to_s == new_currency
        new_balance = new_balance + new_price.to_f
      else
        missing_exchange_rates = true
      end
      puts "recalculate_balance. g.new_price = #{g.new_price.to_s}, new_price = #{new_price.to_s}, new_balance = #{new_balance.to_s} "
    end # each
    return false if missing_exchange_rates # not all exchange rates was read at this time - they should be updated in a moment
    # calculation ok - all needed exchange rates was found
    self.currency = new_currency
    self.balance = new_balance
    return true
  end # recalculate_balance

  def balance_with_2_decimals
    "%0.2f" % (balance || 0)
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

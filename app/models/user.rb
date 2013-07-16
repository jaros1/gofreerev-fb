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
  #                Format FB-<userid> = facebook user
  #                Format GP-<xxxxxx> = google+ user
  #   user_name  - encrypted
  #   currency   - encrypted
  #   balance    - encrypted - BigDecimal
  #   balance_at - date for last balance calculation
  #   created_at - timestamp - not encrypted
  #   updated_at - timestamp - not encrypted


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  crypt_keeper :user_name, :currency, :balance, :permissions, :encryptor => :aes, :key => ENCRYPT_KEYS[0]


  ##############
  # attributes #
  ##############

  # 1) user_id. required unique USER id, fx. FB-1234567890. Not encrypted. PK and user in encryption
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
    puts "temp_extended_balance = #{temp_extended_balance}"
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
  # for FB users a hash with grants privs {"installed"=>1, "basic_info"=>1, "bookmarked"=>1}
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


  ##################
  # helper methods #
  ##################

  def self.facebook_user_prefix
    'FB-'
  end # facebook_user_prefix
  def self.google_plus_user_prefix
    'GP-'
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

  # add login api to user name
  def user_name_with_api
    api = case
            when facebook?
              ' (facebook)'
            when google_plus?
              ' (google+)'
            else nil
          end
    "#{user_name}#{api}"
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

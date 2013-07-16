class Gift < ActiveRecord::Base

=begin
  create_table "gifts", force: true do |t|
    t.integer  "gift_id"                                    - PK - not encrypted
    t.text     "description",                  null: false  - encrypted
    t.text     "currency"                      null: false  - encrypted
    t.text     "price"                                      - encrypted BigDecimal
    t.string   "user_id_giver",     limit: 20, null: false  - FK - not encrypted
    t.string   "user_id_receiver",  limit: 20               - FK - not encrypted
    t.text     "received_at"                                - encrypted Date
    t.date     "new_price_at"                               - not encrypted, normally = today
    t.text     "new_price"                                  - encrypted BigDecimal
    t.text     "negative_interest"                          - encrypted BigDecimal
    t.text     "social_dividend"                            - encrypted BigDecimal
    t.datetime "created_at"                                 - not encrypted
    t.datetime "updated_at"                                 - not encrypted
  end
=end

  # general: all text columns are encrypted in database
  # gift_id           is an internal unique pk key / sequence
  # description       is the encrypted post in fb/google+ wall
  # currency          eg DKK is required if the gifts has as price. DKK => FREE-DKK. Default currency from country
  # price             is optional. Can be set by giver or by receiver. Can be changed until closed
  # user_id_giver     is user_id for giver / seller
  # user_id_receiver  is user_id for receiver / buyer
  # received_at       when was the present received / when was the deal closed
  # new_price_at      when was the new price last calculated
  # new_price         price - negative_interest
  # negative_interest 0.02 % per day = 7.6 % per year
  # social_dividend   abs(nnegative_interest / 4). Distributed to both users. 0.01 % per day = 3.8 % per year

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


  ##############
  # attributes #
  ##############

  # 1) gift_id - required - not encrypted - readonly
  validates_presence_of :gift_id
  validates_uniqueness_of :gift_id
  attr_readonly :gift_id
  before_validation(on: :create) do
    self.gift_id = self.new_encrypt_pk unless self.gift_id
  end
  def gift_id=(new_gift_id)
    return self['gift_id'] if self['gift_id']
    self['gift_id'] = new_gift_id
  end

  # 2) description - required - String in model - encrypted text in db - update not allowed
  validates_presence_of :description
  attr_readonly :description
  def description
    return nil unless (extended_description = read_attribute(:description))
    encrypt_remove_pre_and_postfix(extended_description, 'description', 2)
  end
  def description=(new_description)
    if new_description
      check_type('description', new_description, 'String')
      write_attribute :description, encrypt_add_pre_and_postfix(new_description, 'description', 2)
    else
      write_attribute :description, nil
    end
  end
  alias_method :description_before_type_cast, :description

  # 3) currency - required - String in model - encrypted text in db - update mot allowed
  validates_presence_of :currency
  attr_readonly :currency
  def currency
    return nil unless (extended_currency = read_attribute(:currency))
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 3)
  end
  def currency=(new_currency)
    if new_currency
      check_type('currency', new_currency, 'String')
      write_attribute :currency, encrypt_add_pre_and_postfix(new_currency, 'currency', 3)
    else
      write_attribute :currency, nil
    end
  end # currency
  alias_method :currency_before_type_cast, :currency



  # 4) price - BigDecimal in model - encrypted text in db
  # change not allowed if received_at is not null / deal is closed
  def price
    return nil unless (temp_extended_price = read_attribute(:price))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 4)
  end # price
  def price=(new_price)
    if new_price
      check_type('price', new_price, 'BigDecimal')
      write_attribute :price, encrypt_add_pre_and_postfix(new_price.to_s, 'price', 4)
    else
      write_attribute :price, nil
    end
  end # price=
  alias_method :price_before_type_cast, :price

  # 5) user_id_giver - my user id - required - FK - not encrypted
  validates_presence_of :user_id_giver

  # 6) user_id_receiver - added when received_at is set - FK - not encrypted

  # 7) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def received_at
    return nil unless (temp_extended_received_at = read_attribute(:received_at))
    temp_received_at = encrypt_remove_pre_and_postfix(temp_extended_received_at, 'received_at', 5)
    YAML::load(temp_received_at)
  end
  def received_at=(new_received_at)
    if new_received_at
      check_type('received_at', new_received_at, 'Date')
      write_attribute :received_at, encrypt_add_pre_and_postfix(new_received_at.to_yaml, 'received_at', 5)
    else
      write_attribute :received_at, nil
    end
  end
  alias_method :received_at_before_type_cast, :received_at

  # 8) new_price_at - date - not encrypted - almost always = today

  # 9) new_price - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def new_price
    return nil unless (temp_extended_new_price = read_attribute(:new_price))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_new_price, 'new_price', 6)
  end # new_price
  def new_price=(new_new_price)
    if new_new_price
      check_type('new_price', new_new_price, 'BigDecimal')
      write_attribute :new_price, encrypt_add_pre_and_postfix(new_new_price.to_s, 'new_price', 6)
    else
      write_attribute :new_price, nil
    end
  end # new_price=
  alias_method :new_price_before_type_cast, :new_price

  # 10) negative_interest - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def negative_interest
    return nil unless (temp_extended_negative_interest = read_attribute(:negative_interest))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_negative_interest, 'negative_interest', 7)
  end # negative_interest
  def negative_interest=(new_negative_interest)
    if new_negative_interest
      check_type('negative_interest', new_negative_interest, 'BigDecimal')
      write_attribute :negative_interest, encrypt_add_pre_and_postfix(new_negative_interest.to_s, 'negative_interest', 7)
    else
      write_attribute :negative_interest
    end
  end # negative_interest=
  alias_method :negative_interest_before_type_cast, :negative_interest

  # 11) social_dividend - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price
  def social_dividend
    return nil unless (temp_extended_social_dividend = read_attribute(:social_dividend))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_social_dividend, 'social_dividend', 8)
  end # negative_interest
  def social_dividend=(new_social_dividend)
    if new_social_dividend
      check_type('social_dividend', new_social_dividend, 'BigDecimal')
      write_attribute :social_dividend, encrypt_add_pre_and_postfix(new_social_dividend.to_s, 'social_dividend', 8)
    else
      write_attribute :social_dividend, nil
    end
  end # social_dividend=
  alias_method :social_dividend_before_type_cast, :social_dividend

  # 12) created_at - timestamp - not encrypted

  # 13) updated_at - timestamp - not encrypted


  #
  # helper methods
  #


  # psydo attribute file - only used if create gift fails
  attr_accessor :file

  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
  # overwrite non model specific methods defined in /config/initializers/active_record_extensions.rb
    protected
    def encrypt_pk
      self.gift_id
    end
    def encrypt_pk=(new_encrypt_pk_value)
      self.gift_id = new_encrypt_pk_value
    end
    def new_encrypt_pk
      temp_gift_id = nil
      loop do
        temp_gift_id = String.generate_random_string(20)
        return temp_gift_id unless Gift.find_by_gift_id(temp_gift_id)
      end
    end


end # Gift

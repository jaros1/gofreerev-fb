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
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


  ##############
  # attributes #
  ##############

  # 1) gift_id - required - not encrypted - readonly
  validates_presence_of :gift_id
  validates_uniqueness_of :gift_id
  attr_readonly :gift_id
  before_validation(on: :create) do
    self.gift_id = Gift.new_gift_id unless self.gift_id
  end
  def gift_id=(new_gift_id)
    return self['gift_id'] if self['gift_id']
    self['gift_id'] = new_gift_id
  end

  # 2) description - required - String in model - encrypted text in db - update not allowed
  validates_presence_of :description
  attr_readonly :currency
  def description
    return nil unless (extended_description = self['description'])
    encrypt_remove_pre_and_postfix(extended_description, 'description', 2)
  end
  def description=(new_description)
    if new_description
      check_type('description', new_description, 'String')
      self['description'] = encrypt_add_pre_and_postfix(new_description, 'description', 2)
    else
      self['description'] = nil
    end
  end

  # 3) currency - required - String in model - encrypted text in db - update mot allowed
  validates_presence_of :currency
  attr_readonly :currency
  def currency
    return nil unless (extended_currency = self['currency'])
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 3)
  end
  def currency=(new_currency)
    if new_currency
      check_type('currency', new_currency, 'String')
      self['currency'] = encrypt_add_pre_and_postfix(new_currency, 'currency', 3)
    else
      self['currency'] = nil
    end
  end # currency



  # 4) price - BigDecimal in model - encrypted text in db
  # change not allowed if received_at is not null / deal is closed
  def price
    return nil unless (temp_extended_price = self['price'])
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 4)
  end # price
  def price=(new_price)
    if new_price
      check_type('price', new_price, 'BigDecimal')
      self['price'] = encrypt_add_pre_and_postfix(new_price.to_s, 'price', 4)
    else
      self['price'] = nil
    end
  end # price=

  # 5) user_id_giver - my user id - required - FK - not encrypted
  validates_presence_of :user_id_giver

  # 6) user_id_receiver - added when received_at is set - FK - not encrypted

  # 7) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def received_at
    return nil unless (temp_extended_received_at = self['received_at'])
    temp_received_at = encrypt_remove_pre_and_postfix(temp_extended_received_at, 'received_at', 5)
    YAML::load(temp_received_at)
  end
  def received_at=(new_received_at)
    if new_received_at
      check_type('received_at', new_received_at, 'Date')
      self['received_at'] = encrypt_add_pre_and_postfix(new_received_at.to_yaml, 'received_at', 5)
    else
      self['received_at'] = nil
    end
  end

  # 8) new_price_at - date - not encrypted - almost always = today

  # 9) new_price - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def new_price
    return nil unless (temp_extended_new_price = self['new_price'])
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_new_price, 'new_price', 6)
  end # new_price
  def new_price=(new_new_price)
    if new_new_price
      check_type('new_price', new_new_price, 'BigDecimal')
      self['new_price'] = encrypt_add_pre_and_postfix(new_new_price.to_s, 'new_price', 6)
    else
      self['new_price'] = nil
    end
  end # new_price=

  # 10) negative_interest - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def negative_interest
    return nil unless (temp_extended_negative_interest = self['negative_interest'])
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_negative_interest, 'negative_interest', 7)
  end # negative_interest
  def negative_interest=(new_negative_interest)
    if new_negative_interest
      check_type('negative_interest', new_negative_interest, 'BigDecimal')
      self['negative_interest'] = encrypt_add_pre_and_postfix(new_negative_interest.to_s, 'negative_interest', 7)
    else
      self['negative_interest'] = nil
    end
  end # negative_interest=

  # 11) social_dividend - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price
  def social_dividend
    return nil unless (temp_extended_social_dividend = self['social_dividend'])
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_social_dividend, 'social_dividend', 8)
  end # negative_interest
  def social_dividend=(new_social_dividend)
    if new_social_dividend
      check_type('social_dividend', new_social_dividend, 'BigDecimal')
      self['social_dividend'] = encrypt_add_pre_and_postfix(new_social_dividend.to_s, 'social_dividend', 8)
    else
      self['social_dividend'] = nil
    end

  end # social_dividend=

  # 12) created_at - timestamp - not encrypted

  # 13) updated_at - timestamp - not encrypted


  #
  # helper methods
  #

  # private
  def check_type (attributename, attributevalue, classname)
    return unless attributevalue
    return if attributevalue.class.name == classname
    raise TypeError, "Invalid type #{attributename.class.name} for attribute #{attributename}. " +
                     "Allowed types are NilClass and #{classname}"
  end # check_type


  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
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

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
  # ( same key for all attributes and all rows in database )
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


  ##############
  # attributes #
  ##############

  # gift_id - required - readonly
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

  # description - required - encrypted i db by crypt_keeper
  validates_presence_of :description

  # currency - encrypted in db by crypt_keeper - not null - can not be changed
  validates_presence_of :description

  # price - BigDecimal in model - encrypted text in db - change not allowed if received_at is not null / deal is closed
  # different encryption for each attribute and row in database
  def price
    return nil unless self['price']
    temp_extended_price = self['price']
    temp_price = encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 5)
    BigDecimal.new temp_price
  end # price
  def price=(new_price)
    if new_price
      check_type('price', new_price, 'BigDecimal')
      temp_price =  new_price.to_s
      temp_extended_price = encrypt_add_pre_and_postfix(temp_price, 'price', 5) # different key for each field and row in database
      self['price'] = temp_extended_price
    else
      self['price'] = nil
    end
  end # price=

  # user_id_giver - my user id - required - FK - not encrypted
  validates_presence_of :user_id_giver

  # user_id_receiver - added when received_at is set - FK - not encrypted

  # received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def received_at
    return nil unless self['received_at']
    YAML::load(self['received_at'])
  end
  def received_at=(new_received_at)
    if  new_received_at
      check_type('received_at', new_received_at, 'Date')
      self['received_at'] = new_received_at.to_yaml
    else
      self['received_at'] = nil
    end
  end


  # new_price_at - date - not encrypted - almost always = today

  # new_price - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price
  def new_price
    return nil unless self['new_price']
    BigDecimal.new self['new_price']
  end # new_price
  def new_price=(new_new_price)
    if new_new_price
      check_type('new_price', new_new_price, 'BigDecimal')
      self['new_price'] = new_new_price.to_s
    else
      self['new_price'] = nil
    end
  end # new_price=

  # negative_interest - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price
  def negative_interest
    return nil unless self['new_price']
    BigDecimal.new self['new_price']
  end # negative_interest
  def negative_interest=(new_negative_interest)
    if new_negative_interest
      check_type('negative_interest', new_negative_interest, 'BigDecimal')
      self['negative_interest'] = new_negative_interest.to_s
    else
      self['negative_interest'] = nil
    end
  end # negative_interest=

  # social_dividend - BigDecimal in model - encrypted text in db - recalculated once every day for closed deals with a price
  def social_dividend
    return nil unless self['social_dividend']
    BigDecimal.new self['social_dividend']
  end # negative_interest
  def social_dividend=(new_social_dividend)
    if new_social_dividend
      check_type('social_dividend', new_social_dividend, 'BigDecimal')
      self['social_dividend'] = new_social_dividend.to_s
    else
      self['social_dividend'] = nil
    end

  end # social_dividend=

  # created_at - timestamp - not encrypted

  # updated_at - timestamp - not encrypted


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

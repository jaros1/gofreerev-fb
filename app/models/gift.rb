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
    t.text     "api_gift_id"                                - encrypted
    t.datetime "created_at"                                 - not encrypted
    t.datetime "updated_at"                                 - not encrypted
  end
=end


  belongs_to :giver, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_giver
  belongs_to :receiver, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_receiver
  has_many :comments, :class_name => 'Comment', :primary_key => :gift_id, :foreign_key => :gift_id, :dependent => :destroy
  has_many :likes, :class_name => 'GiftLike', :primary_key => :gift_id, :foreign_key => :gift_id, :dependent => :destroy

  before_create :before_create

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :api_gift_id, :balance_giver, :balance_receiver, :api_picture_url, :api_picture_url_updated_at, :api_picture_url_on_error_at, :balance_doc_giver, :balance_doc_receiver, :social_dividend_doc, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


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
    # puts "gift.description: description = #{read_attribute(:description)} (#{read_attribute(:description).class.name})"
    return nil unless (extended_description = read_attribute(:description))
    encrypt_remove_pre_and_postfix(extended_description, 'description', 2)
  end
  def description=(new_description)
    # puts "gift.description=: description = #{new_description} (#{new_description.class.name})"
    if new_description
      check_type('description', new_description, 'String')
      write_attribute :description, encrypt_add_pre_and_postfix(new_description, 'description', 2)
    else
      write_attribute :description, nil
    end
  end
  alias_method :description_before_type_cast, :description
  def description_was
    return description unless description_changed?
    return nil unless (extended_description = attribute_was(:description))
    encrypt_remove_pre_and_postfix(extended_description, 'description', 2)
  end # description_was

  # 3) currency - required - String in model - encrypted text in db - update not allowed
  validates_presence_of :currency
  validates_inclusion_of :currency, :allow_blank => true, :in => Money::Currency.table.collect { |a| [  a[1][:iso_code] ][0] }
  validates_each :currency do |record, attr, value|
    if record.new_record? or !record.currency_changed?
      nil # new record or unchanged currency - always ok
    elsif !record.received_at_was and record.received_at
      nil # deal has just been approved - currency and price have just been copied from proposal
    else
      # puts "Gift.validates_each currency: gift id #{record.id}, old value = #{record.currency_was}, new value = #{value}"
      record.errors.add attr, :readonly
    end
  end # validates_each :currency
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
  def currency_was
    return currency unless currency_changed?
    return nil unless (extended_currency = attribute_was('currency'))
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 3)
  end # currency_was

  # 4) price - Float in model - encrypted text in db
  validates_each :price do |record, attr, value|
    if record.new_record? or value == record.price_was
      nil # new record or unchanged price - always ok
    elsif !record.received_at_was and record.received_at
      nil # deal has just been approved - copy currency and price from proposal
    else
      record.errors.add attr, :readonly
    end
  end
  def price
    return nil unless (temp_extended_price = read_attribute(:price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 4)
  end # price
  def price=(new_price)
    if new_price.to_s != ''
      check_type('price', new_price, 'Float')
      write_attribute :price, encrypt_add_pre_and_postfix(new_price.to_s, 'price', 4)
    else
      write_attribute :price, nil
    end
  end # price=
  alias_method :price_before_type_cast, :price
  def price_was
    return price unless price_changed?
    return nil unless (temp_extended_price = attribute_was('price'))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 4)
  end # price_was

  # 5) user_id_giver - FK - not encrypted.
  # validates_presence_of :user_id_giver, :if => Proc.new {|g| (g.received_at or !g.user_id_receiver) }
  validates_each :user_id_giver do |record, attr, value|
    if record.new_record?
      record.errors.add :base, :giver_or_receiver_must_be_blank if value and record.user_id_receiver and record.gifttype == 'G'
      record.errors.add :base, :giver_or_receiver_is_required if !value and !record.user_id_receiver
    elsif record.user_id_giver_was and record.user_id_giver_was != value
      record.errors.add attr, :readonly
    elsif record.received_at and !value
      record.errors.add attr, :empty
    end
  end

  # 6) user_id_receiver - FK - not encrypted. Gift must have a giver or an receiver when created. Must have giver and receiver when closed
  # validates_presence_of :user_id_receiver, :if => Proc.new {|g| (g.received_at or !g.user_id_giver) }
  validates_each :user_id_receiver do |record, attr, value|
    if record.new_record?
      nil if value and record.user_id_giver # error already reported for user_id_giver
      nil if !value and !record.user_id_giver # # error already reported for user_id_giver
    elsif record.user_id_receiver_was and record.user_id_receiver_was != value
      record.errors.add attr, :readonly
    elsif record.received_at and !value
      record.errors.add attr, :empty
    end
  end

  # 7) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def received_at
    return nil unless (temp_extended_received_at = read_attribute(:received_at))
    temp_received_at1 = encrypt_remove_pre_and_postfix(temp_extended_received_at, 'received_at', 5)
    temp_received_at2 = YAML::load(temp_received_at1)
    temp_received_at2 = temp_received_at2.to_time if temp_received_at2.class.name == 'Date'
    temp_received_at2
  end # received_at
  def received_at=(new_received_at)
    if new_received_at
      check_type('received_at', new_received_at, 'Time')
      write_attribute :received_at, encrypt_add_pre_and_postfix(new_received_at.to_yaml, 'received_at', 5)
    else
      write_attribute :received_at, nil
    end
  end # received_at=
  alias_method :received_at_before_type_cast, :received_at
  def received_at_was
    return received_at unless received_at_changed?
    return nil unless (temp_extended_received_at = attribute_was('received_at'))
    temp_received_at1 = encrypt_remove_pre_and_postfix(temp_extended_received_at, 'received_at', 5)
    temp_received_at2 = YAML::load(temp_received_at1)
    temp_received_at2 = temp_received_at2.to_time if temp_received_at2.class.name == 'Date'
    temp_received_at2
  end # received_at_was

  # 8) new_price_at - date - not encrypted - almost always = today

  # 9) new_price - Float in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def new_price
    return nil unless (temp_extended_new_price = read_attribute(:new_price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_new_price, 'new_price', 6)
  end # new_price
  def new_price=(new_new_price)
    if new_new_price.to_s != ''
      check_type('new_price', new_new_price, 'Float')
      write_attribute :new_price, encrypt_add_pre_and_postfix(new_new_price.to_s, 'new_price', 6)
    else
      write_attribute :new_price, nil
    end
  end # new_price=
  alias_method :new_price_before_type_cast, :new_price
  def new_price_was
    return new_price unless new_price_changed?
    return nil unless (temp_extended_new_price = attribute_was(:new_price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_new_price, 'new_price', 6)
  end # new_price_was

  # 10) negative_interest - Float in model - encrypted text in db - recalculated once every day for closed deals with a price and a receiver
  def negative_interest
    return nil unless (tmp_extended_negative_interest = read_attribute(:negative_interest))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(tmp_extended_negative_interest, 'negative_interest', 7)
  end # negative_interest
  def negative_interest=(new_neg_int)
    if new_neg_int.to_s != ''
      check_type('negative_interest', new_neg_int, 'Float')
      write_attribute :negative_interest, encrypt_add_pre_and_postfix(new_neg_int.to_s, 'negative_interest', 7)
    else
      write_attribute :negative_interest, nil
    end
  end # negative_interest=
  alias_method :negative_interest_before_type_cast, :negative_interest
  def negative_interest_was
    return negative_interest unless negative_interest_changed?
    return nil unless (tmp_extended_negative_interest = attribute_was(:negative_interest))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(tmp_extended_negative_interest, 'negative_interest', 7)
  end # negative_interest_was

  # 11) social_dividend - Float in model - encrypted text in db - recalculated once every day for closed deals with a price
  def social_dividend
    return nil unless (temp_extended_social_dividend = read_attribute(:social_dividend))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_social_dividend, 'social_dividend', 8)
  end # negative_interest
  def social_dividend=(new_social_dividend)
    if new_social_dividend.to_s != ''
      check_type('social_dividend', new_social_dividend, 'Float')
      write_attribute :social_dividend, encrypt_add_pre_and_postfix(new_social_dividend.to_s, 'social_dividend', 8)
    else
      write_attribute :social_dividend, nil
    end
  end # social_dividend=
  alias_method :social_dividend_before_type_cast, :social_dividend
  def social_dividend_was
    return social_dividend unless social_dividend_changed?
    return nil unless (temp_extended_social_dividend = attribute_was(:social_dividend))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_social_dividend, 'social_dividend', 8)
  end # social_dividend_was

  # 12) api_gift_id - String in model - encrypted text in db - api id for the gift / status update on the wall
  attr_readonly :api_gift_id
  def api_gift_id
    return nil unless (extended_api_gift_id = read_attribute(:api_gift_id))
    encrypt_remove_pre_and_postfix(extended_api_gift_id, 'api_gift_id', 24)
  end
  def api_gift_id=(new_api_gift_id)
    return api_gift_id if self.api_gift_id
    if new_api_gift_id
      check_type('api_gift_id', new_api_gift_id, 'String')
      write_attribute :api_gift_id, encrypt_add_pre_and_postfix(new_api_gift_id, 'api_gift_id', 24)
    else
      write_attribute :api_gift_id, nil
    end
  end # api_gift_id=
  alias_method :api_gift_id_before_type_cast, :api_gift_id
  def api_gift_id_was
    return api_gift_id unless api_gift_id_changed?
    return nil unless (extended_api_gift_id = attribute_was(:api_gift_id))
    encrypt_remove_pre_and_postfix(extended_api_gift_id, 'api_gift_id', 24)
  end # api_gift_id_was

  # 13) gifttype - String in model and DB - G if gift - S if exchanged social dividend
  # gifttype = G : social dividend = ( new_price - price) / 4
  # gifttype = S : social divident = new_price when price = social dividend exchanged between the two users.
  validates_presence_of :gifttype
  validates_inclusion_of :gifttype, :allow_blank => true, :in => %W(G S)

  # 14) field social_dividend_from has been moved to social_dividend_doc hash

  # 15) balance giver - Float in Model. Encrypted text in db.
  def balance_giver
    return nil unless (extended_balance_giver = read_attribute(:balance_giver))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(extended_balance_giver, 'balance_giver', 25)
  end # balance_giver
  def balance_giver=(new_balance_giver)
    if new_balance_giver.to_s != ''
      check_type('balance_giver', new_balance_giver, 'Float')
      write_attribute :balance_giver, encrypt_add_pre_and_postfix(new_balance_giver.to_s, 'balance_giver', 25)
    else
      write_attribute :balance_giver, nil
    end
  end # balance_giver=
  alias_method :balance_giver_before_type_cast, :balance_giver
  def balance_giver_was
    return balance_giver unless balance_giver_changed?
    return nil unless (extended_balance_giver = attribute_was(:balance_giver))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(extended_balance_giver, 'balance_giver', 25)
  end # balance_giver_was

  # 16) balance receiver - Float in model - encrypted text in db
  def balance_receiver
    return nil unless (extended_balance_receiver = read_attribute(:balance_receiver))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(extended_balance_receiver, 'balance_receiver', 26)
  end
  def balance_receiver=(new_balance_receiver)
    if new_balance_receiver.to_s != ''
      check_type('balance_receiver', new_balance_receiver, 'Float')
      write_attribute :balance_receiver, encrypt_add_pre_and_postfix(new_balance_receiver.to_s, 'balance_receiver', 26)
    else
      write_attribute :balance_receiver, nil
    end
  end
  alias_method :balance_receiver_before_type_cast, :balance_receiver
  def balance_receiver_was
    return balance_receiver unless balance_receiver_changed?
    return nil unless (extended_balance_receiver = attribute_was(:balance_receiver))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(extended_balance_receiver, 'balance_receiver', 26)
  end # balance_receiver_was

  # 17) picture Y/N - String - not encrypted
  validates_presence_of :picture
  validates_inclusion_of :picture, :allow_blank => true, :in => %w(Y N) ;
  validates_each :picture, :allow_blank => true do |record, attr, value|
    record.errors.add attr, :invalid if value == 'Y' and record.api_picture_url.to_s == ""
  end
  
  # 18) api_picture_url - String in Model - encrypted text in db
  validates_presence_of :api_picture_url, :if => Proc.new { |rec| rec.picture == 'Y' }
  def api_picture_url
    # puts "gift.api_picture_url: api_picture_url = #{read_attribute(:api_picture_url)} (#{read_attribute(:api_picture_url).class.name})"
    return nil unless (extended_api_picture_url = read_attribute(:api_picture_url))
    encrypt_remove_pre_and_postfix(extended_api_picture_url, 'api_picture_url', 23)
  end # api_picture_url
  def api_picture_url=(new_api_picture_url)
    # puts "gift.api_picture_url=: api_picture_url = #{new_api_picture_url} (#{new_api_picture_url.class.name})"
    if new_api_picture_url
      check_type('api_picture_url', new_api_picture_url, 'String')
      write_attribute :api_picture_url, encrypt_add_pre_and_postfix(new_api_picture_url, 'api_picture_url', 23)
    else
      write_attribute :api_picture_url, nil
    end
  end # api_picture_url=
  alias_method :api_picture_url_before_type_cast, :api_picture_url
  def api_picture_url_was
    return api_picture_url unless api_picture_url_changed?
    return nil unless (extended_api_picture_url = attribute_was(:api_picture_url))
    encrypt_remove_pre_and_postfix(extended_api_picture_url, 'api_picture_url', 23)
  end # api_picture_url_was

  # 19) api_picture_url_updated_at - timestamp in model - encrypted text 
  def api_picture_url_updated_at
    return nil unless (temp_extended_api_picture_url_updated_at = read_attribute(:api_picture_url_updated_at))
    temp_api_picture_url_updated_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_updated_at, 'api_picture_url_updated_at', 21)
    YAML::load(temp_api_picture_url_updated_at)
  end # api_picture_url_updated_at
  def api_picture_url_updated_at=(new_api_picture_url_updated_at)
    if new_api_picture_url_updated_at
      check_type('api_picture_url_updated_at', new_api_picture_url_updated_at, 'Time')
      write_attribute :api_picture_url_updated_at, encrypt_add_pre_and_postfix(new_api_picture_url_updated_at.to_yaml, 'api_picture_url_updated_at', 21)
    else
      write_attribute :api_picture_url_updated_at, nil
    end
  end # api_picture_url_updated_at=
  alias_method :api_picture_url_updated_at_before_type_cast, :api_picture_url_updated_at
  def api_picture_url_updated_at_was
    return api_picture_url_updated_at unless api_picture_url_updated_at_changed?
    return nil unless (temp_extended_api_picture_url_updated_at = attribute_was(:api_picture_url_updated_at))
    temp_api_picture_url_updated_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_updated_at, 'api_picture_url_updated_at', 21)
    YAML::load(temp_api_picture_url_updated_at)
  end # api_picture_url_updated_at_was

  # 20) api_picture_url_on_error_at - timestamp in model - encrypted text (todo) in db
  def api_picture_url_on_error_at
    return nil unless (temp_extended_api_picture_url_on_error_at = read_attribute(:api_picture_url_on_error_at))
    temp_api_picture_url_on_error_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_on_error_at, 'api_picture_url_on_error_at', 22)
    YAML::load(temp_api_picture_url_on_error_at)
  end # api_picture_url_on_error_at
  def api_picture_url_on_error_at=(new_api_picture_url_on_error_at)
    if new_api_picture_url_on_error_at
      check_type('api_picture_url_on_error_at', new_api_picture_url_on_error_at, 'Time')
      write_attribute :api_picture_url_on_error_at, encrypt_add_pre_and_postfix(new_api_picture_url_on_error_at.to_yaml, 'api_picture_url_on_error_at', 22)
    else
      write_attribute :api_picture_url_on_error_at, nil
    end
  end # api_picture_url_on_error_at=
  alias_method :api_picture_url_on_error_at_before_type_cast, :api_picture_url_on_error_at
  def api_picture_url_on_error_at_was
    return api_picture_url_on_error_at unless api_picture_url_on_error_at_changed?
    return nil unless (temp_extended_api_picture_url_on_error_at = attribute_was(:api_picture_url_on_error_at))
    temp_api_picture_url_on_error_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_on_error_at, 'api_picture_url_on_error_at', 22)
    YAML::load(temp_api_picture_url_on_error_at)
  end # api_picture_url_on_error_at_was

  # 21) deleted_at_api. String Y/N.

  # 22) status_change_at - integer - not encrypted - keep track of gifts changed after user has loaded gifts/index page

  # 23) balance_doc_giver. documentation for balance_giver to be used in users/show page
  # Hash in model, encrypted text in db
  def balance_doc_giver
    return nil unless (temp_extended_balance_doc_giver = read_attribute(:balance_doc_giver))
    # puts "temp_extended_balance_doc_giver = #{temp_extended_balance_doc_giver}"
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance_doc_giver, 'balance_doc_giver', 34)
  end # balance_doc_giver
  def balance_doc_giver=(new_balance_doc_giver)
    if new_balance_doc_giver
      check_type('balance_doc_giver', new_balance_doc_giver, 'Hash')
      write_attribute :balance_doc_giver, encrypt_add_pre_and_postfix(new_balance_doc_giver.to_yaml, 'balance_doc_giver', 34)
    else
      write_attribute :balance_doc_giver, nil
    end
  end # balance_doc_giver=
  alias_method :balance_doc_giver_before_type_cast, :balance_doc_giver
  def balance_doc_giver_was
    return balance_doc_giver unless balance_doc_giver_changed?
    return nil unless (temp_extended_balance_doc_giver = attribute_was(:balance_doc_giver))
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance_doc_giver, 'balance_doc_giver', 34)
  end # balance_doc_giver_was

  # 24) balance_doc_receiver. documentation for balance_receiver to be used in users/show page
  # Hash in model, encrypted text in db
  def balance_doc_receiver
    return nil unless (temp_extended_balance_doc_receiver = read_attribute(:balance_doc_receiver))
    # puts "temp_extended_balance_doc_receiver = #{temp_extended_balance_doc_receiver}"
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance_doc_receiver, 'balance_doc_receiver', 35)
  end # balance_doc_receiver
  def balance_doc_receiver=(new_balance_doc_receiver)
    if new_balance_doc_receiver
      check_type('balance_doc_receiver', new_balance_doc_receiver, 'Hash')
      write_attribute :balance_doc_receiver, encrypt_add_pre_and_postfix(new_balance_doc_receiver.to_yaml, 'balance_doc_receiver', 35)
    else
      write_attribute :balance_doc_receiver, nil
    end
  end # balance_doc_receiver=
  alias_method :balance_doc_receiver_before_type_cast, :balance_doc_receiver
  def balance_doc_receiver_was
    return balance_doc_receiver unless balance_doc_receiver_changed?
    return nil unless (temp_extended_balance_doc_receiver = attribute_was(:balance_doc_receiver))
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_balance_doc_receiver, 'balance_doc_receiver', 35)
  end # balance_doc_receiver_was

  # 25) social_dividend_doc. documentation for social dividend calculation used in gifts/index and users/show balance tab page
  # Hash in model, encrypted text in db
  def social_dividend_doc
    return nil unless (temp_extended_social_dividend_doc = read_attribute(:social_dividend_doc))
    # puts "temp_extended_social_dividend_doc = #{temp_extended_social_dividend_doc}"
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_social_dividend_doc, 'social_dividend_doc', 36)
  end # social_dividend_doc
  def social_dividend_doc=(new_social_dividend_doc)
    if new_social_dividend_doc
      check_type('social_dividend_doc', new_social_dividend_doc, 'Hash')
      write_attribute :social_dividend_doc, encrypt_add_pre_and_postfix(new_social_dividend_doc.to_yaml, 'social_dividend_doc', 36)
    else
      write_attribute :social_dividend_doc, nil
    end
  end # social_dividend_doc=
  alias_method :social_dividend_doc_before_type_cast, :social_dividend_doc
  def social_dividend_doc_was
    return social_dividend_doc unless social_dividend_doc_changed?
    return nil unless (temp_extended_social_dividend_doc = attribute_was(:social_dividend_doc))
    YAML::load encrypt_remove_pre_and_postfix(temp_extended_social_dividend_doc, 'social_dividend_doc', 36)
  end # social_dividend_doc_was

  # 26) created_at - timestamp - not encrypted

  # 27) updated_at - timestamp - not encrypted


  #
  # helper methods
  #

  # todo: drop price with 2 decimals methods in models - use view helpers
  def price_with_2_decimals
    return nil unless price
    '%0.2f' % (price || 0)
  end
  def new_price_with_2_decimals
    return nil unless new_price
    '%0.2f' % (new_price || 0)
  end


  # get/set balance for actual user. Used in user.recalculate_balance and in /gifts/index page
  def balance (current_user, login_user)
    return nil unless user_id_receiver and user_id_giver
    balance_current_user = case current_user.user_id
      when user_id_giver then balance_giver
      when user_id_receiver then balance_receiver
      else nil
    end
    return nil unless balance_current_user
    balance_login_user = ExchangeRate.exchange(balance_current_user, current_user.currency, login_user.currency)
    balance_login_user
  end # balance
  def balance_doc (current_user)
    return nil unless user_id_receiver and user_id_giver
    case current_user.user_id
      when user_id_giver then balance_doc_giver
      when user_id_receiver then balance_doc_receiver
      else nil
    end
  end # balance_doc
  def set_balance (user_id, new_balance, new_balance_doc)
    # puts "Gift.set_balance: id = #{id}, user_id = #{user_id}, new_balance = #{new_balance}, user_id_giver = #{user_id_giver}, user_id_receiver = #{user_id_receiver}"
    return new_balance unless received_at
    case user_id
      when user_id_giver
        self.balance_giver = new_balance
        self.balance_doc_giver = new_balance_doc
      when user_id_receiver
        self.balance_receiver = new_balance
        self.balance_doc_receiver = new_balance_doc
      else return new_balance # error
    end
    new_balance
  end # set_balance

  # calculate negative interest for a period
  # it can be from received_at to today = self.negative_interest
  # it can also be for a selected period. Used when calculating social dividend exchanged between two users for a period
  def negative_interest_in_period (date1, date2)
    raise "invalid type" unless date1.class == Date and date2.class == Date
    received_at_date = received_at.to_date if received_at
    puts "received_at_date = #{received_at_date} (#{received_at_date.class})"
    if !received_at_date or received_at_date >= date2 or date1 == date2
      puts "gifts: negative_interest_in_period: id = #{id}, date1 = #{date1}, date2 = #{date2}, negative_interest = 0"
      return 0.0
    end

    date1 = received_at_date if date1 > received_at_date
    if date1 == received_at_date
      price1 = self.price
    else
      puts "date1 = #{date1} (#{date1.class.name}), received_at_date = #{received_at_date} (#{received_at_date.class.name})"
      days = (date1 - received_at_date).to_i
      price1 = self.price.to_f * PRICE_FACTOR_PER_DAY ** days
    end
    days = (date2 - received_at_date).to_i
    price2 = self.price * PRICE_FACTOR_PER_DAY ** days
    negative_interest = price1 - price2
    puts "gifts: negative_interest_in_period: id = #{id}, date1 = #{date1}, date2 = #{date2}, price = #{self.price}, negative_interest = #{negative_interest} (#{negative_interest.class.name})"
    negative_interest
  end # negative_interest_in_period

  def social_dividend_between_dates (date1, date2)
    negative_interest_in_period(date1, date2) / 4
  end

  # recalculate negative interest, new_price and social dividend for gift today
  # negative interest for gifts (gifttype = G) is used in social dividend calculation
  # negative interest for social dividend (gifttype = S) in social dividend calculation
  # that is - no social dividend of social dividend.
  def recalculate
    puts "gift: recalculate: id = #{id}"
    unless received_at
      puts 'open offer - prices is not recalculated'
      return self
    end
    today = Date.today
    return self if new_price_at == today
    # calculate new interest, price and social dividend
    self.negative_interest = case gifttype
                               when 'G' then negative_interest_in_period(received_at.to_date, today)
                               when 'S' then 0.0
                               else 0.0 # error
                             end # case
    self.new_price = price - negative_interest
    self.new_price_at = today
    self.social_dividend = case gifttype
                             when 'G' then negative_interest / 4 # gifttype G = Gift
                             when 'S' then new_price # gifttype S = Social dividend given or received
                             else 0.0 # error
                           end # case
    puts "Gift.recalculate: currency = #{currency}"
    save!
    self
  end # recalculate


  # called when a gift (gifttype = G) is created to exchange social dividend between the 2 users
  def create_social_dividend
    # find first gifts. New users do not get social dividend from old users.
    # find all relevant gifts
    puts "giver = #{giver.user_name}, receiver = #{receiver.user_name}, received_at = #{received_at}"
    gifts = Gift.where('(? in (user_id_giver, user_id_receiver) or ? in (user_id_giver, user_id_receiver)) and received_at is not null', user_id_receiver, user_id_giver)
    gifts.sort! { |a,b| a.received_at <=> b.received_at }
    giver_gifts = gifts.find_all { |g| g.gifttype == 'G' and [g.user_id_giver, g.user_id_receiver].index(user_id_giver) }
    receiver_gifts = gifts.find_all { |g| g.gifttype == 'G' and [g.user_id_giver, g.user_id_receiver].index(user_id_receiver) }
    social_dividends = gifts.find_all do |g|
      if g.gifttype != 'S'
        false
      elsif ![g.user_id_giver, g.user_id_receiver].index(self.user_id_giver)
        false
      elsif ![g.user_id_giver, g.user_id_receiver].index(self.user_id_receiver)
        false
      else
        true
      end
    end
    puts "gifts.size #{gifts.size}, giver_gifts.size = #{giver_gifts.size}, receiver_gifts.size = #{receiver_gifts.size}, social_dividends.size = #{social_dividends.size}"
    puts 'gifts: dates =' + gifts.collect { |g| g.received_at.to_s }.join(', ')
    # find first gifts
    giver_first_gift    = giver_gifts.first
    receiver_first_gift    = receiver_gifts.first
    return nil unless giver_first_gift and receiver_first_gift # error
    # find previous social dividend before this gift (self.received_at)
    # only calculate social dividend for period between last social dividend and this gift
    # also needed in documentation for social dividend calculation (from variable)
    last_social_dividend = social_dividends.reverse.find { |g| g.received_at < self.received_at }
    if last_social_dividend
      last_social_dividend_at = last_social_dividend.received_at
    else
      last_social_dividend_at = giver_first_gift.received_at
    end
    date1 = [ giver_first_gift.received_at, receiver_first_gift.received_at, last_social_dividend_at ].max.to_date
    date2 = received_at.to_date
    puts "giver first gift = #{giver_first_gift.received_at}, receiver first gift = #{receiver_first_gift.received_at}, date1 = #{date1}, date2 = #{date2}"
    return nil if date1 == date2 # giver or receiver is a new user - no social dividend is exchanged
    # remove gifts before date1 or after date2
    # puts "giver_gifts (before) : dates =" + giver_gifts.collect { |g| g.received_at.to_s }.join(', ')
    # puts "receiver_gifts (before) : dates =" + receiver_gifts.collect { |g| g.received_at.to_s }.join(', ')
    giver_gifts.delete_if { |g| g.received_at >= date2 }
    receiver_gifts.delete_if { |g| g.received_at >= date2 }
    # puts "giver_gifts (after) : dates =" + giver_gifts.collect { |g| g.received_at.to_s }.join(', ')
    # puts "receiver_gifts (after) : dates =" + receiver_gifts.collect { |g| g.received_at.to_s }.join(', ')
    puts "giver_gifts.size = #{giver_gifts.size}, receiver_gifts.size = #{receiver_gifts.size}"
    hash = {}
    null_hash = {:giver_no_gifts => 0,
                         :giver_negative_interest => 0.0,
                         :giver_social_dividend => 0.00,
                         :receiver_no_gifts => 0,
                         :receiver_negative_interest => 0.00,
                         :receiver_social_dividend => 0.00}
    giver_gifts.each do |g|
      next if g.gifttype != 'G' or g.price == 0
      hash[g.currency] = null_hash unless hash.has_key?(g.currency)
      hash[g.currency][:giver_no_gifts] += 1
      negative_interest = g.negative_interest_in_period(date1, date2)
      hash[g.currency][:giver_negative_interest] += negative_interest
      hash[g.currency][:giver_social_dividend] += negative_interest / 4
    end
    receiver_gifts.each do |g|
      next if g.gifttype != 'G' or g.price == 0
      hash[g.currency] = null_hash unless hash.has_key?(g.currency)
      hash[g.currency][:receiver_no_gifts] += 1
      negative_interest = g.negative_interest_in_period(date1, date2)
      hash[g.currency][:receiver_negative_interest] += negative_interest
      hash[g.currency][:receiver_social_dividend] += negative_interest / 4
    end
    puts "hash = #{hash.to_s}"

    # delete any social dividend calculation for this date (received_at) and this giver/receiver combination
    social_dividends.each { |g| g.destroy if g.received_at == self.received_at }

    # insert social dividend calculation for this date (received_at)
    hash.each do |name, value|
      puts "#{name} = #{value}"
      currency = name
      giver_social_dividend = value[:giver_social_dividend]
      receiver_social_dividend = value[:receiver_social_dividend]
      difference = ((giver_social_dividend - receiver_social_dividend)/2).abs.round(2)
      puts "currency = #{currency}, diference = #{difference}"
      next if difference == 0.00
      # initialize and create social dividend for actuel currency
      social_dividend_doc_hash = {:social_dividend_from => last_social_dividend ? date1 : nil }
      gift = Gift.new
      gift.currency = currency
      gift.price = difference

      if giver_social_dividend > receiver_social_dividend
        gift.user_id_giver = self.user_id_giver
        gift.user_id_receiver = self.user_id_receiver
        giver_user_name = giver.user_name
        receiver_user_name = receiver.user_name
        social_dividend_doc_hash[:giver_no_gifts] = value[:giver_no_gifts]
        social_dividend_doc_hash[:receiver_no_gifts] = value[:receiver_no_gifts]
        social_dividend_doc_hash[:giver_negative_interest] = value[:giver_negative_interest]
        social_dividend_doc_hash[:receiver_negative_interest] = value[:receiver_negative_interest]
        social_dividend_doc_hash[:giver_old_social_dividend] = value[:giver_social_dividend]
        social_dividend_doc_hash[:receiver_old_social_dividend] = value[:receiver_social_dividend]
        social_dividend_doc_hash[:giver_new_social_dividend] = value[:giver_social_dividend] - difference
        social_dividend_doc_hash[:receiver_new_social_dividend] = value[:receiver_social_dividend] + difference
      else
        gift.user_id_giver = self.user_id_receiver
        gift.user_id_receiver = self.user_id_giver
        giver_user_name = receiver.user_name
        receiver_user_name = giver.user_name
        social_dividend_doc_hash[:giver_no_gifts] = value[:receiver_no_gifts]
        social_dividend_doc_hash[:receiver_no_gifts] = value[:giver_no_gifts]
        social_dividend_doc_hash[:giver_negative_interest] = value[:receiver_negative_interest]
        social_dividend_doc_hash[:receiver_negative_interest] = value[:giver_negative_interest]
        social_dividend_doc_hash[:giver_old_social_dividend] = value[:receiver_social_dividend]
        social_dividend_doc_hash[:receiver_old_social_dividend] = value[:giver_social_dividend]
        social_dividend_doc_hash[:giver_new_social_dividend] = value[:receiver_social_dividend] - difference
        social_dividend_doc_hash[:receiver_new_social_dividend] = value[:giver_social_dividend] + difference
      end
      if last_social_dividend
        key_no = 2 # description with from and to dates
      else
        key_no = 1 # description only with to date - first social dividend for a new Gofreerev user
      end
      # this format (description saved in db) is also used in application_helper.format_gift_description
      gift.description = I18n.t "gifts.gift.social_dividend_description_#{key_no}",
                              :currency => currency,
                              :price => "%0.2f" % difference,
                              :giver => giver_user_name,
                              :receiver => receiver_user_name,
                              :from_date => social_dividend_doc_hash[:social_dividend_from],
                              :to_date => date2
      puts "self.id = #{self.id}, self.recieved_at = #{self.received_at}"
      gift.received_at = self.received_at
      gift.new_price = gift.price
      gift.new_price_at = gift.received_at
      gift.negative_interest = 0.0
      gift.social_dividend = 0.0
      gift.gifttype = 'S'
      # gift.social_dividend_from = date1 # moved to social_dividend_doc hash
      gift.picture = 'N'
      gift.social_dividend_doc = social_dividend_doc_hash
      gift.save!
    end # each

    # recalculate any social dividends after received_at
    next_social_dividend = social_dividends.find { |g| g.received_at > self.received_at }
    next_social_dividend.create_social_dividend if next_social_dividend # recursive call

    # recalculate balance for giver and receiver
    # todo: should only recalculate balance for actuel gift.id and forward
    giver.recalculate_balance
    receiver.recalculate_balance

  end # create_social_dividend

=begin
  # todo: this request url only return url for small picture. it would be nice to get url with a larger picture
  def get_api_picture_url (access_token)
    return nil unless picture == 'Y'
    return nil if deleted_at_api == 'Y'
    raise NoApiAccessTokenException unless access_token
    api = Koala::Facebook::API.new(access_token)
    api_request = "#{api_gift_id}?fields=full_picture"
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
      # Koala::Facebook::ClientError
      # e.fb_error_type = GraphMethodException
      # e.fb_error_code = 100
      # e.fb_error_subcode =
      # e.fb_error_message = Unsupported get request.
      # e.http_status = 400
      # e.response_body = {"error":{"message":"Unsupported get request.","type":"GraphMethodException","code":100}}
      # e.fb_error_type.class.name = String
      # e.fb_error_code.class.name = Fixnum
      # todo: identical error response if picture is deleted or if user is not allowed to see picture
      if e.fb_error_type == 'GraphMethodException' and e.fb_error_code == 100
        # picture not found - maybe picture has been deleted - maybe a permission problem
        raise ApiPostNotFoundException
      else
        raise
      end
    end
    puts "api_response = #{api_response}"
    return api_response["full_picture"]
  end # get_api_picture_url
=end

  def get_api_picture_url (access_token)
    return nil unless picture == 'Y'
    return nil if deleted_at_api == 'Y'
    raise NoApiAccessTokenException unless access_token
    api = Koala::Facebook::API.new(access_token)
    api_request = "#{api_gift_id}?fields=full_picture"
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
      if e.fb_error_type == 'GraphMethodException' and e.fb_error_code == 100
        # identical error response if picture is deleted or if user is not allowed to see picture
        # picture not found - maybe picture has been deleted - maybe a permission problem
        raise ApiPostNotFoundException
      else
        raise
      end
    end
    puts "api_response = #{api_response}"
    return api_response["full_picture"]
  end # get_api_picture_url


  def visible_for (user)
    if !user
      access = nil
    elsif [user_id_receiver, user_id_giver].index(user.user_id)
      access = 'Y'
    else
      access = user.app_friends.find { |f| [user_id_receiver, user_id_giver].index(f.user_id_receiver) }
    end
    (access != nil)
  end # visible_for


  # return last 4 comments for gifts/index page if first_comment_id is nil
  # return next 10 old comments in ajax request ii first_comment_id is not null
  # used in gifts/index (html/first_comment_id == nil) and in comments/comments (ajax/first_comment_id != nil)
  def comments_with_filter (first_comment_id = nil)
    cs = comments.sort { |a,b| a.created_at <=> b.created_at }
    (0..(cs.length-1)).each { |i| cs[i].no_older_comments = i }
    return cs.last(4) if first_comment_id == nil
    index = cs.find_index { |c| c.id.to_s == first_comment_id.to_s }
    # puts "index = #{index}"
    return [] if index == nil or index == 0
    cs[0..(index-1)].last(10)
  end # comments_with_filter


  # display new deal check box?
  # only for open deals - and not for users deals
  def show_new_deal_checkbox? (user)
    return false if user_id_giver and user_id_receiver # close deal
    return false if user_id_giver == user.user_id
    return false if user_id_receiver == user.user_id
    true
  end # show_new_deal_checkbox?



  # psydo attributea
  attr_accessor :file, :direction


  def before_create
    self.status_update_at = Sequence.next_status_update_at
  end


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
      loop do
        temp_gift_id = String.generate_random_string(20)
        return temp_gift_id unless Gift.find_by_gift_id(temp_gift_id)
      end
    end

end # Gift

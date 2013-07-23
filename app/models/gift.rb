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

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :api_gift_id, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


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
      write_attribute :negative_interest, nil
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

  # 12) api_gift_id - String in model - encrypted text in db - api id for the gift / status update on the wall
  attr_readonly :api_gift_id
  def api_gift_id
    return nil unless (extended_api_gift_id = read_attribute(:api_gift_id))
    encrypt_remove_pre_and_postfix(extended_api_gift_id, 'api_gift_id', 2)
  end
  def api_gift_id=(new_api_gift_id)
    return api_gift_id if self.api_gift_id
    if new_api_gift_id
      check_type('api_gift_id', new_api_gift_id, 'String')
      write_attribute :api_gift_id, encrypt_add_pre_and_postfix(new_api_gift_id, 'api_gift_id', 2)
    else
      write_attribute :api_gift_id, nil
    end
  end
  alias_method :api_gift_id_before_type_cast, :api_gift_id

  # 13) gifttype - String in model and DB - G if gift - S if exchanged social dividend
  # gifttype = G : social dividend = ( new_price - price) / 4
  # gifttype = S : social divident = new_price when price = social dividend exchanged between the two users.

  # 14) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def social_dividend_from
    return nil unless (temp_extended_social_dividend_from = read_attribute(:social_dividend_from))
    temp_social_dividend_from = encrypt_remove_pre_and_postfix(temp_extended_social_dividend_from, 'social_dividend_from', 10)
    YAML::load(temp_social_dividend_from)
  end
  def social_dividend_from=(new_social_dividend_from)
    if new_social_dividend_from
      check_type('social_dividend_from', new_social_dividend_from, 'Date')
      write_attribute :social_dividend_from, encrypt_add_pre_and_postfix(new_social_dividend_from.to_yaml, 'social_dividend_from', 10)
    else
      write_attribute :social_dividend_from, nil
    end
  end
  alias_method :social_dividend_from_before_type_cast, :social_dividend_from

  # 15) new_price_giver - BigDecimal in model - encrypted text in db - equal new_price, but with givers actual currency and with sign - used for balance
  def new_price_giver
    return nil unless (temp_extended_new_price_giver = read_attribute(:new_price_giver))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_new_price_giver, 'new_price_giver', 11)
  end # new_price_giver
  def new_price_giver=(new_new_price_giver)
    if new_new_price_giver
      check_type('new_price_giver', new_new_price_giver, 'BigDecimal')
      write_attribute :new_price_giver, encrypt_add_pre_and_postfix(new_new_price_giver.to_s, 'new_price_giver', 11)
    else
      write_attribute :new_price_giver, nil
    end
  end # new_price_giver=
  alias_method :new_price_giver_before_type_cast, :new_price_giver

  # 16) new_price_receiver - BigDecimal in model - encrypted text in db - equal new_price but with receivers actual currency and with sign - used for balance
  def new_price_receiver
    return nil unless (temp_extended_new_price_receiver = read_attribute(:new_price_receiver))
    BigDecimal.new encrypt_remove_pre_and_postfix(temp_extended_new_price_receiver, 'new_price_receiver', 12)
  end # new_price_receiver
  def new_price_receiver=(new_new_price_receiver)
    if new_new_price_receiver
      check_type('new_price_receiver', new_new_price_receiver, 'BigDecimal')
      write_attribute :new_price_receiver, encrypt_add_pre_and_postfix(new_new_price_receiver.to_s, 'new_price_receiver', 12)
    else
      write_attribute :new_price_receiver, nil
    end
  end # new_price=
  alias_method :new_price_receiver_before_type_cast, :new_price_receiver

  def balance_giver
    return nil unless (extended_balance_giver = read_attribute(:balance_giver))
    balance = encrypt_remove_pre_and_postfix(extended_balance_giver, 'balance_giver', 13)
    return nil unless balance
    balance.to_f
  end
  def balance_giver=(new_balance_giver)
    if new_balance_giver
      check_type('balance_giver', new_balance_giver, 'Float')
      write_attribute :balance_giver, encrypt_add_pre_and_postfix(new_balance_giver.to_s, 'balance_giver', 13)
    else
      write_attribute :balance_giver, nil
    end
  end
  alias_method :balance_giver_before_type_cast, :balance_giver

  def balance_receiver
    return nil unless (extended_balance_receiver = read_attribute(:balance_receiver))
    balance = encrypt_remove_pre_and_postfix(extended_balance_receiver, 'balance_receiver', 14)
    return nil unless balance
    balance.to_f
  end
  def balance_receiver=(new_balance_receiver)
    if new_balance_receiver
      check_type('balance_receiver', new_balance_receiver, 'Float')
      write_attribute :balance_receiver, encrypt_add_pre_and_postfix(new_balance_receiver.to_s, 'balance_receiver', 14)
    else
      write_attribute :balance_receiver, nil
    end
  end
  alias_method :balance_receiver_before_type_cast, :balance_receiver

  # 19) created_at - timestamp - not encrypted

  # 20) updated_at - timestamp - not encrypted


  #
  # helper methods
  #


  def price_with_2_decimals
    return nil unless price
    "%0.2f" % (price || 0)
  end
  def new_price_with_2_decimals
    return nil unless new_price
    "%0.2f" % (new_price || 0)
  end
  def new_price_user (user)
    return nil unless price
    return nil unless receiver
    case user
      when giver then new_price_giver
      when receiver then -new_price_receiver
      else nil
    end
  end # new_price_user

  # get/set balance for actual user. Used in user.recalculate_balance and in /gifts/index page
  def balance (user_id)
    return nil unless user_id_receiver
    case user_id
      when user_id_giver then balance_giver
      when user_id_receiver then balance_receiver
      else nil
    end
  end
  def set_balance (user_id, new_balance)
    puts "Gift.set_balance: id = #{id}, user_id = #{user_id}, new_balance = #{new_balance}, user_id_giver = #{user_id_giver}, user_id_receiver = #{user_id_receiver}"
    return new_balance unless received_at
    case user_id
      when user_id_giver then self.balance_giver = new_balance
      when user_id_receiver then self.balance_receiver = new_balance
      else return new_balance ;
    end
    new_balance
  end

  # calculate negative interest for a period
  # it can be from received_at to today = self.negative_interest
  # it can also be for a selected period. Used when calculating social dividend exchanged between two users for a period
  def negative_interest_between_dates (date1, date2)
    if !received_at or received_at >= date2 or date1 == date2
      puts "gifts: negative_interest_between_dates: id = #{id}, date1 = #{date1}, date2 = #{date2}, negative_interest = 0"
      return 0
    end

    date1 = received_at if date1 > received_at
    if date1 == received_at
      price1 = self.price.to_f
    else
      days = (date1 - received_at).to_i
      price1 = self.price.to_f * PRICE_FACTOR_PER_DAY ** days
    end
    days = (date2 - received_at).to_i
    price2 = self.price.to_f * PRICE_FACTOR_PER_DAY ** days
    negative_interest = price1 - price2
    puts "gifts: negative_interest_between_dates: id = #{id}, date1 = #{date1}, date2 = #{date2}, negative_interest = #{negative_interest} (#{negative_interest.class.name})"
    negative_interest
  end # negative_interest_between_dates

  def social_dividend_between_dates (date1, date2)
    negative_interest_between_dates(date1, date2) / 4
  end

  # recalculate negative interest, new_price and social dividend for gift today
  # negative interest for gifts (gifttype = G) is used in social dividend calculation
  # negative interest for social dividend (gifttype = S) in social dividend calculation
  # that is - no social dividend of social dividend.
  def recalculate
    puts "gift: recalculate: id = #{id}"
    if !received_at
      puts "open offer - prices is not recalculated"
      return self
    end
    today =  Date.today
    if  new_price_at != today
      # calculate new interest, price and social dividend
      self.negative_interest = BigDecimal.new negative_interest_between_dates(received_at, today).to_s unless new_price_at == today
      self.new_price = price - negative_interest
      self.new_price_at = today
      self.social_dividend = case gifttype
                               when 'G' then negative_interest / 4 # gifttype G = Gift
                               when 'S' then new_price             # gifttype S = Social dividend given or received
                               else BigDecimal.new '0' # error
                             end # case
    end
    # update currency_giver and new_price_giver if any changes
    if self.new_price
      if giver.currency == self.currency
        self.new_price_giver = self.new_price
      else
        new_price = ExchangeRate.exchange(self.new_price, self.currency, giver.currency)
        if new_price.currency.to_s == giver.currency
          # found exchange rate
          self.currency_giver =  new_price.currency.to_s
          self.new_price_giver = BigDecimal.new new_price.to_s
        else
          self.new_price_giver = nil
        end
      end
    end
    # update currency_receiver and new_price_receiver if any changes
    if receiver and self.new_price
      if receiver.currency == self.currency
        self.new_price_receiver = self.new_price
      elsif receiver.currency == self.currency_giver
        self.new_price_receiver = self.new_price_giver
        self.currency_receiver = self.currency_giver
      else
        new_price = ExchangeRate.exchange(self.new_price, self.currency, receiver.currency)
        if new_price.currency.to_s == receiver.currency
          # found exchange rate
          self.currency_receiver =  new_price.currency.to_s
          self.new_price_receiver = BigDecimal.new new_price.to_s
        else
          self.new_price_receiver = nil
        end
      end
    end

    save!
    self
  end # recalculate


  # called when a gift (gifttype = G) is created to exchange social dividend between the 2 users
  def create_social_dividend
    # find first gifts. New users do not get social dividend from old users.
    # find all relevant gifts
    puts "giver = #{giver.user_name}, receiver = #{receiver.user_name}, received_at = #{received_at}"
    gifts = Gift.where("(? in (user_id_giver, user_id_receiver) or ? in (user_id_giver, user_id_receiver)) and received_at is not null", user_id_receiver, user_id_giver)
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
    puts "gifts: dates =" + gifts.collect { |g| g.received_at.to_s }.join(', ')
    # find first gifts
    giver_first_gift    = giver_gifts.first
    receiver_first_gift    = receiver_gifts.first
    last_social_dividend = social_dividends.reverse.find { |g| g.received_at < self.received_at }
    return nil unless giver_first_gift and receiver_first_gift # error
    if last_social_dividend
      last_social_dividend_at = last_social_dividend.received_at
    else
      last_social_dividend_at = giver_first_gift.received_at
    end
    date1 = [ giver_first_gift.received_at, receiver_first_gift.received_at, last_social_dividend_at ].max
    date2 = received_at
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
    giver_gifts.each do |g|
      next if g.gifttype != 'G' or g.price == 0
      hash[g.currency] = { :giver => 0, :receiver => 0 } unless hash.has_key?(g.currency)
      hash[g.currency][:giver] += g.negative_interest_between_dates(date1, date2) / 4
    end
    receiver_gifts.each do |g|
      next if g.gifttype != 'G' or g.price == 0
      hash[g.currency] = { :giver => 0, :receiver => 0 } unless hash.has_key?(g.currency)
      hash[g.currency][:receiver] += g.negative_interest_between_dates(date1, date2) / 4
    end
    puts "hash = #{hash.to_s}"

    # delete any social dividend calculation for this date
    social_dividends.each { |g| g.destroy if g.received_at == self.received_at }

    # insert social dividend calculation for this date
    hash.each do |name, value|
      currency = name
      giver_social_dividend = value[:giver]
      receiver_social_dividend = value[:receiver]
      difference = ((giver_social_dividend - receiver_social_dividend)/2).abs.round(2)
      puts "currency = #{currency}, diference = #{difference}"
      next if difference == 0
      gift = Gift.new
      gift.currency = currency
      gift.price = BigDecimal.new difference.to_s
      gift.description = "Social dividend %0.2f #{currency}" % difference
      if giver_social_dividend > receiver_social_dividend
        gift.user_id_giver = self.user_id_giver
        gift.user_id_receiver = self.user_id_receiver
        gift.description += " from #{gift.giver.short_user_name} to #{gift.receiver.short_user_name}"
      else
        gift.user_id_giver = self.user_id_receiver
        gift.user_id_receiver = self.user_id_giver
        gift.description += " from #{gift.receiver.short_user_name} to #{gift.giver.short_user_name}"
      end
      if last_social_dividend
        gift.description += " for period #{date1} to #{date2}"
      else
        gift.description += " for period up to #{date2}"
      end
      gift.received_at = self.received_at
      gift.new_price = gift.price
      gift.new_price_at = gift.received_at
      gift.negative_interest = BigDecimal.new "0"
      gift.social_dividend = BigDecimal.new "0"
      gift.gifttype = 'S'
      gift.social_dividend_from = date1
      !gift.save!
    end # each

    # recalculate any social dividends after self.received_at
    next_social_dividend = social_dividends.find { |g| g.received_at > self.received_at }
    next_social_dividend.create_social_dividend if next_social_dividend #

  end # create_social_dividend


  # psydo attributea
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

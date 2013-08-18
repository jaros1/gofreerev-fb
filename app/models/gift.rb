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


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :description, :currency, :price, :received_at, :new_price, :negative_interest, :social_dividend, :api_gift_id, :social_dividend_from, :balance_giver, :balance_receiver, :api_picture_url, :api_picture_url_updated_at, :api_picture_url_on_error_at, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


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



  # 4) price - Float in model - encrypted text in db
  validates_each :price do |record, attr, value|
    record.errors.add attr, :readonly if value.to_s != record.price_was.to_s and  record.received_at
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

  # 5) user_id_giver - FK - not encrypted. Gift must have a giver or an receiver when created. Must have giver and receiver when closed
  validates_presence_of :user_id_giver, :if => Proc.new {|g| (g.received_at or !g.user_id_receiver) }

  # 6) user_id_receiver - FK - not encrypted. Gift must have a giver or an receiver when created. Must have giver and receiver when closed
  validates_presence_of :user_id_receiver, :if => Proc.new {|g| (g.received_at or !g.user_id_giver) }

  # 7) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def received_at
    return nil unless (temp_extended_received_at = read_attribute(:received_at))
    temp_received_at1 = encrypt_remove_pre_and_postfix(temp_extended_received_at, 'received_at', 5)
    temp_received_at2 = YAML::load(temp_received_at1)
    temp_received_at2 = temp_received_at2.to_time if temp_received_at2.class.name == 'Date'
    temp_received_at2
  end
  def received_at=(new_received_at)
    if new_received_at
      check_type('received_at', new_received_at, 'Time')
      write_attribute :received_at, encrypt_add_pre_and_postfix(new_received_at.to_yaml, 'received_at', 5)
    else
      write_attribute :received_at, nil
    end
  end
  alias_method :received_at_before_type_cast, :received_at

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
  end
  alias_method :api_gift_id_before_type_cast, :api_gift_id

  # 13) gifttype - String in model and DB - G if gift - S if exchanged social dividend
  # gifttype = G : social dividend = ( new_price - price) / 4
  # gifttype = S : social divident = new_price when price = social dividend exchanged between the two users.

  # 14) received_at. Date in model - encrypted text in db - set once when the deal is closed together with user_id_receiver
  def social_dividend_from
    return nil unless (temp_ext_soc_div_from = read_attribute(:social_dividend_from))
    temp_social_dividend_from = encrypt_remove_pre_and_postfix(temp_ext_soc_div_from, 'social_dividend_from', 27)
    YAML::load(temp_social_dividend_from)
  end
  def social_dividend_from=(new_soc_div_from)
    if new_soc_div_from
      check_type('social_dividend_from', new_soc_div_from, 'Date')
      write_attribute :social_dividend_from, encrypt_add_pre_and_postfix(new_soc_div_from.to_yaml, 'social_dividend_from', 27)
    else
      write_attribute :social_dividend_from, nil
    end
  end
  alias_method :social_dividend_from_before_type_cast, :social_dividend_from

  # 15) balance giver - Float in Model. Encrypted text in db.
  def balance_giver
    return nil unless (extended_balance_giver = read_attribute(:balance_giver))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(extended_balance_giver, 'balance_giver', 25)
  end
  def balance_giver=(new_balance_giver)
    if new_balance_giver.to_s != ''
      check_type('balance_giver', new_balance_giver, 'Float')
      write_attribute :balance_giver, encrypt_add_pre_and_postfix(new_balance_giver.to_s, 'balance_giver', 25)
    else
      write_attribute :balance_giver, nil
    end
  end
  alias_method :balance_giver_before_type_cast, :balance_giver

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

  # 17) picture Y/N - String - not encrypted
  
  # 18) api_picture_url - String in Model - encrypted text in db
  def api_picture_url
    # puts "gift.api_picture_url: api_picture_url = #{read_attribute(:api_picture_url)} (#{read_attribute(:api_picture_url).class.name})"
    return nil unless (extended_api_picture_url = read_attribute(:api_picture_url))
    encrypt_remove_pre_and_postfix(extended_api_picture_url, 'api_picture_url', 23)
  end
  def api_picture_url=(new_api_picture_url)
    # puts "gift.api_picture_url=: api_picture_url = #{new_api_picture_url} (#{new_api_picture_url.class.name})"
    if new_api_picture_url
      check_type('api_picture_url', new_api_picture_url, 'String')
      write_attribute :api_picture_url, encrypt_add_pre_and_postfix(new_api_picture_url, 'api_picture_url', 23)
    else
      write_attribute :api_picture_url, nil
    end
  end
  alias_method :api_picture_url_before_type_cast, :api_picture_url

  # 19) api_picture_url_updated_at - timestamp in model - encrypted text 
  def api_picture_url_updated_at
    return nil unless (temp_extended_api_picture_url_updated_at = read_attribute(:api_picture_url_updated_at))
    temp_api_picture_url_updated_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_updated_at, 'api_picture_url_updated_at', 21)
    YAML::load(temp_api_picture_url_updated_at)
  end
  def api_picture_url_updated_at=(new_api_picture_url_updated_at)
    if new_api_picture_url_updated_at
      check_type('api_picture_url_updated_at', new_api_picture_url_updated_at, 'Time')
      write_attribute :api_picture_url_updated_at, encrypt_add_pre_and_postfix(new_api_picture_url_updated_at.to_yaml, 'api_picture_url_updated_at', 21)
    else
      write_attribute :api_picture_url_updated_at, nil
    end
  end
  alias_method :api_picture_url_updated_at_before_type_cast, :api_picture_url_updated_at

  # 20) api_picture_url_on_error_at - timestamp in model - encrypted text (todo) in db
  def api_picture_url_on_error_at
    return nil unless (temp_extended_api_picture_url_on_error_at = read_attribute(:api_picture_url_on_error_at))
    temp_api_picture_url_on_error_at = encrypt_remove_pre_and_postfix(temp_extended_api_picture_url_on_error_at, 'api_picture_url_on_error_at', 22)
    YAML::load(temp_api_picture_url_on_error_at)
  end
  def api_picture_url_on_error_at=(new_api_picture_url_on_error_at)
    if new_api_picture_url_on_error_at
      check_type('api_picture_url_on_error_at', new_api_picture_url_on_error_at, 'Time')
      write_attribute :api_picture_url_on_error_at, encrypt_add_pre_and_postfix(new_api_picture_url_on_error_at.to_yaml, 'api_picture_url_on_error_at', 22)
    else
      write_attribute :api_picture_url_on_error_at, nil
    end
  end
  alias_method :api_picture_url_on_error_at_before_type_cast, :api_picture_url_on_error_at

  # 21) deleted_at_api. String Y/N.

  # 22) created_at - timestamp - not encrypted

  # 23) updated_at - timestamp - not encrypted


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
  def balance (user_id)
    return nil unless user_id_receiver
    case user_id
      when user_id_giver then balance_giver
      when user_id_receiver then balance_receiver
      else nil
    end
  end
  def set_balance (user_id, new_balance)
    # puts "Gift.set_balance: id = #{id}, user_id = #{user_id}, new_balance = #{new_balance}, user_id_giver = #{user_id_giver}, user_id_receiver = #{user_id_receiver}"
    return new_balance unless received_at
    case user_id
      when user_id_giver then self.balance_giver = new_balance
      when user_id_receiver then self.balance_receiver = new_balance
      else return new_balance # error
    end
    new_balance
  end

  # calculate negative interest for a period
  # it can be from received_at to today = self.negative_interest
  # it can also be for a selected period. Used when calculating social dividend exchanged between two users for a period
  def negative_interest_in_period (date1, date2)
    received_at_date = received_at.to_date if received_at
    if !received_at_date or received_at_date >= date2 or date1 == date2
      puts "gifts: negative_interest_in_period: id = #{id}, date1 = #{date1}, date2 = #{date2}, negative_interest = 0"
      return 0.0
    end

    date1 = received_at_date if date1 > received_at_date
    if date1 == received_at_date
      price1 = self.price
    else
      puts "date1 = #{date1} (#{date1.class.name}, received_at_date = #{received_at_date} (#{received_at_date.class.name})"
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
    today =  Date.today
    return self if new_price_at == today
    # calculate new interest, price and social dividend
    self.negative_interest = negative_interest_in_period(received_at.to_date, today) unless new_price_at == today
    self.new_price = price - negative_interest
    self.new_price_at = today
    self.social_dividend = case gifttype
                             when 'G' then negative_interest / 4 # gifttype G = Gift
                             when 'S' then new_price             # gifttype S = Social dividend given or received
                             else 0.0 # error
                           end # case
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
      hash[g.currency][:giver] += g.negative_interest_in_period(date1, date2) / 4
    end
    receiver_gifts.each do |g|
      next if g.gifttype != 'G' or g.price == 0
      hash[g.currency] = { :giver => 0, :receiver => 0 } unless hash.has_key?(g.currency)
      hash[g.currency][:receiver] += g.negative_interest_in_period(date1, date2) / 4
    end
    puts "hash = #{hash.to_s}"

    # delete any social dividend calculation for this date (received_at)
    social_dividends.each { |g| g.destroy if g.received_at == self.received_at }

    # insert social dividend calculation for this date (received_at)
    hash.each do |name, value|
      currency = name
      giver_social_dividend = value[:giver]
      receiver_social_dividend = value[:receiver]
      difference = ((giver_social_dividend - receiver_social_dividend)/2).abs.round(2)
      puts "currency = #{currency}, diference = #{difference}"
      next if difference == 0
      gift = Gift.new
      gift.currency = currency
      gift.price = difference
      # description in english.
      # views should use a description translate helper
      gift.description = "Social dividend %0.2f #{currency}" % difference
      if giver_social_dividend > receiver_social_dividend
        gift.user_id_giver = self.user_id_giver
        gift.user_id_receiver = self.user_id_receiver
        gift.description += " from #{self.giver.short_user_name} to #{self.receiver.short_user_name}"
      else
        gift.user_id_giver = self.user_id_receiver
        gift.user_id_receiver = self.user_id_giver
        gift.description += " from #{self.receiver.short_user_name} to #{self.giver.short_user_name}"
      end
      if last_social_dividend
        gift.description += " for period #{date1} to #{date2}"
      else
        gift.description += " for period up to #{date2}"
      end
      gift.received_at = self.received_at
      gift.new_price = gift.price
      gift.new_price_at = gift.received_at
      gift.negative_interest = 0.0
      gift.social_dividend = 0.0
      gift.gifttype = 'S'
      gift.social_dividend_from = date1
      !gift.save!
    end # each

    # recalculate any social dividends after received_at
    next_social_dividend = social_dividends.find { |g| g.received_at > self.received_at }
    next_social_dividend.create_social_dividend if next_social_dividend # recursive call

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


  # psydo attributea
  attr_accessor :file, :direction


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

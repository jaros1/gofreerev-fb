class Gift < ActiveRecord::Base

  has_many :comments, :class_name => 'Comment', :primary_key => :gift_id, :foreign_key => :gift_id, :dependent => :destroy
  has_many :likes, :class_name => 'GiftLike', :primary_key => :gift_id, :foreign_key => :gift_id, :dependent => :destroy
  has_many :api_gifts, :class_name => 'ApiGift', :primary_key => :gift_id, :foreign_key => :gift_id, :dependent => :destroy

  before_create :before_create
  before_update :before_update

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :description, :currency, :price, :received_at, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


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

  # 26) created_at - timestamp - not encrypted

  # 27) updated_at - timestamp - not encrypted

  # 28) direction - giver, receiver or both - starts with giver or receiver and is changed to both when the deal is accepted
  validates_presence_of :direction
  validates_inclusion_of :direction, :allow_blank => true, :in => %w(giver receiver both)
  validates_each :direction, :allow_blank => true do |record, attr, value|
    if record.new_record? and value == 'both'
      record.errors.add attr, :invalid
    elsif record.received_at and value != 'both'
      record.errors.add attr, :invalid
    end
  end

  # placeholders for giver and receiver from api gifts - from user.gifts methods
  # attr_accessor :giver, :receiver, :picture


  #
  # helper methods
  #

  def user_id_giver
    return nil unless giver
    giver.user_id
  end
  def user_id_receiver
    return nil unless receiver
    receiver.user_id
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
    balance_login_user = ExchangeRate.exchange(balance_current_user, 'USD', login_user.currency, received_at)
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


  # todo: these get_api_picture_url methods only return url for small picture. it would be nice to get url with a larger picture

=begin
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



  def visible_for (users)
    if users.class != Array
      return false
    elsif users.length == 0
      return false
    elsif deleted_at
      return false
    else
      # check if user is giver or receiver
      api_gifts.each do |api_gift|
        user = users.find { |user2| user2.provider == api_gift.provider }
        next unless user
        return true if [api_gift.user_id_receiver, api_gift.user_id_giver].index(user.user_id)
      end
      # check if giver or receiver is a friend
      api_gifts.each do |api_gift|
        user = users.find { |user2| user2.provider == api_gift.provider }
        next unless user
        return true if user.app_friends.find { |f| [api_gift.user_id_receiver, api_gift.user_id_giver].index(f.user_id_receiver) }
      end
    end
    false
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
  # only for open deals - and not for users deals (user is giver or receiver)
  def show_new_deal_checkbox? (users)
    return false unless users.class == Array and users.size > 0
    return false if direction == 'both' # closed deal
    count = 0
    api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      next unless user
      count += 1
      return false if api_gift.user_id_giver == user.user_id
      return false if api_gift.user_id_receiver == user.user_id
    end # each
    raise "gift #{id} without api gifts for login user(s)" unless count > 0
    true
  end # show_new_deal_checkbox?

  def show_delete_gift_link? (users)
    return false unless users.class == Array and users.length > 0
    api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      next unless user
      return true if [api_gift.user_id_giver, api_gift.user_id_receiver].index(user.user_id)
    end
    return false
  end # show_delete_gift_link?


  def temp_picture_url
    return nil unless temp_picture_filename
    "temp/#{temp_picture_filename}"
  end
  def temp_picture_path
    return nil unless temp_picture_filename
    Rails.root.join('public', 'images', 'temp', temp_picture_filename).to_s
  end


  # psydo attributea
  attr_accessor :file




  def before_create
    self.status_update_at = Sequence.next_status_update_at
  end

  def before_update
    if !deleted_at_was and deleted_at
      # gift has been delete marked in util_controller.delete_gift
      # update status_update_at so that gift will be ajax deleted in other sessions
      self.status_update_at = Sequence.next_status_update_at
      # destroy all notifications for this gift
      comment_ids = comments.collect { |c| c.comment_id }
      return if comment_ids.size == 0
      notification_ids = CommentNotification.where("comment_id in (?)", comment_ids).collect { |cn| cn.notification_id }.uniq
      return if notification_ids.size == 0
      Notification.where("notification_id in (?)", notification_ids).each { |n| n.destroy }
    end # if
  end # before_update


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

class ApiGift < ActiveRecord::Base

  #create_table "api_gifts", force: true do |t|
  #  1 t.string   "gift_id",                     limit: 20
  #  2 t.string   "provider",                    limit: 20
  #  3 t.string   "user_id_giver",               limit: 40
  #  4 t.string   "user_id_receiver",            limit: 40
  #  5 t.string   "picture",                     limit: 1
  #  6 t.text     "api_gift_id"
  #  7 t.text     "api_picture_url"
  #  8 t.text     "api_picture_url_updated_at"
  #  9 t.text     "api_picture_url_on_error_at"
  # 10 t.string   "deleted_at_api",              limit: 1
  # 11 t.text     "balance_giver"
  # 12 t.text     "balance_receiver"
  # 13 t.text     "balance_doc_giver"
  # 14 t.text     "balance_doc_receiver"
  # 15 t.datetime "created_at"
  # 16 t.datetime "updated_at"
  #end

  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id
  belongs_to :giver, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_giver
  belongs_to :receiver, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_receiver

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :api_gift_id, :balance_giver, :balance_receiver, :api_picture_url, :api_picture_url_updated_at, :api_picture_url_on_error_at, :balance_doc_giver, :balance_doc_receiver, :encryptor => :aes, :key => ENCRYPT_KEYS[1]


  ##############
  # attributes #
  ##############

  # 1) gift_id - required - not encrypted - readonly
  validates_presence_of :gift_id
  validates_uniqueness_of :gift_id, :scope => :provider
  attr_readonly :gift_id
  before_validation(on: :create) do
    self.gift_id = self.new_encrypt_pk unless self.gift_id
  end
  def gift_id=(new_gift_id)
    return self['gift_id'] if self['gift_id']
    self['gift_id'] = new_gift_id
  end

  # 2) provider - login provider - required - not encrypted - readonly
  validates_presence_of :provider
  validates_inclusion_of :provider, :in => OmniAuth::Builder.providers, :allow_blank => true

  # 3) user_id_giver - FK - not encrypted.
  # validates_presence_of :user_id_giver, :if => Proc.new {|g| (g.received_at or !g.user_id_receiver) }
  validates_each :user_id_giver do |record, attr, value|
    if record.new_record?
      record.errors.add :base, :giver_or_receiver_must_be_blank if value and record.user_id_receiver
      record.errors.add :base, :giver_or_receiver_is_required if !value and !record.user_id_receiver
    elsif record.user_id_giver_was and record.user_id_giver_was != value
      record.errors.add attr, :readonly
    end
  end

  # 4) user_id_receiver - FK - not encrypted. Gift must have a giver or an receiver when created. Must have giver and receiver when closed
  # validates_presence_of :user_id_receiver, :if => Proc.new {|g| (g.received_at or !g.user_id_giver) }
  validates_each :user_id_receiver do |record, attr, value|
    if record.new_record?
      nil if value and record.user_id_giver # error already reported for user_id_giver
      nil if !value and !record.user_id_giver # # error already reported for user_id_giver
    elsif record.user_id_receiver_was and record.user_id_receiver_was != value
      record.errors.add attr, :readonly
    end
  end

  # 5) picture Y/N - String - not encrypted
  validates_presence_of :picture
  validates_inclusion_of :picture, :allow_blank => true, :in => %w(Y N) ;
  validates_each :picture, :allow_blank => true do |record, attr, value|
    record.errors.add attr, :invalid if value == 'Y' and record.api_picture_url.to_s == ""
  end

  # 6) api_gift_id - String in model - encrypted text in db - api id for the gift / status update on the wall
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

  # 7) api_picture_url - String in Model - encrypted text in db
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

  # 8) api_picture_url_updated_at - timestamp in model - encrypted text
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

  # 9) api_picture_url_on_error_at - timestamp in model - encrypted text (todo) in db
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

  # 10) deleted_at_api. String Y/N.

  # 11) balance giver - Float in Model. Encrypted text in db.
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

  # 12) balance receiver - Float in model - encrypted text in db
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

  # 13) balance_doc_giver. documentation for balance_giver to be used in users/show page
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

  # 14) balance_doc_receiver. documentation for balance_receiver to be used in users/show page
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

  # 15) created_at - timestamp - not encrypted

  # 16) updated_at - timestamp - not encrypted

  # helper methods
  def gift_with_placeholders
    g = gift
    g.giver = self.giver
    g.receiver = self.receiver
    g.picture = self.picture
    g
  end # gift_with_placeholders

  # 1 for closed api gift - 2 for open api gift - used in sort before removing api gift doubles. Used in User.api_gifts sort
  def status_sort
    user_id_giver and user_id_receiver ? 1 : 2
  end # status_sort

  # 1 for picture with error url and creator in login_users
  # 2 for picture
  # 3 for without picture
  # used in sort before removing api gift doubles. Used in User.api_gifts sort
  def picture_sort (login_users)
    return 3 unless picture == 'Y'
    return 2 unless api_picture_url_on_error_at
    # find picture with error marked url - could be missing privs or maybe picture has been deleted on wall
    # sort picture created by login user before other pictures
    if user_id_giver and user_id_receiver
      comment = gift.comments.find { |c| c.accepted_yn == 'Y' }
      creator = comment.user_id == user_id_giver ? user_id_receiver : user_id_giver
    else
      creator = user_id_giver || user_id_receiver
    end
    return 1 if login_users.find { |user| user.user_id == creator } # picture created by login user(s)
    2
  end # picture_sort

  # for ajax show-more-rows functionality
  # api_gift can be a little random for users with multi provider login (see User.api_gift)
  # use api_gift.gift.id for last_row_id in ajax expanding pages (gifts/index and users/show balance tab)
  def last_row_id
    gift.id
  end

  def get_api_picture_url (access_token)
    if picture != 'Y'
      puts "api_gift.get_api_picture_url: picture = \"#{picture}\""
      return nil
    end
    if deleted_at_api == 'Y'
      puts "api_gift.get_api_picture_url: deleted picture"
      return nil
    end
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
    puts "get_api_picture_url: api_response = #{api_response}"
    return api_response["full_picture"]
  end # get_api_picture_url


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
    raise "gift_id must always be initialized as first attribute"
  end


end
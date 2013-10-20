class Friend < ActiveRecord::Base

  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_giver
  belongs_to :friend, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id_receiver

  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  crypt_keeper :api_friend, :app_friend, :encryptor => :aes, :key => ENCRYPT_KEYS[15]


  ##############
  # attributes #
  ##############

  # 1) friend_id - required - not encrypted - readonly
  validates_presence_of :friend_id
  validates_uniqueness_of :friend_id
  attr_readonly :friend_id
  before_validation(on: :create) do
    self.friend_id = self.new_encrypt_pk unless self.friend_id
  end
  def friend_id=(new_friend_id)
    return self['friend_id'] if self['friend_id']
    self['friend_id'] = new_friend_id
  end

  # 2) user_id_giver - String in model and db - not encrypted
  validates_presence_of :user_id_giver
  validates_uniqueness_of :user_id_giver, :scope => :user_id_receiver

  # 3) user_id_receiver - String in model and db - not encrypted
  validates_presence_of :user_id_receiver
  validates_uniqueness_of :user_id_receiver, :scope => :user_id_giver

  # 4) api_friend. String Y/N in model. Encrypted text in db. Required
  # Y or N. Friends in FB or mutual connection in google+
  validates_presence_of :api_friend
  def api_friend
    # puts "gift.api_friend: api_friend = #{read_attribute(:api_friend)} (#{read_attribute(:api_friend).class.name})"
    return nil unless (extended_api_friend = read_attribute(:api_friend))
    encrypt_remove_pre_and_postfix(extended_api_friend, 'api_friend', 16)
  end
  def api_friend=(new_api_friend)
    # puts "gift.api_friend=: api_friend = #{new_api_friend} (#{new_api_friend.class.name})"
    if new_api_friend
      check_type('api_friend', new_api_friend, 'String')
      raise TypeError, "Allowed values for api_friend is Y and N" unless %w(Y N).index(new_api_friend)
      write_attribute :api_friend, encrypt_add_pre_and_postfix(new_api_friend, 'api_friend', 16)
    else
      write_attribute :api_friend, nil
    end
  end
  alias_method :api_friend_before_type_cast, :api_friend

  # 5) app_friend. String Y/N in model. Encrypted text in db.
  # values: nil, Y, N or R.
  #   nil (default) means that friend lists are identical in login api and in app - also used if app friendship request is ignored
  #   R - request for app friendship - used for non api friends to create connection within app
  #   Y - app friends
  #   N - not app friends
  #   B - not app friends and blocked
  def app_friend
    # puts "gift.app_friend: app_friend = #{read_attribute(:app_friend)} (#{read_attribute(:app_friend).class.name})"
    return nil unless (extended_app_friend = read_attribute(:app_friend))
    encrypt_remove_pre_and_postfix(extended_app_friend, 'app_friend', 17)
  end
  def app_friend=(new_app_friend)
    # puts "gift.app_friend=: app_friend = #{new_app_friend} (#{new_app_friend.class.name})"
    if new_app_friend
      check_type('app_friend', new_app_friend, 'String')
      raise TypeError, "Allowed values for app_friend is Y, N, R, P and B" unless %w(Y N R P B).index(new_app_friend)
      write_attribute :app_friend, encrypt_add_pre_and_postfix(new_app_friend, 'app_friend', 17)
    else
      write_attribute :app_friend, nil
    end
  end
  alias_method :app_friend_before_type_cast, :app_friend


  ##################
  # helper methods #
  ##################

  def self.add_friend(userid1, userid2)
    transaction do
      f1 = Friend.new
      f1.user_id_giver = userid1
      f1.user_id_receiver = userid2
      f1.api_friend = 'Y'
      f1.app_friend = nil # nil = default = use api_friend as app_friend status
      f1.save!
      f2 = Friend.new
      f2.user_id_giver = userid2
      f2.user_id_receiver = userid1
      f2.api_friend = 'Y'
      f2.app_friend = nil # nil = default = use api_friend as app_friend status
      f2.save!
    end # transaciton
  end # self.add_friend

  def api_friend?
    api_friend == 'Y'
  end
  def app_friend?
    app_friend == 'Y'
  end



  ##############
  # encryption #
  ##############

  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
  # overwrites non model specific methods defined in /config/initializers/active_record_extensions.rb
  protected
  def encrypt_pk
    self.friend_id
  end
  def encrypt_pk=(new_encrypt_pk_value)
    self.friend_id = new_encrypt_pk_value
  end
  def new_encrypt_pk
    loop do
      temp_friend_id = String.generate_random_string(20)
      return temp_friend_id unless Friend.find_by_friend_id(temp_friend_id)
    end
  end


end

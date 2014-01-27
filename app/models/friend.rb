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
    # logger.debug2  "gift.api_friend: api_friend = #{read_attribute(:api_friend)} (#{read_attribute(:api_friend).class.name})"
    return nil unless (extended_api_friend = read_attribute(:api_friend))
    encrypt_remove_pre_and_postfix(extended_api_friend, 'api_friend', 16)
  end # api_friend
  def api_friend=(new_api_friend)
    # logger.debug2  "gift.api_friend=: api_friend = #{new_api_friend} (#{new_api_friend.class.name})"
    if new_api_friend
      check_type('api_friend', new_api_friend, 'String')
      raise TypeError, "Allowed values for api_friend is Y and N" unless %w(Y N).index(new_api_friend)
      write_attribute :api_friend, encrypt_add_pre_and_postfix(new_api_friend, 'api_friend', 16)
    else
      write_attribute :api_friend, nil
    end
  end # api_friend=
  alias_method :api_friend_before_type_cast, :api_friend
  def api_friend_was
    return api_friend unless api_friend_changed?
    return nil unless (extended_api_friend = attribute_was(:api_friend))
    encrypt_remove_pre_and_postfix(extended_api_friend, 'api_friend', 16)
  end # api_friend_was

  # 5) app_friend. String Y/N in model. Encrypted text in db.
  # values: nil, Y, N or R.
  #   nil (default) means that friend lists are identical in login api and in app - also used if app friendship request is ignored
  #   R - request for app friendship - used for non api friends to create connection within app
  #   Y - app friends
  #   N - not app friends
  #   B - not app friends and blocked
  def app_friend
    # logger.debug2  "gift.app_friend: app_friend = #{read_attribute(:app_friend)} (#{read_attribute(:app_friend).class.name})"
    return nil unless (extended_app_friend = read_attribute(:app_friend))
    encrypt_remove_pre_and_postfix(extended_app_friend, 'app_friend', 17)
  end # app_friend
  def app_friend=(new_app_friend)
    # logger.debug2  "gift.app_friend=: app_friend = #{new_app_friend} (#{new_app_friend.class.name})"
    if new_app_friend
      check_type('app_friend', new_app_friend, 'String')
      raise TypeError, "Allowed values for app_friend is Y, N, R, P and B" unless %w(Y N R P B).index(new_app_friend)
      write_attribute :app_friend, encrypt_add_pre_and_postfix(new_app_friend, 'app_friend', 17)
    else
      write_attribute :app_friend, nil
    end
  end # app_friend=
  alias_method :app_friend_before_type_cast, :app_friend
  def app_friend_was
    return app_friend unless app_friend_changed?
    return nil unless (extended_app_friend = attribute_was(:app_friend))
    encrypt_remove_pre_and_postfix(extended_app_friend, 'app_friend', 17)
  end # app_friend_was


  ##################
  # helper methods #
  ##################

  def self.add_friend(userid1, userid2)
    logger.debug2 "userid1 = #{userid1}, userid2 = #{userid2}"
    transaction do
      # check for any old information about blocked or deselect app friend
      # ( information is kept even if user delete and recreates account )
      f2 = Friend.where('user_id_giver = ? and user_id_receiver = ?', userid2, userid1).first
      f1 = Friend.new
      f1.user_id_giver = userid1
      f1.user_id_receiver = userid2
      f1.api_friend = 'Y'
      if f2
        f1.app_friend = case f2.app_friend
                          when 'B' then 'N' # other user has blocked user1 = login user
                          when 'N' then 'N' # other user has deselect user1 = login user
                          else nil
                        end
      else
        f1.app_friend = nil
      end
      f1.save!
      f2 = Friend.new unless f2
      f2.user_id_giver = userid2
      f2.user_id_receiver = userid1
      f2.api_friend = 'Y'
      f2.save!
    end # transaction
  end # self.add_friend

  def self.remove_friend(userid1, userid2)
    transaction do
      f1 = Friend.where("user_id_giver = ? and user_id_receiver = ?", userid1, userid2).first
      f2 = Friend.where("user_id_giver = ? and user_id_receiver = ?", userid2, userid1).first
      if !f1.app_friend and !f2.app_friend
        # default app_friend value (nil)
        f1.destroy! if f1
        f2.destroy! if f2
        return
      end
      # non default app_friend value (N, B)
      f1.api_friend = 'N'
      f2.api_friend = 'N'
      f1.save!
      f2.save!
    end # transaction
  end # self.remove_friend

  def api_friend?
    api_friend == 'Y'
  end
  def app_friend?
    app_friend == 'Y'
  end

  # friends_hash is hash with old and new friend from util_controller.post_login_<provider> api request
  # mutual_friends = true: facebook, linkedin - update friend list for login user and for friend
  # mutual friends = false: google+, twitter - update only friend list for login user
  def self.update_friends_from_hash (options)
    login_user_id = options[:login_user_id]
    friends_hash = options[:friends_hash]
    mutual_friends = options[:mutual_friends]
    fields = options[:fields] || %w(name)
    provider = login_user_id.split('/').last
    if fields.index('api_profile_picture_url')
      # check picture store for profile pictures
      picture_store = API_PROFILE_PICTURE_STORE[provider] || :api
      if ![:local,:api].index(picture_store)
        logger.fatal2 "unknown profile picture store #{picture_store} for login provider #{provider}"
        logger.fatal2 "please check array constant API_PROFILE_PICTURE_STORE (/config/initializers/omniauth.rb"
        picture_store = :api
      end
    end

    # update selected user fields - different api clients/providers returns different information about friends
    friends_hash.each do |friend_user_id, hash|
      friend_user = nil
      if fields.index('name')
        # update name
        if hash[:old_name] != hash[:new_name]
          friend_user = hash[:user]
          friend_user.user_name = hash[:new_name].force_encoding('UTF-8')
        end
      end
      if fields.index('api_profile_url')
        # update api_profile_url
        if hash[:old_api_profile_url] != hash[:new_api_profile_url]
          friend_user = hash[:user] unless friend_user
          friend_user.api_profile_url = hash[:new_api_profile_url]
        end
      end
      if fields.index('api_profile_picture_url')
        # update api_profile_picture_url
        if hash[:old_api_profile_picture_url] != hash[:new_api_profile_picture_url]
          # check picture store
          # do not overwrite old picture if local picture store and old picture url is an local url
          local = (picture_store == :local and Picture.app_url?(hash[:old_api_profile_picture_url]))
          if !hash[:old_api_profile_picture_url] or picture_store == :api or !local
            friend_user = hash[:user] unless friend_user
            friend_user.api_profile_picture_url = hash[:new_api_profile_picture_url]
          end
        end
      end
      if fields.index('no_api_friends')
        # update no_api_friends
        if hash[:old_no_api_friends] != hash[:new_no_api_friends]
          # logger.debug2  "fetch_user: update api profile url: old url = #{hash[:old_no_api_friends]}, new url = #{hash[:new_no_api_friends]}"
          friend_user = hash[:user] unless friend_user
          friend_user.no_api_friends = hash[:new_no_api_friends]
        end
      end
      friend_user.save! if friend_user
    end # each

    # update api_fiend
    friends_hash.each do |friend_user_id, hash|
      if hash[:new_record]
        # new friend entries
        # logger.debug2  "new friend entries"
        Friend.add_friend(login_user_id, friend_user_id)
      else
        # keep dummy friend row for login user. user_id_giver == user_id_receiver
        next if login_user_id == friend_user_id
        # old friend entry
        # logger.debug2  "old friend entry, name = #{hash[:new_name]}, old api friend = #{hash[:old_api_friend]}, new api friend = #{hash[:new_api_friend]}"
        next if hash[:old_api_friend] == hash[:new_api_friend] # no change in api friend status
        # api friend status changed
        f1 = Friend.where("user_id_giver = ? and user_id_receiver = ?", login_user_id, friend_user_id).first
        f2 = Friend.where("user_id_giver = ? and user_id_receiver = ?", friend_user_id, login_user_id).first
        if (f1 == nil or f1.app_friend == nil) and (f2 == nil or f2.app_friend == nil)
          # Default app_friend status - just delete
          # logger.debug2  "Default app_friend status - just delete"
          Friend.remove_friend(login_user_id, friend_user_id)
          next
        end
                                                               # non default app_friend status - update - do not delete
        if !f1
          # create missing friend (error)
          f1 = Friend.new
          f1.user_id_giver = login_user_id
          f1.user_id_receiver = friend_user_id
          f1.app_friend = nil
        end
        if !f2
          # create missing friend (error)
          f2 = Friend.new
          f1.user_id_giver = friend_user_id
          f1.user_id_receiver = login_user_id
          f2.app_friend = nil
        end
        f1.api_friend = f2.api_friend = hash[:new_api_friend]
                                                               # logger.debug2  "before save"
                                                               # logger.debug2  "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
                                                               # logger.debug2  "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
        f1.save!
        f2.save!
                                                               # logger.debug2  "after save"
        f1.reload
        f2.reload
                                                               # logger.debug2  "update f1: giver = #{f1.user_id_giver}, receiver = #{f1.user_id_receiver}, api = #{f1.api_friend}, app = #{f1.app_friend}"
                                                               # logger.debug2  "update f2: giver = #{f2.user_id_giver}, receiver = #{f2.user_id_receiver}, api = #{f2.api_friend}, app = #{f2.app_friend}"
        raise "api_friend status was not updated" unless f1.api_friend == hash[:new_api_friend] and f2.api_friend == hash[:new_api_friend]
      end # if
    end # each
    # facebook friend list updated

  end # self.update_friends_from_hash

  def self.define_sort_by_user_name (friends)
    friends.define_singleton_method :sort_by_user_name do
      self.sort do |a, b|
        if a.friend.user_name == b.friend.user_name
          a.friend.id <=> b.friend.id
        else
          a.friend.user_name <=> b.friend.user_name
        end
      end # sort
    end # sort_by_user_name
    friends
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

class Comment < ActiveRecord::Base

  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id

  after_create :after_create


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :comment, :currency, :price, :encryptor => :aes, :key => ENCRYPT_KEYS[28]


  ##############
  # attributes #
  ##############

  # 1) comment_id - required - not encrypted - readonly
  validates_presence_of :comment_id
  validates_uniqueness_of :comment_id
  attr_readonly :comment_id
  before_validation(on: :create) do
    self.comment_id = self.new_encrypt_pk unless self.comment_id
  end
  def comment_id=(new_comment_id)
    return self['comment_id'] if self['comment_id']
    self['comment_id'] = new_comment_id
  end

  # 2) user_id - required - not encrypted - readonly
  validates_presence_of :user_id
  attr_readonly :user_id  
  
  # 3) comment - required - String in model - encrypted text in db
  def comment
    # puts "comment.comment: comment = #{read_attribute(:comment)} (#{read_attribute(:comment).class.name})"
    return nil unless (extended_comment = read_attribute(:comment))
    encrypt_remove_pre_and_postfix(extended_comment, 'comment', 31)
  end
  def comment=(new_comment)
    # puts "comment.comment=: comment = #{new_comment} (#{new_comment.class.name})"
    if new_comment
      check_type('comment', new_comment, 'String')
      write_attribute :comment, encrypt_add_pre_and_postfix(new_comment, 'comment', 31)
    else
      write_attribute :comment, nil
    end
  end
  alias_method :comment_before_type_cast, :comment

  # 4) Gift id - required - unencrypted string

  # 5) currency - only for agreement proposal - String in model - encrypted text in db - update not allowed
  attr_readonly :currency
  def currency
    return nil unless (extended_currency = read_attribute(:currency))
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 32)
  end
  def currency=(new_currency)
    if !new_record?
      nil
    elsif new_currency
      check_type('currency', new_currency, 'String')
      write_attribute :currency, encrypt_add_pre_and_postfix(new_currency, 'currency', 32)
    else
      write_attribute :currency, nil
    end
  end # currency
  alias_method :currency_before_type_cast, :currency

  # 6) price - only for agreement proposal - Float in model - encrypted text in db
  def price
    return nil unless (temp_extended_price = read_attribute(:price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 33)
  end # price
  def price=(new_price)
    if !new_record?
      nil
    elsif new_price.to_s != ''
      check_type('price', new_price, 'Float')
      write_attribute :price, encrypt_add_pre_and_postfix(new_price.to_s, 'price', 33)
    else
      write_attribute :price, nil
    end
  end # price=
  alias_method :price_before_type_cast, :price


  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments

  # Note: 48 different translations. See inbox/index/gift_comment*
  # noti_key_prefix is 1) gift_comment_giver, 2) gift_comment_receiver, 3) gift_comment_giver_and_receiver, 4) gift_comment_giver_other, 5) gift_comment_receiver_other or 6) gift_comment_giver_and_receiver_other
  # from_user is user that has commented the gift - added to noti_options hash
  # to_user is giver, receiver or an other user that also has commented the gift - receiver of notification
  def create_or_update_noti (noti_key_prefix, from_user, to_user)
    noti_key_prefix_lng = noti_key_prefix.length
    noti_key_version = 1
    regexp = Regexp.new "^#{noti_key_prefix}_(1|2|3|n)_v#{noti_key_version}$"
    # puts "regexp = #{regexp}"
    match = nil
    n = Notification.where("to_user_id = ? and noti_read = 'N'", to_user.user_id)
                     .find { |n| n.noti_options[:giftid] == gift.id and match = regexp.match(n.noti_key) }
    if !n
      # first unread comment for this gift
      # puts "first unread comment for this gift"
      n = Notification.new
      n.to_user_id = to_user.user_id
      n.from_user_id = nil
      n.internal = 'Y'
      n.noti_key = "#{noti_key_prefix}_1_v#{noti_key_version}"
      n.noti_options = { :giftid => gift.id, :gifttext => gift.description.first(30),
                         :no_users => 1, :no_other_users => -1,
                         :userid1 => from_user.id, :username1 => from_user.short_user_name,
                         :userid2 => nil, :username2 => nil,
                         :userid3 => nil, :username3 => nil,
                         :givername => (gift.user_id_giver ? gift.giver.short_user_name : ""),
                         :receivername => (gift.user_id_receiver ? gift.receiver.short_user_name : "") }
      n.noti_read = 'N'
    elsif [n.noti_options[:userid1], n.noti_options[:userid2], n.noti_options[:userid3]].index(from_user.id)
      # user already in unread notification message
      # puts "user already in unread notification message"
      nil
    else
      # change noti_key / add user to unread notification message
      # puts "change noti_key / add user to unread notification message"
      noti_options = n.noti_options # copy to/from local variable for encryption to work
      noti_options[:no_users] += 1
      noti_options[:no_other_users] += 1
      if noti_options[:no_users] > 3 then
        xno_users = 'n'
      else
        xno_users = noti_options[:no_users].to_s
        noti_options["userid#{xno_users}".to_sym] = from_user.id
        noti_options["username#{xno_users}".to_sym] = from_user.short_user_name
      end
      n.noti_key = "#{noti_key_prefix}_#{xno_users}_v#{noti_key_version}"
      n.noti_options = noti_options
    end
    n.valid?
    # todo: error response from comment/create does not work
    puts "n.errors = " + n.errors.full_messages.join('. ') if not n.valid?
    n.save!
    # add comment id to ajax comments - used in new messages count where new comments is ajax inserted in gifts/index page
    # buffer is returned to gifts/index page and cleared in util_controller.new_messages_count
    # buffer is cleared in gifts_controller.index when user starts or reloads index page
    # buffer is emptied for messages older whan 6 minutes in AjaxComment.after_insert call back
    ac = AjaxComment.new
    ac.user_id = to_user.user_id
    ac.comment_id = comment_id ;
    ac.save!
  end # create_or_update_noti


  # Note: 48 different translations. See inbox/index/gift_comment*
  def after_create
    # noti_key_format: <noti_key_prefix>_<n>_v1
    # noti_key_prefix: gift_comment_giver (offer), gift_comment_receiver (seek) or gift_comment_giver_and_receiver (closed)
    # n: 1, 2, 3 or n : number of users that has commented the gift
    # v1: version of noti_option hash format - change to next version if changing hast keys for translations
    # remember to setup translation keys (gift_comment_giver_1_v1_to_url, gift_comment_giver_1_v1_to_msg etc)
    noti_key_prefix = 'gift_comment_'
    noti_key_prefix += case
                          when gift.giver && gift.receiver then 'giver_and_receiver'
                          when gift.giver then 'giver'
                          when gift.receiver then 'receiver'
                       end
    puts "noti_key_prefix = #{noti_key_prefix}"
    # send notifications
    # 1) notifications to giver and/or receiver
    logger.info "send notifications to gifts giver and/or receiver"
    users1 = []
    users1.push(gift.giver) if gift.user_id_giver and user_id != gift.user_id_giver
    users1.push(gift.receiver) if gift.user_id_receiver and user_id != gift.user_id_receiver
    users1_ids = users1.collect { |u| u.user_id }
    # 2) notifications to users that has commented the gift - note that "_other" is added to notification key!
    users2 = gift.comments.includes(:user).collect { | c| c.user }.find_all { |user2| ![user.user_id, gift.user_id_giver, gift.user_id_receiver].index(user2.user_id) }.uniq
    users2_ids = users2.collect { |u| u.user_id }
    users_ids = (users1_ids + users2_ids).uniq
    # check followers - users that have selected to follow gift comments - users that have selected NOT to follow gift comments
    GiftLike.where("gift_id = ? and follow is not null", gift.gift_id).each do |gl|
      if gl.follow == 'Y'
        # user has selected to follow gift
        users1 << gl.user if !users_ids.index(gl.user_id)
      else
        # user has deselected to follow gift
        users1 = users1.delete_if { |u| u.user_id == gl.user_id }
        users2 = users2.delete_if { |u| u.user_id == gl.user_id }
      end
    end # each
    # send notifications
    logger.info "send notifications to gifts giver, receiver and followers: " + users1.collect { |u| u.short_user_name }.join(', ')
    users1.each { |user2| create_or_update_noti(noti_key_prefix, user, user2) }
    logger.info "send notifications to other users that also have commented the gift: " + users2.collect { |u| u.short_user_name }.join(', ')
    users2.each { |user2| create_or_update_noti(noti_key_prefix + '_other', user, user2) }
  end # after_create
  

  ##############
  # encryption #
  ##############

  # https://github.com/jmazzi/crypt_keeper gem encrypts all attributes and all rows in db with the same key
  # this extension to use different encryption for each attribute and each row
  # overwrite non model specific methods defined in /config/initializers/active_record_extensions.rb
  protected
  def encrypt_pk
    self.comment_id
  end
  def encrypt_pk=(new_encrypt_pk_value)
    self.comment_id = new_encrypt_pk_value
  end
  def new_encrypt_pk
    loop do
      temp_comment_id = String.generate_random_string(20)
      return temp_comment_id unless Comment.find_by_comment_id(temp_comment_id)
    end
  end

end # Comment

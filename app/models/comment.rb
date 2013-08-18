class Comment < ActiveRecord::Base

  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id

  after_create :after_create


  # https://github.com/jmazzi/crypt_keeper - text columns are encrypted in database
  # encrypt_add_pre_and_postfix/encrypt_remove_pre_and_postfix added in setters/getters for better encryption
  # this is different encrypt for each attribute and each db row
  # _before_type_cast methods are used by form helpers and are redefined
  crypt_keeper :comment, :encryptor => :aes, :key => ENCRYPT_KEYS[28]


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
    encrypt_remove_pre_and_postfix(extended_comment, 'comment', 2)
  end
  def comment=(new_comment)
    # puts "comment.comment=: comment = #{new_comment} (#{new_comment.class.name})"
    if new_comment
      check_type('comment', new_comment, 'String')
      write_attribute :comment, encrypt_add_pre_and_postfix(new_comment, 'comment', 2)
    else
      write_attribute :comment, nil
    end
  end
  alias_method :comment_before_type_cast, :comment


  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments

  # user2 is giver or receiver - receiver of notification
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
                         :userid3 => nil, :username3 => nil }
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
  end # create_or_update_noti


  def after_create
    puts "user_id = #{user_id}, user_id_giver = #{gift.user_id_giver}, user_id_receiver = #{gift.user_id_receiver}"
    return if user_id == gift.user_id_receiver and !gift.user_id_giver
    return if user_id == gift.user_id_giver and !gift.user_id_receiver
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
    if gift.user_id_giver and user_id != gift.user_id_giver
      # notification to giver.
      create_or_update_noti(noti_key_prefix, user, gift.giver)
    end
    if gift.user_id_receiver and user_id != gift.user_id_receiver
      # notification to receiver
      create_or_update_noti(noti_key_prefix, user, gift.receiver)
    end
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

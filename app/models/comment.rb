# translation key used in notifications. 4 elements.
# noti_type:
NOTI_KEY_1 = {1 => 'new_comment',
              2 => 'new_proposal',
              3 => 'cancelled_proposal',
              4 => 'rejected_proposal',
              5 => 'accepted_proposal'}
# gift type:
NOTI_KEY_2 = {1 => 'giver',
              2 => 'receiver',
              3 => 'giver_and_receiver'}
# used for other user that have commented the gift
NOTI_KEY_3 = "other"
NOTI_KEY_4 = "1" # version


class Comment < ActiveRecord::Base

  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id
  has_and_belongs_to_many :notifications

  before_create :before_create
  after_create :after_create
  after_update :after_update
  before_destroy :before_destroy


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
  end

  # currency
  alias_method :currency_before_type_cast, :currency

  # 6) price - only for agreement proposal - Float in model - encrypted text in db
  def price
    return nil unless (temp_extended_price = read_attribute(:price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 33)
  end

  # price
  def price=(new_price)
    if !new_record?
      nil
    elsif new_price.to_s != ''
      check_type('price', new_price, 'Float')
      write_attribute :price, encrypt_add_pre_and_postfix(new_price.to_s, 'price', 33)
    else
      write_attribute :price, nil
    end
  end

  # price=
  alias_method :price_before_type_cast, :price

  # 7) new_deal_yn - y for agreement proposal - n for cancelled agreement - not encrypted string

  # 8) accepted_yn - y for accepted agreement - n for rejected agreement - not encrypted string

  # 9) status_update_at - integer - keep track of comments changed after user has loaded gifts/index page


  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments

  def table_row_id
    "gift-#{gift.id}-comment-#{id}"
  end

  # table_row_id

  # display cancel new deal check box?
  # only for new not accepted/rejected agreement proposals
  def show_cancel_new_deal_link? (user)
    return false unless new_deal_yn == 'Y'
    return false if accepted_yn
    return false unless user_id == user.user_id
    return false if gift.user_id_receiver and gift.user_id_giver
    true
  end

  # show_cancel_new_deal_link?

  def show_accept_new_deal_link? (user)
    return false unless new_deal_yn == 'Y'
    return false if accepted_yn
    return false if user_id == user.user_id
    return false if gift.user_id_receiver and gift.user_id_giver
    return false unless [gift.user_id_receiver, gift.user_id_giver].index(user.user_id)
    true
  end

  # show_accept_new_deal_link?

  def show_reject_new_deal_link? (user)
    show_accept_new_deal_link?(user)
  end

  # show_reject_new_deal_link?

  def show_delete_comment_link?(user)
    return false unless user_id == user.user_id
    return false if new_deal_yn == 'Y' and accepted_yn == 'Y'
    true
  end # show_delete_comment_link?


  def get_noti_key_prefix (noti_key_1, noti_key_2, noti_key_3)
    NOTI_KEY_1[noti_key_1] + '_' + NOTI_KEY_2[noti_key_2] + (noti_key_3 ? '_' + NOTI_KEY_3 : '')
  end # get_noti_key_prefix

  def init_noti_key_regexp (noti_key_1, noti_key_2, noti_key_3)
    noti_key_prefix = get_noti_key_prefix(noti_key_1, noti_key_2, noti_key_3)
    Regexp.new "^#{noti_key_prefix}_(1|2|3|n)_v#{NOTI_KEY_4}$"
  end # init_noti_key_regexp



  # Note: nnn different translations. See inbox/index/gift_comment*
  # noti_key_1: 1:new comment, 2:new proposal, 3:cancelled proposal, 4:rejected proposal, 5:accepted proposal
  # noti_key_2: 1:giver, 2:receiver, 3: giver and receiver
  # noti_key_3: false: notification to owner of gift and followers of gift, true: notification to other users that has commented the gift
  # from_user is user that has commented the gift - added to noti_options hash
  # to_user is giver, receiver or an other user that also has commented the gift - receiver of notification
  # noti_key is concatenation of noti_key_1, noti_type_2, noti_key_3 and NOTI_KEY_4 (version)
  # total of 176 different translation keys                                   8
  # config/locales/language.yml/inbox/index/new_comment_* (48 translations)
  # config/locales/language.yml/inbox/index/new_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/cancelled_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/rejected_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/accepted_proposal_* (32 translations)
  def send_notification (noti_key_1, noti_key_2, noti_key_3, from_user, to_user)
    if [3,4,5].index(noti_key_1)
      # special handling of noti_type_1 = 3..5. noti_key_1 (noti_type):
      #   3 - cancelled proposal notification
      #       a) change unread new proposal notification to new_comment notification
      #       b) read new proposal - send cancelled proposal notification to owner of gift
      #       c) read new proposal - don't send any other notifications
      #   4 - rejected proposal
      #       a) change any unread new proposal notification to new comment notification
      #       b) send rejected proposal notification to owner of new proposal / comment
      #       c) don't send any other notifications
      #   5 - accepted proposal
      #       a) unread - change unread new proposal notification to accepted proposal notification
      #       b) read - send accepted proposal notification
      regexp = init_noti_key_regexp(2, noti_key_2, noti_key_3)
      puts "regexp = #{regexp}, comment.id = #{id}, to_userid = #{to_user.user_id}"
      new_proposal_notification = notifications.where("to_user_id = ? and noti_read = 'N'", to_user.user_id).find_all { |n| regexp.match(n.noti_key)}.first
      puts new_proposal_notification
      if new_proposal_notification
        # 3a, 4a or 5a
        remove_from_notification(new_proposal_notification)
        if [3,4].index(noti_key_1)
          # 3a or 4a
          send_notification(1, noti_key_2, noti_key_3, from_user, to_user) # new comment notification
          return
        end
        # 5a => 5b
      else
        # 3b, 3c, 4b, 4c, 5b
        return if noti_key_1 == 3 and ![gift.user_id_giver, gift.user_id_receiver].index(to_user.user_id) # 3c
        return if noti_key_1 == 4 and user_id != to_user.user_id # 4c
        # 3b, 4b, 5b
      end
    end # if [3,4,5].index(noti_key_1)

    noti_key_prefix = get_noti_key_prefix(noti_key_1, noti_key_2, noti_key_3)
    regexp = init_noti_key_regexp(noti_key_1, noti_key_2, noti_key_3)
    # puts "regexp = #{regexp}"
    match = nil
    n = Notification.where("to_user_id = ? and noti_read = 'N'", to_user.user_id)
    .find { |n| n.noti_options[:giftid] == gift.id and match = regexp.match(n.noti_key) }
    if !n
      # first unread comment for this gift
      puts "first unread comment for this gift"
      n = Notification.new
      n.to_user_id = to_user.user_id
      n.from_user_id = nil
      n.internal = 'Y'
      n.noti_key = "#{noti_key_prefix}_1_v#{NOTI_KEY_4}" # no_users = 1
      noti_options = {:giftid => gift.id, :gifttext => gift.description.first(30),
                        :no_users => 0, :no_other_users => -2,
                        :username1 => nil,
                        :username2 => nil,
                        :username3 => nil,
                        :givername => (gift.user_id_giver ? gift.giver.short_user_name : ""),
                        :receivername => (gift.user_id_receiver ? gift.receiver.short_user_name : "")}
      puts "noti_key_1 = #{noti_key_1}, noti_key_3 = #{noti_key_3}"
      unless [4,5].index(noti_key_1) and !noti_key_3
        # user array not used for rejected and accepted notification to owner of comment
        noti_options[:username1] = from_user.short_user_name
        noti_options[:no_users] += 1
        noti_options[:no_other_users] += 1
      end
      n.noti_options = noti_options
      n.noti_read = 'N'
    elsif [4,5].index(noti_key_1) and noti_key_3
      raise "debug - this notification should only be sent once"
    elsif n.comments.find { |c| c.user_id == from_user.user_id }
      # user already in unread notification messages "user array"
      # puts "user already in unread notification message"
      nil
    else
      # user not in unread notification messages "user array"
      # change noti_key / add user to unread notification message
      # puts "change noti_key / add user to unread notification message"
      noti_options = n.noti_options # copy to/from local variable for encryption to work
      noti_options[:no_users] += 1
      noti_options[:no_other_users] += 1
      if noti_options[:no_users] > 3 then
        xno_users = 'n'
      else
        xno_users = noti_options[:no_users].to_s
        noti_options["username#{xno_users}".to_sym] = from_user.short_user_name
      end
      n.noti_key = "#{noti_key_prefix}_#{xno_users}_v#{NOTI_KEY_4}"
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
    ac.comment_id = comment_id;
    ac.save!
    # add row to CommentNotification / keep track of number of users in notification message
    puts "add CommentNotification for comment id #{id} and notification id #{n.id}"
    cn = CommentNotification.where("comment_id = ? and notification_id = ?", id, n.id).first
    if !cn
      cn = CommentNotification.new
      cn.comment_id = id
      cn.notification_id = n.id
      cn.save!
    end
  end # create_or_update_noti

  # comment no longer relevant for unread notification n
  # used when comments are deleted, deal proposal is cancelled, rejected or accepted
  def remove_from_notification (n)
    puts "remove_from_notification. comment id #{id}. Notification id #{n.id}. notification key #{n.noti_key}"
    # only modify unread notifications
    return unless n.noti_read == 'N'
    cn = notifications.where("notification_id = ?", n.id).first
    # find no users before and after removing this comment from notification
    old_no_users = n.comments.collect { |c| c.user_id }.uniq.size
    new_users = n.comments.find_all { |c| c.id != id }.collect { |c| c.user }.uniq
    new_no_users = new_users.size
    if new_no_users == 0
      # last user for this unread notification has been removed
      puts "last user for this unread notification has been removed"
      n.destroy!
      return
    end
    return if old_no_users == new_no_users # unchanged number of users => unchanged notification
    if new_no_users > 3
      # unchanged noti_key and username array. Just change number of users
      puts "unchanged noti_key and username array. Just change number of users"
      notifications.delete(cn) if cn
      noti_options = n.noti_options
      noti_options[:no_users] = new_no_users
      noti_options[:no_other_users] = new_no_users - 2
      n.noti_options = noti_options
      n.save!
      return
    end
    # change noti_key, username array and number of users
    if n.noti_key !~ /^([a-z_]+)_(\d)_v(\d+)$/
      puts "invalid noti key format. noti key = #{noti_key}"
      return
    end
    puts "change noti_key, username array and number of users"
    noti_key_prefix, noti_key_no_users, noti_key_version = $1
    noti_options = n.noti_options
    (1..3).each { |i| noti_options["username#{i}".to_sym] = nil }
    usernames = new_users.collect { |u| u.short_user_name }
    0.upto(usernames.size-1).each do |i|
      noti_options["username#{i+1}".to_sym] = usernames[i]
    end
    noti_options[:no_users] = new_no_users
    noti_options[:no_other_users] = new_no_users - 2
    n.noti_key = "#{noti_key_prefix}_#{new_no_users}_v#{noti_key_version}"
    puts "noti_key: old = #{n.noti_key_was}, new = #{n.noti_key}"
    n.noti_options = noti_options
    notifications.delete(cn) if cn
    n.save!
  end # remove_from_notification


  def before_create
    self.status_update_at = Sequence.next_status_update_at
  end

  # Note: 176 different translation keys                                   8
  # config/locales/language.yml/inbox/index/new_comment_* (48 translations)
  # config/locales/language.yml/inbox/index/new_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/cancelled_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/rejected_proposal_* (32 translations)
  # config/locales/language.yml/inbox/index/accepted_proposal_* (32 translations)
  # this method is also called from after_update for noti types 3 .. 5 (cancel, reject and accept). update = true
  def after_create (update = false)
    # find noti_type and noti_userid.
    # noti_type: 1:new comment, 2:new proposal, 3:cancelled proposal, 4:rejected proposal, 5:accepted proposal
    # noti_userid: user behind action - newer send notification to this user.
    if update
      # after_update
      case
        when new_deal_yn == 'Y' && !accepted_yn_was && accepted_yn == 'Y'
          noti_key_1 = 5 # accepted
          from_userid = gift.user_id_giver || gift.user_id_receiver
        when new_deal_yn == 'Y' && !accepted_yn_was && accepted_yn == 'N'
          noti_key_1 = 4 # rejected
          from_userid = gift.user_id_giver || gift.user_id_receiver
        when new_deal_yn_was == 'Y' && !new_deal_yn && !accepted_yn
          noti_key_1 = 3 # cancelled
          from_userid = user_id
      end # case
      # after update
    else
      # after insert
      if new_deal_yn == 'Y'
        noti_key_1 = 2 # proposal
      else
        noti_key_1 = 1 # comment
      end
      from_userid = user_id
      # after insert
    end
    from_user = User.find_by_user_id(from_userid)
    case
      when gift.giver && gift.receiver then
        noti_key_2 = 3
      when gift.giver then
        noti_key_2 = 1
      when gift.receiver then
        noti_key_2 = 2
    end
    noti_key_prefix = NOTI_KEY_1[noti_key_1] + '_' + NOTI_KEY_2[noti_key_2]
    puts "noti_key_prefix = #{noti_key_prefix}"
    # send notifications
    # 1) notifications to giver and/or receiver
    logger.info "send notifications to gifts giver and/or receiver"
    users1 = []
    users1.push(gift.giver) if gift.user_id_giver and from_userid != gift.user_id_giver
    users1.push(gift.receiver) if gift.user_id_receiver and from_userid != gift.user_id_receiver
    if [4, 5].index(noti_key_1)
      # special rejected/accepted notification to owner of comment
      to_user_id = user_id
      users1.push(user) if [4, 5].index(noti_key_1)
    end
    users1_ids = users1.collect { |u| u.user_id }
    puts "1: users1 = " + users1_ids.join(', ')
    # 2) notifications to users that has commented the gift - "_other" is added to notification key!
    users2 = gift.comments.includes(:user).collect { |c| c.user }.find_all { |user2| ![from_userid, to_user_id, gift.user_id_giver, gift.user_id_receiver].index(user2.user_id) }.uniq
    users2_ids = users2.collect { |u| u.user_id }
    users_ids = (users1_ids + users2_ids).uniq
    puts "2: users2 = " + users2_ids.join(', ')
    # 3) check followers - users that have selected to follow gift comments - users that have selected NOT to follow gift comments
    puts "3: adding followers"
    GiftLike.where("gift_id = ? and follow is not null", gift.gift_id).each do |gl|
      next if
      if gl.follow == 'Y'
        # user has selected to follow gift
        users1 << gl.user if gl.user.user_id != from_userid and !users_ids.index(gl.user_id)
      else
        # user has deselected to follow gift
        users1 = users1.delete_if { |u| u.user_id == gl.user_id }
        users2 = users2.delete_if { |u| u.user_id == gl.user_id }
      end
    end # each
    puts "3: users1 = " + users1_ids.join(', ')
    puts "3: users2 = " + users2_ids.join(', ')
    # send notifications
    logger.info "send notifications to gifts giver, receiver and followers: " + users1.collect { |u| u.short_user_name }.join(', ')
    users1.each { |to_user| send_notification(noti_key_1, noti_key_2, false, from_user, to_user) }
    logger.info "send notifications to other users that also have commented the gift: " + users2.collect { |u| u.short_user_name }.join(', ')
    users2.each { |to_user| send_notification(noti_key_1, noti_key_2, true, from_user, to_user) }
    # new comment and new proposal - add user as follower of gift - user will receive notifications until user stops following the gift
    if noti_key_1 <= 2 and ![gift.user_id_giver, gift.user_id_receiver].index(user_id)
      gl = GiftLike.where("user_id = ? and gift_id = ?", user_id, gift.gift_id).first
      if gl
        gl.follow = 'Y' unless gl.follow
      else
        gl = GiftLike.new
        gl.user_id = user_id
        gl.gift_id = gift.gift_id
        gl.like = 'N'
        gl.follow = 'Y'
        gl.show = 'Y'
      end
      gl.save!
    end
  end # after_create

  def after_update
    puts "comment.after update:"
    puts "new deal_yn: #{new_deal_yn_was} (#{new_deal_yn_was.class}) => #{new_deal_yn} (#{new_deal_yn.class})"
    puts "accepted_jn: #{accepted_yn_was} (#{accepted_yn_was.class}) => #{accepted_yn} (#{accepted_yn.class})"
    # comment: after update: new deal: Y => Y, accepted:  => N
    # check for canceled, rejected or accepted deal proposal
    if  (new_deal_yn == 'Y' and !accepted_yn_was and accepted_yn == 'Y') or # noti_type 5: accepted proposal
        (new_deal_yn == 'Y' and !accepted_yn_was and accepted_yn == 'N') or # noti type 4: rejected proposal
        (new_deal_yn_was == 'Y' and !new_deal_yn and !accepted_yn) # noti type 3: cancelled proposal
      puts "call after_create method"
      after_create(true)
    end # cancelled deal proposal
  end # after_update

  def before_destroy
    puts "cleanup any unread notifications"
    # change number of users for uny unread notifications
    notifications.find_all { |n| n.noti_read == 'N' }.each do |n|
      remove_from_notification(n)
    end # each n
  end # before_destroy


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

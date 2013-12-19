# translation key used in notifications. 4 elements.
# noti_type:
NOTI_KEY_1 = {1 => 'new_comment',
              2 => 'new_proposal',
              3 => 'cancelled_proposal',
              4 => 'rejected_proposal',
              5 => 'accepted_proposal'}
# gift type/status
NOTI_KEY_2 = {1 => 'giver',
              2 => 'receiver',
              3 => 'giver_and_receiver'}
# user group.
NOTI_KEY_3 = {1 => '',
              2 => '_other',
              3 => '_follow'}
NOTI_KEY_4 = "1" # version


class Comment < ActiveRecord::Base

  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id
  has_and_belongs_to_many :notifications

  before_create :before_create
  before_update :before_update
  # before_destroy :before_destroy
  after_create :after_create
  after_update :after_update

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
  def comment_was
    return comment unless comment_changed?
    return nil unless (extended_comment = attribute_was(:comment))
    encrypt_remove_pre_and_postfix(extended_comment, 'comment', 31)
  end


  # 4) Gift id - required - unencrypted string

  # 5) currency - only for agreement proposal - String in model - encrypted text in db - update not allowed
  attr_readonly :currency
  validates_inclusion_of :currency, :allow_blank => true, :in => Money::Currency.table.collect { |a| [  a[1][:iso_code] ][0] }

  def currency
    return nil unless (extended_currency = read_attribute(:currency))
    # puts "Comment.currency: currency = #{extended_currency}"
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 32)
  end # currency
  def currency=(new_currency)
    if !new_record?
      nil
    elsif new_currency
      check_type('currency', new_currency, 'String')
      write_attribute :currency, encrypt_add_pre_and_postfix(new_currency, 'currency', 32)
    else
      write_attribute :currency, nil
    end
  end # currency=
  alias_method :currency_before_type_cast, :currency
  def currency_was
    return currency unless currency_changed?
    return nil unless (extended_currency = attribute_was(:currency))
    # puts "Comment.currency: currency = #{extended_currency}"
    encrypt_remove_pre_and_postfix(extended_currency, 'currency', 32)
  end # currency_was

  # 6) price - only for agreement proposal - Float in model - encrypted text in db
  # todo: there is a minor problem with price validation.
  # price= accepts only float and model can not return invalid price errors
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
  def price_was
    return price unless price_changed?
    return nil unless (temp_extended_price = attribute_was(:price))
    str_to_float_or_nil encrypt_remove_pre_and_postfix(temp_extended_price, 'price', 33)
  end # price_was

  # 7) new_deal_yn - y for agreement proposal - n for cancelled agreement - not encrypted string

  # 8) accepted_yn - y for accepted agreement - n for rejected agreement - not encrypted string

  # 9) status_update_at - integer - keep track of comments changed after user has loaded gifts/index page


  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments

  def debug_notifications
    true
  end # debug_notifications

  def table_row_id
    "gift-#{gift.id}-comment-#{id}"
  end # table_row_id

  # display cancel new deal check box?
  # only for new not accepted/rejected agreement proposals
  def show_cancel_new_deal_link? (users)
    return false unless new_deal_yn == 'Y'
    return false if accepted_yn
    return false unless users.find { |user| user_id == user.user_id }
    return false if gift.direction == 'both'
    true
  end # show_cancel_new_deal_link?

  def show_accept_new_deal_link? (users)
    return false unless new_deal_yn == 'Y'
    return false if accepted_yn
    return false if users.find { |user| user_id == user.user_id }
    return false if gift.direction == 'both'
    gift.api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      return true if [api_gift.user_id_receiver, api_gift.user_id_giver].index(user.user_id)
    end
    false
  end # show_accept_new_deal_link?

  def show_reject_new_deal_link? (users)
    show_accept_new_deal_link?(users)
  end # show_reject_new_deal_link?

  def show_delete_comment_link?(users)
    return false unless users.class == Array and users.length > 0
    gift.api_gifts.each do |api_gift|
      user = users.find { |user2| user2.provider == api_gift.provider }
      next unless user
      return true if [api_gift.user_id_receiver, api_gift.user_id_giver].index(user.user_id)
    end
    false
  end # show_delete_comment_link?

  def cancelled_proposal?
    noti_type = 3 if (new_deal_yn_was == 'Y' and !new_deal_yn and !accepted_yn)
    noti_type
  end # cancelled_proposal?
  def rejected_proposal?
    noti_type = 4 if (new_deal_yn == 'Y' and !accepted_yn_was and accepted_yn == 'N')
    noti_type
  end # rejected_proposal?
  def accepted_proposal?
    noti_type = 5 if (new_deal_yn == 'Y' and !accepted_yn_was and accepted_yn == 'Y')
    noti_type
  end # accepted_proposal?
  def deleted_comment?
    !deleted_at_was and deleted_at # deleted mark comment
  end # deleted_comment?

  def get_noti_key_prefix (noti_key_1, noti_key_2, noti_key_3)
    NOTI_KEY_1[noti_key_1] + '_' + NOTI_KEY_2[noti_key_2] + NOTI_KEY_3[noti_key_3]
  end # get_noti_key_prefix

  def init_noti_key_regexp (noti_key_1, noti_key_2, noti_key_3)
    noti_key_prefix = get_noti_key_prefix(noti_key_1, noti_key_2, noti_key_3)
    Regexp.new "^#{noti_key_prefix}_(1|2|3|n)_v#{NOTI_KEY_4}$"
  end # init_noti_key_regexp



  # Note: nnn different translations. See inbox/index/gift_comment*
  # noti_key_1: 1:new comment, 2:new proposal, 3:cancelled proposal, 4:rejected proposal, 5:accepted proposal
  # noti_key_2: 1:giver, 2:receiver, 3: giver and receiver
  # noti_key_3: 1: notification to owner of gift and followers of gift, 2: notification to other users that has commented the gift, 3: notification to followers
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
    raise "invalid noti_key_3" if [true, false].index(noti_key_3)
    puts "send_notification: noti_key_1 = #{noti_key_1} (#{NOTI_KEY_1[noti_key_1]}), " +
             "noti_key_2 = #{noti_key_2} (#{NOTI_KEY_2[noti_key_2]}), " +
             "noti_key_3 = #{noti_key_3} (#{NOTI_KEY_3[noti_key_3]}), " +
             "from_user = #{from_user.short_user_name}, " +
             "to_user = #{to_user.short_user_name}" if debug_notifications
    if [3,4].index(noti_key_1)
      puts "special handling of noti_key_1 = 3..5 ..." if debug_notifications
      # special handling of noti_type_1 = 3..5. noti_key_1 (noti_type):
      #   3 - cancelled proposal notification
      #       a) change unread new proposal notification to new_comment notification (remove+send+stop)
      #       b) read new proposal - send cancelled proposal notification to owner of gift - continue
      #       c) read new proposal - don't send any other notifications
      #   4 - rejected proposal
      #       a) change any unread new proposal notification to new comment notification (remove+send)
      #       b) send rejected proposal notification to owner of new proposal / comment
      #       c) don't send any other notifications
      #   5 - accepted proposal
      #       a) unread - change unread new proposal notification to accepted proposal notification (remove)
      #       b) read - send accepted proposal notification

      # puts "comment id #{id} used in unread notifications " + notifications.where("noti_read = 'N'").collect { |n| "#{n.noti_key} to #{n.to_user.short_user_name}" }.join(', ')
      # comment id 3 used in
      #   a) unread notifications new_proposal_giver_3_v1 to Charlie S,
      #   b) new_proposal_giver_other_2_v1 to Sandra Q,
      #   c) new_proposal_giver_other_1_v1 to Karen S
      # do not a) change new_proposal_giver_3_v1 to Charlie S
      # change b) new_proposal_giver_other_2_v1 to Sandra Q to a new_proposal_giver_other_1_v1 (u2/karen) and a new_comment_giver_other_1_v1 (u3/david)
      # change c) new_proposal_giver_other_1_v1 to Karen S to a new_comment_giver_other_1_v1 (u3/david)

      # find any new_proposal_other notifications for this comment. used in 3a, 4a and 5a
      regexp1 = init_noti_key_regexp(2, noti_key_2, 1) # notification to gift giver/receiver
      regexp2 = init_noti_key_regexp(2, noti_key_2, 2) # notification to other users
      regexp3 = init_noti_key_regexp(2, noti_key_2, 3) # notification to followers
      new_proposal_notifications = notifications.find_all { |n| ((noti_key_1 == 3 and regexp1.match(n.noti_key)) or regexp2.match(n.noti_key) or regexp3.match(n.noti_key)) }
      if new_proposal_notifications.size == 0
        puts "no new proposal notifications was found for comment id #{id}" if debug_notifications
      else
        puts "comment id #{id} used in new proposal notifications:" if debug_notifications
        0.upto(new_proposal_notifications.size-1) do |i|
          n = new_proposal_notifications[i]
          puts "#{i+1}: #{n.noti_read == 'N' ? 'un' : ''}read #{n.noti_key} to #{n.to_user.short_user_name}"
          puts "#{i+1}: from user #{n.from_user.short_user_name}" if n.from_user
        end if debug_notifications
      end

      stop = false
      0.upto(new_proposal_notifications.size-1) do |i|
        new_proposal_notification = new_proposal_notifications[i]
        if new_proposal_notification.noti_read == 'N'
          puts "#{i+1}: #{new_proposal_notification.noti_read == 'N' ? 'un' : ''}read #{new_proposal_notification.noti_key} to #{new_proposal_notification.to_user.short_user_name}" if debug_notifications
          # 3a, 4a, 5a - change unread new_proposal_other notification to new_comment notification
          puts "#{i+1}: case 3a, 4a, 5a - change unread new_proposal_other notification to new_comment notification" if debug_notifications
          # change or delete new_proposal_notification
          puts "#{i+1}: change or delete new_proposal_notification" if debug_notifications
          remove_from_notification(new_proposal_notification)
          # add new comment notification corresponding to changed/deleted new proposal notification
          puts "#{i+1}: add new comment notification corresponding to changed/deleted new proposal notification" if debug_notifications
          # initialize variables to be used in new comment notification that replaces removed new proposal notification
          puts "#(i+1}: initialize variables to be used in new comment notification that replaces removed new proposal notification" if debug_notifications
          tmp_noti_key_3 = case
                             when regexp1.match(new_proposal_notification.noti_key) then 1
                             when regexp2.match(new_proposal_notification.noti_key) then 2
                             when regexp3.match(new_proposal_notification.noti_key) then 3
                           end
          if noti_key_1 == 3
            # cancelled - from_user = comment.user - ok
            tmp_from_user = from_user
          else
            # rejected/accepted - use from_user from new_proposal_notification
            tmp_from_user = new_proposal_notification.from_user || user
          end
          tmp_to_user = new_proposal_notification.to_user
          puts "#{i+1}: noti_key_3 = #{noti_key_3}, tmp_noti_key_3 = #{tmp_noti_key_3}" if debug_notifications
          puts "#{i+1}: from_user = #{from_user.short_user_name}, tmp_from_user = #{tmp_from_user ? tmp_from_user.short_user_name : nil}" if debug_notifications
          puts "#{i+1}: to_user = #{to_user.short_user_name}, tmp_to_user = #{tmp_to_user.short_user_name}" if debug_notifications
          send_notification(1, noti_key_2, tmp_noti_key_3, tmp_from_user, tmp_to_user)
          puts "#{i+1}: stop check: noti_key_1 = #{noti_key_1}, new_proposal_notification.noti_key = #{new_proposal_notification.noti_key}" if debug_notifications
          if [3,4].index(noti_key_1) and regexp1.match(new_proposal_notification.noti_key)
            puts "#{i+1}: signal stop" if debug_notifications
            stop = true
          end
        else
          # 3b, 3c, 4b, 4c, 5b - don't change read new proposal notification
          puts "#{i+1}: 3b, 3c, 4b, 4c, 5b - don't change read new proposal notification" if debug_notifications
        end
      end # each new_proposal_notification
      if stop
        puts "stopped" if debug_notifications
        return
      end

      #regexp = init_noti_key_regexp(2, noti_key_2, noti_key_3)
      #puts "regexp = #{regexp}, comment.id = #{id}, to_userid = #{to_user.user_id} (#{to_user.short_user_name})"
      #new_proposal_notifications = notifications.where("to_user_id = ? and noti_read = 'N'", to_user.user_id).find_all { |n| regexp.match(n.noti_key)}
      #puts "new_proposal_notifications.size = #{new_proposal_notifications.size}"
      #new_proposal_notification = new_proposal_notifications.first
      #puts new_proposal_notification
      #if new_proposal_notification
      #  # 3a, 4a or 5a
      #  remove_from_notification(new_proposal_notification)
      #  if [3,4].index(noti_key_1)
      #    # 3a or 4a
      #    puts "Comment.send_notification: case #{noti_key_1}a"
      #    puts "new_proposal.from_user.short_user_name = #{new_proposal_notification.from_user.short_user_name}" if new_proposal_notification.from_user
      #    puts "new_proposal.to_user.short_user_name = #{new_proposal_notification.to_user.short_user_name}"
      #    puts "from_user.short_user_name = #{from_user.short_user_name}"
      #    puts "to_user.short_user_name = #{to_user.short_user_name}"
      #    puts "todo: can not use from_user in case 4a. is invalid for 4a"
      #    if noti_key_1 == 3
      #      # cancelled - from_user = comment.user - ok
      #      send_notification(1, noti_key_2, noti_key_3, from_user, to_user) # new comment notification
      #    else
      #      send_notification(1, noti_key_2, noti_key_3, new_proposal_notification.from_user, to_user) # new comment notification
      #    end
      #    return
      #  end
      #  # 5a => 5b
      #else
      #  # 3b, 3c, 4b, 4c, 5b
      #  return if noti_key_1 == 3 and ![gift.user_id_giver, gift.user_id_receiver].index(to_user.user_id) # 3c
      #  return if noti_key_1 == 4 and user_id != to_user.user_id # 4c
      #  # 3b, 4b, 5b
      #end

    end # if [3,4,5].index(noti_key_1)

    noti_key_prefix = get_noti_key_prefix(noti_key_1, noti_key_2, noti_key_3)
    regexp = init_noti_key_regexp(noti_key_1, noti_key_2, noti_key_3)
    # puts "regexp = #{regexp}"
    match = nil
    n = Notification.where("to_user_id = ? and noti_read = 'N'", to_user.user_id)
    .find { |n| n.noti_options[:giftid] == gift.id and match = regexp.match(n.noti_key) }
    if !n
      # first unread comment for this gift
      puts "first unread comment for this gift" if debug_notifications
      n = Notification.new
      n.to_user_id = to_user.user_id
      n.from_user_id = from_user.user_id # set to nil if no_users > 1
      n.internal = 'Y'
      n.noti_key = "#{noti_key_prefix}_1_v#{NOTI_KEY_4}" # no_users = 1
      if %w(giver both).index(gift.direction)
        givername = gift.api_gifts.shuffle.first.giver.short_user_name
      end
      if %w(receiver both).index(gift.direction)
        receivername = gift.api_gifts.shuffle.first.receiver.short_user_name
      end
      noti_options = {:giftid => gift.id, :gifttext => gift.description.first(30),
                      :no_users => 0, :no_other_users => -2,
                      :username1 => nil,
                      :username2 => nil,
                      :username3 => nil,
                      :givername => givername, # (gift.user_id_giver ? gift.giver.short_user_name : ""),
                      :receivername => receivername} # (gift.user_id_receiver ? gift.receiver.short_user_name : "")}
      puts "noti_key_1 = #{noti_key_1}, noti_key_3 = #{noti_key_3}" if debug_notifications
      if [1,2,3].index(noti_key_1) or noti_key_3 == 2
        # user array not used for rejected and accepted notification to owner of comment
        noti_options[:username1] = from_user.short_user_name
        noti_options[:no_users] += 1
        noti_options[:no_other_users] += 1
      end
      if [4, 5].index(noti_key_1)
        # names of giver/receiver are used in reject/accept notifications
        # noti_type_1 = 5: giver/receiver is added to gift after the notifications are sent
        puts "before: givername = #{noti_options[:givername]}, receivername = #{noti_options[:receivername]}" if debug_notifications
        noti_options[:givername] = user.short_user_name if noti_options[:givername] == ""
        noti_options[:receivername] = user.short_user_name if noti_options[:receivername] == ""
        puts "after: givername = #{noti_options[:givername]}, receivername = #{noti_options[:receivername]}" if debug_notifications
      end
      n.noti_options = noti_options
      n.noti_read = 'N'
    elsif [4,5].index(noti_key_1) and noti_key_3 == 2
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
      if n.from_user_id
        puts "clear from_userid (#{n.from_user.short_user_name}) for notification #{n.id}. todo: Can cause problems for rule 4a" if debug_notifications
        n.from_user_id = nil # set to nil (no_users > 1)
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
    ac.comment_id = comment_id
    ac.save!
    # add row to CommentNotification / keep track of number of users in notification message
    puts "add CommentNotification for comment id #{id} and notification id #{n.id} #{n.noti_key}" if debug_notifications
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
    puts "remove_from_notification. comment id #{id}. Notification id #{n.id}. notification key #{n.noti_key}" if debug_notifications
    # only modify unread notifications
    return unless n.noti_read == 'N'
    cn = notifications.where("notification_id = ?", n.id).first
    puts "cn.class = #{cn.class}" if debug_notifications
    puts "cn.id = #{cn.id}" if cn and debug_notifications
    puts "cn.noti_key = #{cn.noti_key}" if cn and debug_notifications
    puts "cn.from_user.short_user_name = #{cn.from_user.short_user_name}" if cn and cn.from_user and debug_notifications
    puts "cn.to_user.short_user_name = #{cn.to_user.short_user_name}" if cn and cn.to_user and debug_notifications
    # find no users before and after removing this comment from notification
    old_no_users = n.comments.collect { |c| c.user_id }.uniq.size
    new_users = n.comments.find_all { |c| c.id != id }.collect { |c| c.user }.uniq
    new_no_users = new_users.size
    if new_no_users == 0
      # last user for this unread notification has been removed
      puts "last user for this unread notification has been removed" if debug_notifications
      n.destroy!
      return
    end
    return if old_no_users == new_no_users # unchanged number of users => unchanged notification
    if new_no_users > 3
      # unchanged noti_key and username array. Just change number of users
      puts "unchanged noti_key and username array. Just change number of users" if debug_notifications
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
    puts "change noti_key, username array and number of users" if debug_notifications
    noti_key_prefix, noti_key_no_users, noti_key_version = $1, $2, $3
    noti_options = n.noti_options
    (1..3).each { |i| noti_options["username#{i}".to_sym] = nil }
    usernames = new_users.collect { |u| u.short_user_name }
    0.upto(usernames.size-1).each do |i|
      noti_options["username#{i+1}".to_sym] = usernames[i]
    end
    noti_options[:no_users] = new_no_users
    noti_options[:no_other_users] = new_no_users - 2
    n.noti_key = "#{noti_key_prefix}_#{new_no_users}_v#{noti_key_version}"
    puts "noti_key: old = #{n.noti_key_was}, new = #{n.noti_key}" if debug_notifications
    n.noti_options = noti_options
    notifications.delete(cn) if cn
    n.save!
  end # remove_from_notification


  def before_create
    self.status_update_at = Sequence.next_status_update_at
  end
  def before_update
    # puts "Comment.before_update"
    # puts "Comment.before_update: price = #{price} (#{price.class})"
    # puts "Comment.before_update: currency = #{currency} (#{currency.class})"
    self.status_update_at = Sequence.next_status_update_at if accepted_proposal? or rejected_proposal? or cancelled_proposal?
    if deleted_comment?
      # delete marked comment - will be removed from gift/index pages within the next 5 minutes
      self.status_update_at = Sequence.next_status_update_at
      puts "cleanup any unread notifications" if debug_notifications
      # change number of users for uny unread notifications
      notifications.find_all { |n| n.noti_read == 'N' }.each do |n|
        remove_from_notification(n)
      end # each n
    end # if
  end # before_update

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
      # called from after_update callback
      case
        when accepted_proposal?
          noti_key_1 = 5 # accepted
          from_userid = gift.user_id_giver || gift.user_id_receiver
        when rejected_proposal?
          noti_key_1 = 4 # rejected
          from_userid = gift.user_id_giver || gift.user_id_receiver
        when cancelled_proposal?
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
      when gift.direction == 'both' then
        noti_key_2 = 3
      when gift.direction == 'giver' then
        noti_key_2 = 1
      when gift.direction == 'receiver' then
        noti_key_2 = 2
      else
        raise "system error: gift without giver or receiver"
    end
    puts "noti_key_1 = #{noti_key_1}, noti_key_2 = #{noti_key_2}"
    noti_key_prefix = NOTI_KEY_1[noti_key_1] + '_' + NOTI_KEY_2[noti_key_2]
    puts "noti_key_prefix = #{noti_key_prefix}" if debug_notifications
    # initialise helpers - arrays with giver user_id's, receiver user_id's and both
    gift_givers = gift.api_gifts.collect { |api_gift| api_gift.user_id_giver }.find_all { |user_id2| user_id2 }
    gift_receivers = gift.api_gifts.collect { |api_gift| api_gift.user_id_receiver }.find_all { |user_id2| user_id2 }
    gifts_giver_and_receivers = gift_givers + gift_receivers
    # send notifications
    case
      when [1,2,5].index(noti_key_1)
        # new comment, new proposal and accepted proposal
        # 1) notifications to giver and/or receiver
        #    do not send notification to giver if user is in api_gifts.giver
        #    do not send notification to receiver if user is in api_gifts.receiver
        puts "send notifications to gifts giver and/or receiver" if debug_notifications
        users1 = []
        # old: users1.push(gift.giver) if gift.user_id_giver and from_userid != gift.user_id_giver
        if %w(giver both).index(gift.direction) and !gift_givers.index(from_userid)
          users1 += User.where('user_id in (?)', gift_givers) if gift_givers.size > 0
        end
        # old: users1.push(gift.receiver) if gift.user_id_receiver and from_userid != gift.user_id_receiver
        if %w(receiver both).index(gift.direction) and !gift_receivers.index(from_userid)
          users1 += User.where("user_id in (?)", gift_receivers) if gift_receivers.size > 0
        end
        if noti_key_1 == 5
          # special rejected/accepted notification to owner of comment
          to_user_id = user_id
          users1.push(user)
        end
        users1_ids = users1.collect { |u| u.user_id }
        puts "1: users1 = " + users1_ids.join(', ') if debug_notifications
        # 2) notifications to users that has commented the gift - "_other" is added to notification key!
        # users2 = gift.comments.includes(:user).collect { |c| c.user }.find_all { |user2| ![from_userid, to_user_id, gift.user_id_giver, gift.user_id_receiver].index(user2.user_id) }.uniq
        exclude_user_ids = [from_userid, to_user_id] + gifts_giver_and_receivers
        users2 = gift.comments.includes(:user).collect { |c| c.user }.find_all { |user2| !exclude_user_ids.index(user2.user_id) }.uniq
        users2_ids = users2.collect { |u| u.user_id }
        users_ids = (users1_ids + users2_ids).uniq
        puts "2: users2 = " + users2_ids.join(', ') if debug_notifications
        # 3) check followers - users that have selected to follow gift comments - users that have selected NOT to follow gift comments
        users3 = []
        puts "3: adding/removing followers" if debug_notifications
        GiftLike.where("gift_id = ? and follow is not null", gift.gift_id).each do |gl|
          next if
          if gl.follow == 'Y'
            # user has selected to follow gift
            users3 << gl.user if gl.user.user_id != from_userid and !users_ids.index(gl.user_id)
          else
            # user has deselected to follow gift
            users1 = users1.delete_if { |u| u.user_id == gl.user_id }
            users2 = users2.delete_if { |u| u.user_id == gl.user_id }
          end
        end # each
        #puts "3: users1 = " + users1_ids.join(', ') if debug_notifications
        #puts "3: users2 = " + users2_ids.join(', ') if debug_notifications
        #puts "3: users3 = " + users3_ids.join(', ') if debug_notifications
        # send notifications
        puts "start: send notifications to gifts giver and receiver: " + users1.collect { |u| u.short_user_name }.join(', ') if debug_notifications
        users1.each { |to_user| send_notification(noti_key_1, noti_key_2, 1, from_user, to_user) }
        puts "end: send notifications to gifts giver, receiver and followers: " + users1.collect { |u| u.short_user_name }.join(', ') if debug_notifications
        puts "start: send notifications to other users that also have commented the gift: " + users2.collect { |u| u.short_user_name }.join(', ') if debug_notifications
        users2.each { |to_user| send_notification(noti_key_1, noti_key_2, 2, from_user, to_user) }
        puts "end: send notifications to other users that also have commented the gift: " + users2.collect { |u| u.short_user_name }.join(', ') if debug_notifications
        puts "start: send notifications to users that follows the gift: " + users3.collect { |u| u.short_user_name }.join(', ') if debug_notifications
        users3.each { |to_user| send_notification(noti_key_1, noti_key_2, 3, from_user, to_user) }
        puts "end: send notifications to users that follows the gift: " + users3.collect { |u| u.short_user_name }.join(', ') if debug_notifications

        # new comment and new proposal - add user as follower of gift - user will receive notifications until user stops following the gift
        if noti_key_1 <= 2 and !gifts_giver_and_receivers.index(user_id)
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
          if gl.new_record? or gl.changed?
            puts "added #{user.short_user_name} as follower" if debug_notifications
            gl.save!
          end
        end
      when noti_key_1 == 3
        # cancelled proposal - send only notification to giver/receiver
        users1 = []
        users1.push(gift.giver) if gift.user_id_giver and from_userid != gift.user_id_giver
        users1.push(gift.receiver) if gift.user_id_receiver and from_userid != gift.user_id_receiver
        users1.each { |to_user| send_notification(noti_key_1, noti_key_2, 1, from_user, to_user) }
      when [4].index(noti_key_1)
        # rejected/accepted proposal - send notification to creator of proposal / comment
        users1 = []
        to_user_id = user_id
        users1.push(user)
        users1.each { |to_user| send_notification(noti_key_1, noti_key_2, 1, from_user, to_user) }
    end # case
  end # after_create

  def after_update
    puts "Comment.after_update:" if debug_notifications
    puts "Comment.after_update: new deal_yn: #{new_deal_yn_was} (#{new_deal_yn_was.class}) => #{new_deal_yn} (#{new_deal_yn.class})" if debug_notifications
    puts "Comment.after_update: accepted_jn: #{accepted_yn_was} (#{accepted_yn_was.class}) => #{accepted_yn} (#{accepted_yn.class})" if debug_notifications
    # puts "Comment.after_update: currency = #{currency}"
    # comment: after update: new deal: Y => Y, accepted:  => N
    # check for canceled, rejected or accepted deal proposal - notifications are sent from after_create method
    if  accepted_proposal? or # noti_type 5: accepted proposal
        rejected_proposal? or # noti type 4: rejected proposal
        cancelled_proposal? # noti type 3: cancelled proposal
      # send notifications
      after_create(true)
      if accepted_yn == 'Y'
        # accepted proposal - update gift (user, price, received_at etc)
        gift.reload
        if !gift.user_id_giver
          gift.user_id_giver = user_id
        else
          gift.user_id_receiver = user_id
        end
        if price
          gift.price = price
          gift.currency = currency
          # puts "Comment.after_update: gift.currency = #{gift.currency}"
        end
        gift.received_at = updated_at # todo: move to gift callback
        gift.status_update_at = Sequence.next_status_update_at  # todo: move to gift callback
        gift.save!
        # mark users for balance recalculation - ensures that balance is recalculated even if accept new deal post processing should fail for some reason
        [ gift.giver, gift.receiver].each do |u|
          u.reload
          u.balance_at = Date.yesterday
          u.save
        end # each
      end # if accepted
    end # if cancelled, rejected or accepted
  end # after_update

  #def before_destroy
  #  puts "cleanup any unread notifications" if debug_notifications
  #  # change number of users for uny unread notifications
  #  notifications.find_all { |n| n.noti_read == 'N' }.each do |n|
  #    remove_from_notification(n)
  #  end # each n
  #end # before_destroy


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

class InboxController < ApplicationController
  def index
    # get messages - new messages are shown first in page - max 20 notifications - no need for paginate or ajax expanding page
    @notifications = Notification.where("to_user_id = ?", @user.user_id).order("noti_read, created_at desc")
    for noti in @notifications do loop
      if noti.noti_read == 'N'
        noti.noti_read = 'Y'
        noti.save!
      end
    end
    # temporary workaround. remove notifications for delete or delete marked gifts.
    # todo: delete notifications when gift has been delete marked
    @notifications = @notifications.find_all do |noti|
      postfix = noti.to_user_id == @user.user_id ? 'to' : 'from'
      url = my_t ".#{noti.noti_key}_#{postfix}_url", noti.noti_options
      puts url
      if url =~ /^\/gifts\/([0-9]+)$/
        # gift/comment notification
        gift = Gift.find($1)
        # todo: delete notification for delete marked gift?
        gift and !gift.deleted_at
      else
        # other notifications
        true
      end
    end # find_all
  end # index

  def show
  end

  def destroy
  end

end

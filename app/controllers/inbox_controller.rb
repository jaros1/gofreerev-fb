class InboxController < ApplicationController
  def index
    # get messages - new messages are shown first in page
    @notifications = Notification.where("to_user_id = ? or from_user_id = ?", @user.user_id, @user.user_id).order("noti_read, created_at desc").paginate(:page => params[:page])
    # mark messages as read
    for noti in @notifications do loop
      if noti.to_user_id == @user.user_id and noti.noti_read == 'N'
        noti.noti_read = 'Y'
        noti.save!
      end
    end
  end # index

  def show
  end

  def destroy
  end

end

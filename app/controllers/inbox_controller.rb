class InboxController < ApplicationController
  def index
    @notifications = Notification.where("to_user_id = ?", @user.user_id).order("noti_read, created_at desc").paginate(:page => params[:page])

  end

  def show
  end

  def destroy
  end
end

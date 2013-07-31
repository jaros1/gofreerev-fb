class UtilController < ApplicationController

  # jquery update new message count in menu line once every minute
  def new_messages_count
    if @user
      count = @user.inbox_new_notifications
      @new_messages_count = count if count > 0
    end
    render :layout => false
  end

end

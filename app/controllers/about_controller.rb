class AboutController < ApplicationController

  def index
    @sections = %w(about betatest cookies privacy disclaimer )
  end

  # unsubscribe friend suggestion email from Gofreerev
  # params:
  #   noti_id: noti_id + password
  #   choice: 1-unsubscribe all, 2: unsubscribe for users
  def unsubscribe
    # email_id: noti_id and "password".
    noti_id_and_password = params[:email_id].to_s
    if noti_id_and_password.to_s == ''
      save_flash_key '.email_no_id'
      redirect_to :controller => :auth, :action => :index
      return
    end
    if noti_id_and_password.size != 40
      save_flash_key '.email_not_found'
      redirect_to :controller => :auth, :action => :index
      return
    end
    noti_id = noti_id_and_password.to_s.first(20)
    password = noti_id_and_password.last(20)
    n = Notification.find_by_noti_id(noti_id)
    noti_options = n.noti_options if n
    if !n or noti_options[:password] != password
      save_flash_key '.email_not_found'
      redirect_to :controller => :auth, :action => :index
      return
    end
    email = noti_options[:email].to_s
    us = Unsubscribe.where('email = ? and user_id is null', email).first
    if us
      # email already unsubscribed
      save_flash_key '.ok1'
      redirect_to :controller => :auth, :action => :index
      return
    end

    # choice 1: unsubscribe email
    choice = params[:choice].to_s
    choice = '1' unless %w(1 2).index(choice)
    if choice == '1'
      us = Unsubscribe.new
      us.email = email
      us.save!
      Unsubscribe.where('email = ? and user_id is not null', email).delete_all
      save_flash_key '.ok1'
      redirect_to :controller => :auth, :action => :index
      return
    end
    # choice 2: unsubscribe email for selected Gofreerev users
    login_user_ids = noti_options[:login_users].to_s.split(',')
    login_users = User.where(:user_id => login_user_ids)
    login_users.each do |login_user|
      us = Unsubscribe.where('email = ? and user_id = ?', email, login_user.user_id).first
      if !us
        us = Unsubscribe.new
        us.email = email
        us.user_id = login_user.user_id
        us.save!
      end
    end
    save_flash_key '.ok2'
    redirect_to :controller => :auth, :action => :index
  end

end

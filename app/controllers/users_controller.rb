class UsersController < ApplicationController

  before_filter :login_required

  def new
  end

  def create
  end

  def update
    if params[:id] != @user.id.to_s
      puts "invalid id. params[:id] = #{params[:id]}, @user.id = #{@user.id}"
      flash[:notice] = my_t '.invalid_request'
      if params[:return_to].to_s != ''
        redirect_to params[:return_to]
      else
        redirect_to '/users'
      end
      return
    end

    if params[:return_to].to_s != ''
      # update user called from other controllers.
      # change currency in page header, friend actions in users/show page etc
      if params[:user] and params[:user][:new_currency].to_s != ''
        # currency updated in page header - update currency and return to actual page
        update_user_currency
        return
      end
      if params[:friend_id] and params[:friend_action]
        # friend actions from user/show page - add/remove api/app friend - see full list in user.friend_status_actions
        friend_actions
        return
      end
      # invalid call or update action not implemented
      raise "invalid call / not implemented"
    end

    puts 'not implemented 1'
  end

  def edit
  end

  def destroy
  end

  def index
    # friends filter: true: show friends, false: show not friends (*), nil: show all users (')
    # * = only show friends of friends - not all Gofreerev users
    friends_filter = params[:friends]
    friends_filter = case friends_filter
                        when nil then nil
                        when "" then nil
                        when "true" then true
                        when "false" then false
                        else true
                     end # case
    # http request: return first 10 friends (last_user_id = nil) 
    # ajax request: return next 10 friends (last_user_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end

    # always use users friends as basic (friends_filter = true)
    user_friends = @user.friends.includes(:friend).find_all do |f|
      f.friend.friend?(@user)
    end.sort do |a,b|
      if a.friend.user_name <=> b.friend.user_name
        a.friend.id <=> b.friend.id
      else
        a.friend.user_name <=> b.friend.user_name
      end
    end
    puts "friends_filter = #{friends_filter}, found #{user_friends.size} friends"

    if friends_filter == true
      # simpel friends search - just return login users friends
      users = user_friends.collect { |f| f.friend }
      @users, @last_user_id = get_next_set_of_rows(users, last_row_id)
      respond_to do |format|
        format.html {}
        # format.json { render json: @comment, status: :created, location: @comment }
        format.js {}
      end
      return
    end # friends_filter == true

    # friends_filter = nil (all users) or false (only non friends)

    # find all friends of friends
    friends_userids = user_friends.collect { |f| f.user_id_receiver }
    friends_userids.delete(@user.user_id)
    puts "friends_userids = " + friends_userids.join(', ')
    friends = User.where("user_id in (?)", friends_userids).includes(:friends)
    puts "friends = " + friends.collect { |u| u.short_user_name }.join(', ')
    friends_friends_userids = []
    friends.each do |u|
      friends_friends_userids = (friends_friends_userids + u.friends.collect { |f| f.user_id_receiver }).uniq
    end # each u
    friends_friends_userids.delete(@user.user_id)

    # find relevant users and number of mutual friends
    users = []
    User.where("user_id in (?)", friends_friends_userids).each do |user|
      next if friends_filter == false and user.friend?(@user) # don't show friends
      users << user
    end # each user

    # sort: number of mutual friends desc, user name, user id
    users = users.sort do |a, b|
      if a.mutual_friends(@user).size != b.mutual_friends(@user).size
        b.mutual_friends(@user).size <=> a.mutual_friends(@user).size
      elsif a.user_name != b.user_name
        a.user_name <=> b.user_name
      else
        a.id <=> b.id
      end
    end # sort

    # users = User.all # uncomment to test ajax

    # return next 10 gofreerev users
    @users, @last_row_id = get_next_set_of_rows(users, last_row_id)

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # index

  def show
    id = params[:id]
    @user2 = User.find(id)
    if !@user2
      puts "invalid request. User with id #{id} was not found"
      flash[:notice] = my_t '.invalid_request'
      redirect_to :action => :index
      return
    end
    return unless @user2.friend?(@user)

    # friend - user balance information

    # http request: return first 10 gifts (last_gift_id = nil)
    # ajax request: return next 10 gifts (last_gift_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end

    gifts = Gift.where('user_id_giver = ? or user_id_receiver = ?', @user.user_id, @user.user_id).includes(:giver, :receiver).sort do |a,b|
      if (a.received_at || a.created_at.to_date) ==  (b.received_at || b.created_at.to_date)
        b.id <=> a.id
      else
        (b.received_at || b.created_at.to_date) <=>  (a.received_at || a.created_at.to_date)
      end # if
    end # sort

    # return next 10 gifts - first 10 for http request - next 10 for ajax request
    @gifts, @last_row_id = get_next_set_of_rows(gifts, last_row_id)

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # show


  private
  def update_user_currency
    # currency updated in page header - update currency and return to actual page
    old_currency = @user.currency
    new_currency = params[:user][:new_currency]
    if old_currency == new_currency
      # no change
      redirect_to params[:return_to]
      return
    end

    # recalculate balance in new currency
    # currency and balance is not recalculated if exchange rates are missing
    puts "gifts/update: new_currency = #{new_currency}"
    if !@user.recalculate_balance(new_currency)
      # not all exchange rates was ready yet - keep old balance and currency
      # puts "not all exchange rates was ready yet - keep old balance and currency"
      # flash[:notice] = t '.exchange_rates_not_ready'
      flash[:notice] = t '.exchange_rates_not_ready'
      redirect_to params[:return_to]
      return
    end

    # ok - all needed exchange rates was available - currency and balance was updated
    # puts "ok - all needed exchange rates was available - currency and balance was updated"
    # puts "currency = #{@user.currency}, balance = #{@user.balance}"
    # @user.save!

    redirect_to params[:return_to]
  end  # update_user_currency


  # do friend actions (add/remove api/app friend etc)
  # see users.friend_status_actions for full list
  def friend_actions
    id2 = params[:friend_id]
    user2 = User.find(id2)
    if !user2
      puts "invalid request. Friend with id #{id2} was not found"
      flash[:notice] = my_t '.invalid_request'
      redirect_to params[:return_to]
      return
    end
    friend_action = params[:friend_action]
    allowed_friend_actions = user2.friend_status_actions(@user).collect { |fa| fa.downcase }
    if !allowed_friend_actions.index(friend_action)
      puts "invalid request. Friend action #{friend_action} not allowed."
      puts "allowed friend actions are " + allowed_friend_actions.join(', ')
      redirect_to params[:return_to]
      return
    end

    # friend actions: add_api_friend, remove_api_friend, send_app_friend_request, accept_app_friend_request, ignore_app_friend_request, remove_app_friend, block_app_user, unblock_app_user

    if %w(add_api_friend remove_api_friend).index(friend_action)
      # api friend actions
      # no facebook api dialogs to add and remove facebook friends - just redirect to users profile page at facebook
      redirect_to user2.api_profile_url
      return
    end

    # do app friend action
    # for example send_app_friend_request with ok response send_app_friend_request_ok and error response send_app_friend_request_error
    postfix = user2.send(friend_action, @user) ? "_ok" : "_error"
    flash[:notice] = my_t ".#{friend_action}#{postfix}", :appname => APP_NAME, :username => user2.short_user_name
    redirect_to params[:return_to]
  end # friend_actions


end

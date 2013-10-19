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
    # return first 10 friends (last_user_id = nil).
    # return next 10 friends (last_user_id != nil)
    last_user_id = params[:last_user_id].to_s
    last_user_id = nil if last_user_id == ''
    last_user_id = nil unless last_user_id =~ /^[0-9]+$/

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
      # simpel friends search - return user friends
      if last_user_id
        # ajax request - return next 10 friends
        from = user_friends.index { |f| f.friend.id == last_user_id }
        last_user_id = nil unless from # invalid last_user_id - or user is no longer a friend - ignore error and return first 10 friends
      end
      if !last_user_id
        # first http get - return first 10 friends
        user_friends = user_friends.first(10)
      else
        # ajax request - return next 10 friends
        user_friends = user_friends[from+1..-1]
        if user_friends.size > 10
          user_friends = user_friends.first(10)
          @last_user_id = user_friends.last.friend.id
        else
          @last_user_id = nil
        end
      end
      @friends = user_friends.collect { |f| f.friend }
      # simpel friends search - return user friends
      return
    end # friends_filter == true

    raise "todo: not implemented"

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
    @friend = @user2.friend?(@user)
    if @friend
      # todo: find user gifts (giver or receiver)
    end


  end # show_friend


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

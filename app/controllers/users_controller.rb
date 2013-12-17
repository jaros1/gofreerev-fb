class UsersController < ApplicationController

  before_filter :login_required
  before_filter :clear_state

  def new
  end

  def create
  end

  def update
    if !@users.find { |user| params[:id] == user.id.to_s}
      puts "invalid id. params[:id] = #{params[:id]}"
      flash[:notice] = t '.invalid_request'
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

    raise 'not implemented 1'
  end

  def edit
  end

  def destroy
  end

  def index
    # friends filter: true: show friends, false: show not friends (*), nil: show all users (')
    # * = only show friends of friends - not all Gofreerev users
    @friends_filter = params[:friends]
    @friends_filter = case @friends_filter
                        when nil then nil
                        when "" then nil
                        when "true" then true
                        when "false" then false
                        else true
                     end # case
    # http request: return first 10 friends (last_row_id = nil)
    # ajax request: return next 10 friends (last_row_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end
    # puts "last_row_id = #{last_row_id}"
    if last_row_id and get_next_set_of_rows_error?(last_row_id)
      # problem with ajax request.
      # can be invalid last_row_id - can be too many get-more-rows ajax requests - max one request every 3 seconds - more info in log
      # return "empty" ajax response with dummy row with correct last_row_id to client
      puts "return empty ajax response with dummy row with correct last_row_id to client"
      @gifts = @users = []
      @last_row_id = session[:last_row_id]
      respond_to do |format|
        format.js {}
      end
      return
    end

    # always use users friends as basic (friends_filter = true)
    # todo: remove friend doubles - that is friends with same friend.user_combination?
    # todo: but they maybe friend in one login provider and not friends for an other login provider
    user_friends = Friend.where("user_id_giver in (?)", login_user_ids).includes(:friend).find_all do |f|
      f.friend.friend?(@users)
    end.sort do |a,b|
      if a.friend.user_name <=> b.friend.user_name
        a.friend.id <=> b.friend.id
      else
        a.friend.user_name <=> b.friend.user_name
      end
    end
    # puts "friends_filter = #{@friends_filter}, found #{user_friends.size} friends"

    if @friends_filter == true
      # simple friends search - just return login users friends
      users = user_friends.collect { |f| f.friend }
    else
      # friends_filter = nil (all users) or false (only non friends)
      # find friends of friends
      friends_userids = user_friends.collect { |f| f.user_id_receiver }
      friends_userids.delete_if { |user_id| login_user_ids.index(user_id) }
      # puts "friends_userids = " + friends_userids.join(', ')
      friends = User.where("user_id in (?)", friends_userids).includes(:friends)
      # puts "friends = " + friends.collect { |u| u.short_user_name }.join(', ')
      friends_friends_userids = friends_userids
      friends.each do |u|
        friends_friends_userids = (friends_friends_userids + u.friends.collect { |f| f.user_id_receiver }).uniq
      end # each u
      friends_friends_userids.delete_if { |user_id| login_user_ids.index(user_id) }
      # find relevant users
      users = []
      User.where("user_id in (?)", friends_friends_userids).each do |user|
        next if @friends_filter == false and User.friend?(@users) # don't show friends
        users << user
      end # each user
      # puts "users.size = #{users.size}"
      # sort: number of mutual friends desc, user name ascending, id ascending
      users = users.sort do |a, b|
        if a.mutual_friends(@users).size != b.mutual_friends(@users).size
          b.mutual_friends(@users).size <=> a.mutual_friends(@users).size
        elsif a.user_name != b.user_name
          a.user_name <=> b.user_name
        else
          a.id <=> b.id
        end
      end # sort
      # friends_filter = nil (all users) or false (only non friends)
    end # friends_filter == true

    # use this users select for ajax test - returns all users
    # users = User.all # uncomment to test ajax

    # return next 10 users
    @users, @last_row_id = get_next_set_of_rows(users, last_row_id)

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # index

  # show user information, user friends and user balance (balance is only shown for friends)
  def show
    # check user.id
    id = params[:id]
    @user2 = User.find_by_id(id)
    if !@user2
      puts "invalid request. User with id #{id} was not found"
      flash[:notice] = t '.invalid_request'
      redirect_to :action => :index
      return
    end
    if @user2.mutual_friends(@users).size == 0
      puts "invalid request. No mutual friends for user with id #{id}"
      flash[:notice] = t '.invalid_request'
      redirect_to :action => :index
      return
    end
    puts "@user2 = #{@user2.id} #{@user2.user_name}"

    # recalculate balance once every day
    # todo: should only recalculate user balance from @user2.balance_at and to today
    if @user2.balance_at.to_yyyymmdd != Sequence.get_last_exchange_rate_date
      @user2.recalculate_balance
      @user2.reload
      @users = @users.collect { |user| user.user_id == @user2.user_id ? user.reload : user }
    end

    # get params: tab, last_row_id and todo: filters

    # tab: blank = friends or balance - only friends can see balance
    if @user2.friend?(@users)
      if @users.find { |user| user.user_id == @user2.user_id }
        tabs = %w(gifts balance) # my account - friends information available in Friends menu
      else
        tabs = %w(friends gifts balance) # friend - friend and balance information are allowed
      end
    else
      tabs = [] # non friend - do not display any information (friends, balance and gifts information not allowed)
    end
    if tabs.size <= 1
      tab = tabs.first
    else
      tab = params[:tab].to_s || tabs.first
      tab = tabs.first unless tabs.index(tab)
    end
    puts "tab = #{tab}"

    # http request: return first 10 gifts (last_row_id = nil)
    # ajax request: return next 10 gifts (last_row_id != nil)
    last_row_id = params[:last_row_id].to_s
    last_row_id = nil if last_row_id == ''
    if last_row_id =~ /^[0-9]+$/
      last_row_id = last_row_id.to_i
    else
      last_row_id = nil
    end
    if last_row_id and get_next_set_of_rows_error?(last_row_id)
      # problem with ajax request.
      # can be invalid last_row_id - can be too many get-more-rows ajax requests - max one request every 3 seconds - more info in log
      # return "empty" ajax response with dummy row with correct last_row_id to client
      puts "return empty ajax response with dummy row with correct last_row_id to client"
      @page_values = {:tab => tab }
      @gifts = @users = []
      @last_row_id = session[:last_row_id]
      respond_to do |format|
        format.js {}
      end
      return
    end

    if %w(gifts balance)
      # show balance for @user2 - only friends can see balance information
      # show gifts for @user2 - only friends can see gifts for @user2

      # get any pictures with invalid picture urls
      # that is gifts where picture url are marked as invalid and where url lookup in /util/missing_api_picture_urls failed
      # most possible explanation is that the pictures has been deleted in api
      # but is could also be a api permission problem (gofreerev user is not allowed to see picture in api)
      # check picture url again with owner permission
      # the existing /util/missing_api_picture_urls is used to check invalid picture urls
      # done in a client js call after the page has been rendered to the user
      # see last lines in /gifts/index page
      # see onLoad tag on img
      # see js functions check_api_picture_url and report_missing_api_picture_urls
      @missing_api_picture_urls = get_missing_api_picture_urls()

      # filters: status (open, closed and all) and direction (giver, receiver and both)
      statuses = %w(open closed all)
      status = params[:status] || 'all'
      status = 'all' unless %w(open closed all).index(status)
      directions = %w(giver receiver both)
      direction = params[:direction] || 'both'
      direction = 'both' unless %w(giver receiver both).index(direction)
      puts "balance filters: status = #{status}, direction = #{direction}"

      # initialize array with user navigation links. 0-3 sections with links. Up to 9 links.
      @user_nav_links = []
      @user_nav_links << ["tabs", tabs] if tabs.size > 1
      if %w(gifts balance).index(tab)
        @user_nav_links << ["deal_status", statuses]
        @user_nav_links << ["deal_direction", directions]
      end
      @page_values = {:tab => tab, :status => status, :direction => direction}

      # find gifts with @user2 as giver or receiver
      gifts = Gift.where('(user_id_giver = ? or user_id_receiver = ?)', @user2.user_id, @user2.user_id).includes(:giver, :receiver).find_all do |g|
        # apply status and direction filters
        ((status == 'all' or (status == 'open' and !g.received_at) or (status == 'closed' and g.received_at)) and
            (direction == 'both' or (direction == 'giver' and g.user_id_giver == @user2.user_id) or (direction == 'receiver' and g.user_id_receiver == @user2.user_id)))
      end.sort do |a, b|
        if (a.received_at || a.created_at) == (b.received_at || b.created_at)
          b.id <=> a.id
        else
          (b.received_at || b.created_at) <=> (a.received_at || a.created_at)
        end # if
      end # sort
      # return next 10 gifts - first 10 for http request - next 10 for ajax request
      @gifts, @last_row_id = get_next_set_of_rows(gifts, last_row_id)
      puts "@gifts.size = #{@gifts.size}, @last_row_id = #{@last_row_id}" if debug_ajax?
    end

    if tab == 'friends'
      # show friends for @user2 - sort by user_name
      users = @user2.app_friends.collect { |f| f.friend }.sort { |a,b| a.user_name <=> b.user_name}
      # users = User.all # uncomment to test ajax
      # return next 10 users - first 10 for http request - next 10 for ajax request
      @users, @last_row_id = get_next_set_of_rows(users, last_row_id)
      puts "@users.size = #{@users.size}, @last_row_id = #{@last_row_id}" if debug_ajax?
    end # friends

    if tab == 'gifts'
      # show 4 last comments for each gift
      @first_comment_id = nil
    end # gifts

    respond_to do |format|
      format.html {}
      # format.json { render json: @comment, status: :created, location: @comment }
      format.js {}
    end

  end # show


  private
  def update_user_currency
    # currency updated in page header - update currency and return to actual page
    old_currency = @users.first.currency
    new_currency = params[:user][:new_currency]
    if old_currency == new_currency
      # no change
      redirect_to params[:return_to]
      return
    end

    # check currency - exchange rate most exists
    today = Sequence.get_last_exchange_rate_date
    er = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', today, BASE_CURRENCY, new_currency).first
    if !er
      flash[:notice] = t '.invalid_currency' # todo: add key - test error message
      redirect_to params[:return_to]
      return
    end

    # find all users to change currency for
    users = @users
    user_combinations = users.collect { |user| user.user_combination }.find_all { |user_combination| user_combination }.uniq
    if user_combinations.length > 0
      users = users + User.where('user_combination in (?)', user_combinations)
      users = users.uniq
    end

    # update currency
    users.each do |user|
      user.update_attribute :currency, new_currency
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
    user2 = User.find_by_id(id2)
    if !user2
      puts "invalid request. Friend with id #{id2} was not found"
      flash[:notice] = t '.invalid_request'
      redirect_to params[:return_to]
      return
    end
    login_user = @users.find { |user| user.provider == user2.provider }
    friend_action = params[:friend_action]
    allowed_friend_actions = user2.friend_status_actions(login_user).collect { |fa| fa.downcase }
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
    postfix = user2.send(friend_action, login_user) ? "_ok" : "_error"
    flash[:notice] = t ".#{friend_action}#{postfix}", :appname => APP_NAME, :username => user2.short_user_name
    redirect_to params[:return_to]
  end # friend_actions


end

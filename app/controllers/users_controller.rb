class UsersController < ApplicationController

  before_filter :login_required
  before_filter :clear_state

  def new
  end

  def create
  end

  def update
    if !@users.find { |user| params[:id] == user.id.to_s}
      logger.debug2  "invalid id. params[:id] = #{params[:id]}"
      save_flash '.invalid_request'
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
    # logger.debug2  "last_row_id = #{last_row_id}"
    if last_row_id and get_next_set_of_rows_error?(last_row_id)
      # problem with ajax request.
      # can be invalid last_row_id - can be too many get-more-rows ajax requests - max one request every 3 seconds - more info in log
      # return "empty" ajax response with dummy row with correct last_row_id to client
      logger.debug2  "return empty ajax response with dummy row with correct last_row_id to client"
      @api_gifts = []
      @users2 = []
      @last_row_id = session[:last_row_id]
      respond_to do |format|
        format.js {}
      end
      return
    end

    # always use users friends as basic (friends_filter = true)
    # todo: remove friend doubles - that is friends with same friend.user_combination?
    # todo: but they maybe friend in one login provider and not friends for an other login provider
    #user_friends = User.app_friends(@users).sort do |a,b|
    #  if a.friend.user_name == b.friend.user_name
    #    a.friend.id <=> b.friend.id
    #  else
    #    a.friend.user_name <=> b.friend.user_name
    #  end
    #end
    # logger.debug2  "friends_filter = #{@friends_filter}, found #{user_friends.size} friends"

    if @friends_filter == true
      # simple friends search - just return login users friends
      logger.debug2 'simple friends search - just return login users friends'
      users2 = User.app_friends(@users).sort_by_user_name.collect { |f| f.friend }
      logger.debug2 "users2 = " + users2.collect { |u| u.user_id}.join(', ')
    else
      # all login users direct connections (friends and non friends)
      all_friends = User.all_friends(@users)
      all_friends_user_ids = all_friends.collect { |f| f.user_id_receiver }
      # find user friends
      user_friends = all_friends.find_all { |f| f.friend.friend?(@users)}
      # friends_filter = nil (all users) or false (only non friends)
      # find friends of friends
      friends_userids = user_friends.collect { |f| f.user_id_receiver }
      friends_userids.delete_if { |user_id| login_user_ids.index(user_id) }
      # logger.debug2  "friends_userids = " + friends_userids.join(', ')
      friends = User.where("user_id in (?)", friends_userids).includes(:friends)
      # logger.debug2  "friends = " + friends.collect { |u| u.short_user_name }.join(', ')
      friends_friends_userids = all_friends_user_ids
      friends.each do |u|
        friends_friends_userids = (friends_friends_userids + u.friends.collect { |f| f.user_id_receiver }).uniq
      end # each u
      friends_friends_userids.delete_if { |user_id| login_user_ids.index(user_id) }
      # find relevant users
      users2 = []
      # logger.debug2  "friends_friends_userids = #{friends_friends_userids.join(', ')}"
      User.where("user_id in (?)", friends_friends_userids).each do |user|
        friend = user.friend?(@users)
        # logger.debug2  "user = #{user.user_id}, friend = #{friend}"
        next if @friends_filter == false and friend # don't show friends
        users2 << user
      end # each user
      # logger.debug2  "users2.size = #{users2.size}"
      # sort: number of mutual friends desc, user name ascending, id ascending
      users2 = users2.sort do |a, b|
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
    @users2, @last_row_id = get_next_set_of_rows(users2, last_row_id)

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
      logger.debug2  "invalid request. User with id #{id} was not found"
      save_flash '.invalid_request'
      redirect_to :action => :index
      return
    end
    logger.debug2  "@user2 = #{@user2.id} #{@user2.user_name}"
    # check if login users are allowed to see @user2
    if !(login_user = @users.find { |u| u.provider == @user2.provider })
      logger.debug2 "invalid request. Not connected with a #{@user2.provider} account"
      save_flash '.invalid_request'
      redirect_to :action => :index
      return
    elsif login_user_ids.index(@user2.user_id)
      # ok - login user
    elsif Friend.where('user_id_giver = ? and user_id_receiver = ?',
                       login_user.user_id, @user2.user_id).
                 find { |f| f.api_friend == 'Y' }
      # ok - api friend but maybe not app friends
    elsif @user2.friend?(@users)
      # ok - friends
    else
      # not friend. Must have a mutual friend to allow user/show
      friends1 = User.app_friends([login_user]).collect { |f| f.user_id_receiver }
      friends2 = User.app_friends([@user2]).collect { |f| f.user_id_receiver }
      mutual_friends = friends1 & friends2
      if mutual_friends.size == 0
        logger.warn2 "invalid request. Did not find any mutual friends between @user2 #{@user2.user_id} #{@user2.short_user_name} and login_user #{login_user.user_id} #{login_user.short_user_name}"
        save_flash '.invalid_request'
        redirect_to :action => :index
        return
      end
      # ok - found mutual friends
    end

    @page_values = {}
    @user_nav_links = []

    # recalculate balance once every day
    # todo: should only recalculate user balance from @user2.balance_at and to today
    if !@user2.balance_at or @user2.balance_at.to_yyyymmdd != Sequence.get_last_exchange_rate_date
      @user2.recalculate_balance
      @user2.reload
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
    logger.debug2  "tab = #{tab}"

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
      logger.debug2  "return empty ajax response with dummy row with correct last_row_id to client"
      @api_gifts = @users2 = []
      @last_row_id = session[:last_row_id]
      respond_to do |format|
        format.js {}
      end
      return
    end

    if %w(gifts balance).index(tab)
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
      # see js functions imgonload and report_missing_api_picture_urls
      @missing_api_picture_urls = get_missing_api_picture_urls()

      # filters: status (open, closed and all) and direction (giver, receiver and both)
      statuses = %w(open closed all)
      status = params[:status] || 'all'
      status = 'all' unless %w(open closed all).index(status)
      directions = %w(giver receiver both)
      direction = params[:direction] || 'both'
      direction = 'both' unless %w(giver receiver both).index(direction)
      logger.debug2  "balance filters: status = #{status}, direction = #{direction}"

      # initialize array with user navigation links. 0-3 sections with links. Up to 9 links.
      @user_nav_links << ["tabs", tabs] if tabs.size > 1
      if %w(gifts balance).index(tab)
        @user_nav_links << ["deal_status", statuses]
        @user_nav_links << ["deal_direction", directions]
      end
      @page_values[:status] = status
      @page_values[:direction] = direction

      # find gifts with @user2 as giver or receiver
      # this select only shows gifts for @user2.provider - that is not gifts across providers
      # todo: should show gift across providers if @user2.user_combination and @user2 in @users
      #       ( balance shared across login providers if user has selected this )
      api_gifts = ApiGift.where('(user_id_giver = ? or user_id_receiver = ?) and gifts.deleted_at is null',
                            @user2.user_id, @user2.user_id).references(:gifts, :api_gifts).includes(:gift, :giver, :receiver).find_all do |ag|
        # apply status and direction filters
        ((status == 'all' or (status == 'open' and !ag.gift.received_at) or (status == 'closed' and ag.gift.received_at)) and
            (direction == 'both' or (direction == 'giver' and ag.user_id_giver == @user2.user_id) or (direction == 'receiver' and ag.user_id_receiver == @user2.user_id)))
      end.sort do |a, b|
        if (a.gift.received_at || a.created_at) == (b.gift.received_at || b.created_at)
          b.id <=> a.id
        else
          (b.gift.received_at || b.created_at) <=> (a.gift.received_at || a.created_at)
        end # if
      end # sort
      # return next 10 gifts - first 10 for http request - next 10 for ajax request
      @api_gifts, @last_row_id = get_next_set_of_rows(api_gifts, last_row_id)
      logger.debug2  "@gifts.size = #{@api_gifts.size}, @last_row_id = #{@last_row_id}" if debug_ajax?
    end

    if tab == 'friends'
      # show friends for @user2 - sort by user_name
      # users = @user2.app_friends.collect { |f| f.friend }.sort { |a,b| a.user_name <=> b.user_name}

      logger.debug2 'simple friends search - just return login users friends'
      logger.debug2 "user2 = #{@user2.user_id} #{@user2.short_user_name}"
      users = User.app_friends([@user2]).sort_by_user_name.collect { |f| f.friend }
      logger.debug2 "users = " + users.collect { |u| u.user_id}.join(', ')


      # users = User.all # uncomment to test ajax
      # return next 10 users - first 10 for http request - next 10 for ajax request
      @users2, @last_row_id = get_next_set_of_rows(users, last_row_id)
      logger.debug2  "@users2.size = #{@users2.size}, @last_row_id = #{@last_row_id}" if debug_ajax?
    end # friends

    if tab == 'gifts'
      # show 4 last comments for each gift
      @first_comment_id = nil
    end # gifts

    @page_values[:tab] = tab

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
      save_flash '.invalid_currency' # todo: add key - test error message
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
    # logger.debug2  "ok - all needed exchange rates was available - currency and balance was updated"
    # logger.debug2  "currency = #{@user.currency}, balance = #{@user.balance}"
    # @user.save!

    redirect_to params[:return_to]
  end  # update_user_currency


  # do friend actions (add/remove api/app friend etc)
  # see users.friend_status_actions for full list
  def friend_actions
    # next page is not ajax - remove last_row_id from return_to url to prevent ajax response
    return_to = params[:return_to]
    return_to = return_to.gsub(/&last_row_id=\d+/,'')
    return_to = return_to.gsub(/(last_row_id=\d+&)/,'')
    # check param
    id2 = params[:friend_id]
    user2 = User.find_by_id(id2)
    if !user2
      logger.debug2  "invalid request. Friend with id #{id2} was not found"
      save_flash '.invalid_request'
      redirect_to return_to
      return
    end
    login_user = @users.find { |user| user.provider == user2.provider }
    friend_action = params[:friend_action]
    allowed_friend_actions = user2.friend_status_actions(login_user).collect { |fa| fa.downcase }
    if !allowed_friend_actions.index(friend_action)
      logger.debug2  "invalid request. Friend action #{friend_action} not allowed."
      logger.debug2  "allowed friend actions are " + allowed_friend_actions.join(', ')
      redirect_to return_to
      return
    end

    # friend actions: add_api_friend, remove_api_friend, send_app_friend_request, accept_app_friend_request, ignore_app_friend_request, remove_app_friend, block_app_user, unblock_app_user

    if %w(add_api_friend remove_api_friend).index(friend_action)
      # api friend actions
      # no facebook api dialogs to add and remove facebook friends - just redirect to users profile page at facebook
      redirect_to api_profile_url(user2)
      return
    end

    # do app friend action
    # for example send_app_friend_request with ok response send_app_friend_request_ok and error response send_app_friend_request_error
    postfix = user2.send(friend_action, login_user) ? "_ok" : "_error"
    save_flash ".#{friend_action}#{postfix}", :appname => APP_NAME, :username => user2.short_user_name
    redirect_to return_to
  end # friend_actions


end

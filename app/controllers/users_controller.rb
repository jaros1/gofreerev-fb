class UsersController < ApplicationController

  before_filter :login_required
  before_filter :clear_state_cookie_store

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
    # check user.id
    id = params[:id]
    @user2 = User.find_by_id(id)
    if !@user2
      logger.debug2  "invalid request. User with id #{id} was not found"
      save_flash '.invalid_request'
      redirect_to :action => :index, :friends => 'me'
      return
    end
    logger.debug2  "@user2 = #{@user2.id} #{@user2.user_name}"
    if !login_user_ids.index(@user2.user_id)
      logger.debug2  "invalid request. Not logged in with user id #{id}"
      save_flash '.invalid_request'
      redirect_to :action => :index, :friends => 'me'
      return
    end
    # ok. login user. edit allowed
    # post_on_wall checkbox. 0 disable/hide, 1 unchecked, 2 checked
    if !API_POST_PERMITTED[@user2.provider]
      @post_on_wall = 0
    else
      @post_on_wall = @user2.post_on_wall_yn == 'Y' ? 2 : 1
    end
  end # edit

  # delete user data and close account ajax request
  def destroy
    @errors = []
    @trigger_tasks_form = false
    begin

      # check user.id
      id = params[:id]
      user = User.find_by_id(id)
      if !user
        logger.debug2 "invalid request. User with id #{id} was not found"
        @errors << t('.invalid_request')
        return
      end
      logger.debug2 "user2 = #{user.debug_info}"
      if !login_user_ids.index(user.user_id)
        logger.debug2 "invalid request. Not logged in with user id #{id}"
        save_flash '.invalid_request'
        redirect_to :action => :index, :friends => 'me'
        return
      end

      if !user.deleted_at
        user.update_attribute(:deleted_at, Time.new)
        other_user = @users.find { |u| u.id != user.id and !u.deleted_at }
        key = other_user ? '.ok2_html' : '.ok1_html'
        @errors << t(key, user.app_and_apiname_hash.merge(:url => API_APP_SETTING_URL[user.provider] || '#'))
        add_task "User.delete_user(#{user.id})",5
        @trigger_tasks_form = true
        return
      end

      if user.deleted_at > 6.minutes.ago
        @errors << t('.pending_html', user.app_and_apiname_hash.merge(:url => API_APP_SETTING_URL[user.provider] || '#'))
        return
      end

      key, options = User.delete_user(user.id)
      if key
        key = "shared.translate_ajax_errors#{key}"
        @errors << t(key, options)
        return
      end

      # delete completed
      @errors << t('.completed_html', user.app_and_apiname_hash.merge(:url => API_APP_SETTING_URL[user.provider] || '#'))
      logout(user.provider)

    rescue Exception => e
      logger.debug2 "Exception: #{e.message.to_s}"
      logger.debug2 "Backtrace: " + e.backtrace.join("\n")
      @errors << t(".exception", :error => e.message.to_s)
    end
  end # destroy

  def index
    # page filters:
    # - friends: yes no me all
    # - appuser: yes no all
    # - apiname: provider all
    @page_values = {}

    # friends filter: yes:show friends, no:show not friends, me:show my accounts, all:show all users (')
    # * = only show friends of friends - not all Gofreerev users
    friends_filter_values = %w(yes no me all)
    friends_filter = params[:friends] || friends_filter_values.first
    if !friends_filter_values.index(friends_filter)
      logger.error2 "invalid request. friends = #{friends_filter}. allowed values are #{friends_filter_values.join(', ')}"
      friends_filter = friends_filter_values.first
    end
    @page_values[:friends] = friends_filter
    if @page_values[:friends] == 'me'
      # show logged in users - ignore appuser and apiname filters
      @page_values[:appuser] = @page_values[:apiname] = 'all'
    else
      # appuser filter: yes: show gofreerev users, no: show users that is not using gofreerev, all: show all users (*)
      appuser_filter_values = %w(all yes no)
      appuser_filter = params[:appuser] || appuser_filter_values.first
      if !appuser_filter_values.index(appuser_filter)
        logger.error2 "invalid request. appuser = #{appuser_filter}. allowed values are #{appuser_filter_values.join(', ')}"
        appuser_filter = appuser_filter_values.first
      end
      @page_values[:appuser] = appuser_filter

      # appname filter: all: show all users (*), provider: show only users for selected provider
      apiname_filter_values = %w(all) + @users.collect {|u| u.provider }
      apiname_filter = params[:apiname] || apiname_filter_values.first
      if !apiname_filter_values.index(apiname_filter)
        logger.error2 "invalid request. apiname = #{apiname_filter}. allowed values are #{apiname_filter_values.join(', ')}"
        apiname_filter = apiname_filter_values.first
      end
      @page_values[:apiname] = apiname_filter
    end

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
      @last_row_id = get_last_row_id()
      respond_to do |format|
        format.js {}
      end
      return
    end

    # apply apiname filter before friends lookup
    if @page_values[:apiname] == 'all'
      users = @users
    else
      user = @users.find { |u| u.provider == @page_values[:apiname] }
      users = [user]
    end

    # get users - use info from friends_hash
    friends_categories = case @page_values[:friends]
                           when 'me'
                             [1]
                           when 'yes'
                             [1,2]
                           when 'no'
                             [3,4,5,6]
                           when 'all'
                             [1,2,3,4,5,6]
                         end
    users2 = User.app_friends(users,friends_categories).sort_by_user_name.collect { |f| f.friend }
    if @page_values[:friends] == 'me'
      users2 = users2.sort do |a,b|
        provider_downcase(a.provider) <=> provider_downcase(b.provider)
      end
    end

    # apply appuser filters after user lookup
    users2.delete_if do |u|
      ( (@page_values[:appuser] == 'yes' and !u.app_user?) or
        (@page_values[:appuser] == 'no' and u.app_user?) )
    end


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
    elsif (@user2.friend?(@users) <= 6)
      # ok - friends or friend of friend
    else
      ## not friend. Must have a mutual friend to allow user/show
      #friends1 = User.app_friends([login_user]).collect { |f| f.user_id_receiver }
      ## todo: google+ friend invitation to a stalker
      #friends2 = User.app_friends([@user2]).collect { |f| f.user_id_receiver }
      #mutual_friends = friends1 & friends2
      #if mutual_friends.size == 0
      logger.warn2 "invalid request. Did not find any mutual friends between @user2 #{@user2.user_id} #{@user2.short_user_name} and login_user #{login_user.user_id} #{login_user.short_user_name}"
      save_flash '.invalid_request'
      redirect_to :action => :index
      #  return
      #end
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
    if (@user2.friend?(@users) <= 2)
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
      @last_row_id = get_last_row_id()
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

      # todo: google+ - should show @user2's friends and followers - should not show users stalking user2
      users = User.app_friends(cache_friend_info([@user2]), [2,3]).sort_by_user_name.collect { |f| f.friend }
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

    # debug nav links
    # logger.debug2 "params          = #{params}"
    # logger.debug2 "@user_nav_links = #{@user_nav_links}"
    # logger.debug2 "@page_values    = #{@page_values}"

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
    if new_currency != BASE_CURRENCY
      today = Sequence.get_last_exchange_rate_date
      er = ExchangeRate.where('date = ? and from_currency = ? and to_currency = ?', today, BASE_CURRENCY, new_currency).first
      if !er
        save_flash '.invalid_currency' # todo: add key - test error message
        redirect_to params[:return_to]
        return
      end
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
    # logger.debug2  "currency = #{@users.first.currency}, balance = #{users.first.balance}"

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

  private
  def api_profile_url (user)
    return user.api_profile_url if user.api_profile_url.to_s =~ /^https?/
    provider = user.provider
    # API SETUP
    case provider
      when 'facebook' then "#{API_URL[provider]}/#{user.uid}"
      when 'flickr' then "#{API_URL[:flickr]}people/#{user.uid}"
      when 'foursquare' then "#{API_URL[provider]}/user/#{user.uid}"
      when 'google_oauth2' then "#{API_URL[provider]}#{user.uid}/posts"
      else
        # link to #{API_DOWNCASE_NAME[provider] || provider} user profile not implemented
        msg = translate '.api_profile_link_not_implemented', :apiname => (API_DOWNCASE_NAME[provider] || provider)
        logger.debug2 msg
        "javascript: alert('#{msg}')"
    end
  end
  helper_method :api_profile_url

end

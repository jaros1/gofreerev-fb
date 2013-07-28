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

      # currency updated in page header - update currency and return to page
      old_currency = @user.currency
      new_currency = params[:user][:currency]
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
      return
    end

    puts 'not implemented'
  end

  def edit
  end

  def destroy
  end

  def index
  end

  def show
    id = params[:id]
    @user2 = User.find(id)
    if !@user2
      puts "invalid request. User with id #{id} was not found"
      flash[:notice] = t '.invalid_request'
      redirect_to :action => :index
      return
    end
    @friend = @user2.friend?(@user)
    if @friend
      # todo: find user gifts (giver or receiver)
    end


  end # show_friend

end

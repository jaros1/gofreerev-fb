class UsersController < ApplicationController

  before_filter :fetch_user

  def new
  end

  def create
  end

  def update
    if params[:id] != @user.id.to_s
      puts "invalid id"
      redirect_to '/users'
      return ;
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
        flash[:notice] = t '.exchange_rates_not_ready'
        redirect_to params[:return_to]
        return
      end

      # ok - all needed exchange rates was available - currency and balance was updated
      # puts "ok - all needed exchange rates was available - currency and balance was updated"
      # puts "currency = #{@user.currency}, balance = #{@user.balance}"
      @user.save!

      redirect_to params[:return_to]
      return
    end

    puts "not implemented"
  end

  def edit
  end

  def destroy
  end

  def index
  end

  def show
  end

  private
  def fetch_user
    puts "user_id = #{session[:user_id]}"
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
  end

end

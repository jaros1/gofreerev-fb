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
      new_balance = BigDecimal.new "0"
      missing_exchange_rates = false
      gs = @user.offers.find_all { |g| g.user_id_receiver } + @user.gifts
      gs.each do |g|
        g.price = -g.price if @user.user_id == g.user_id_receiver
        new_price = ExchangeRate.exchange(g.price, g.currency, new_currency)
        if new_price.currency.to_s == new_currency
          new_balance = new_balance + new_price.to_f
        else
          missing_exchange_rates = true
        end
      end # each
      if missing_exchange_rates
        # not all exchange rates was ready yet - keep old balance and currency
        redirect_to params[:return_to]
        return
      end

      # ok - update currency and balance
      @user.currency = new_currency
      @user.balance = new_balance
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

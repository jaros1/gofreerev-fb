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
      if old_currency != new_currency
        @user.currency = params[:user][:currency]
        # todo: exchange currency from old to new currency
        @user.save!
      end

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

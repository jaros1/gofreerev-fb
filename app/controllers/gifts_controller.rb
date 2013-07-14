class GiftsController < ApplicationController



  def new
  end

  def create
    g = Gift.new
    # todo: catch invalid price exception
    g.price = BigDecimal.new params[:gift][:price]
    g.currency = @user.currency
    g.description = params[:gift][:description]
    g.user_id_giver = session[:user_id]
    g.save!
  end

  def update
  end

  def edit
  end

  def destroy
  end

  def index
    @gift = Gift.new
    @gift.currency = @user.currency
    @gift.user_id_giver = session[:user_id]
  end # index

  def show
  end

end

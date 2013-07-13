class GiftsController < ApplicationController


  before_filter :fetch_user

  def new
  end

  # called when user creates a new post.
  #   create_table "gifts", force: true do |t|
  #     t.integer  "gift_id"
  #     t.text     "description",                                           null: false
  #     t.string   "currency",          limit: 3
  #     t.decimal  "price",                        precision: 10, scale: 2
  #     t.string   "user_id_giver",     limit: 20,                          null: false
  #     t.string   "user_id_receiver",  limit: 20
  #     t.date     "received_at"
  #     t.date     "new_price_at"
  #     t.decimal  "new_price",                    precision: 10, scale: 2
  #     t.decimal  "negative_interest",            precision: 10, scale: 2
  #     t.decimal  "social_dividend",              precision: 10, scale: 2
  #     t.datetime "created_at"
  #     t.datetime "updated_at"
end

def create
    g = Gift.new
    g.price = params[:gift][:price]
    g.description = params[:gift][:description]
    g.
  end

  def update
  end

  def edit
  end

  def destroy
  end

  def index
    @gift = Gift.new
    @gift.currency = 'USD'
    @currencies = Money::Currency.table.collect { |a| [  "#{a[1][:iso_code]} #{a[1][:name]}".first(25), a[1][:iso_code] ] }
  end # index

  def show
  end

  private
  def fetch_user
    puts "user_id = #{session[:user_id]}"
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
  end
end

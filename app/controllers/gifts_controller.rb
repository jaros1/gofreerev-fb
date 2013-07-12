class GiftsController < ApplicationController

  before_filter :request_url_for_header
  before_filter :fetch_user

  def new
  end

  def create
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
  def request_url_for_header
    @request_fullpath = request.fullpath
  end

  def fetch_user
    puts "user_id = #{session[:user_id]}"
    @user = User.find_by_user_id(session[:user_id]) if session[:user_id]
  end
end

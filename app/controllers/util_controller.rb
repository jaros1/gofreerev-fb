class UtilController < ApplicationController

  # jquery update new message count in menu line once every minute
  def new_messages_count
    if @user
      count = @user.inbox_new_notifications
      @new_messages_count = count if count > 0
    end
    render :layout => false
  end

  # get array of gift ids with invalid picture url
  # temp api url can have changed / picture may have been deleted
  # Parameters: {"gifts"=>{"ids"=>"161"}}
  def missing_api_picture_urls
    render :layout => false
    return unless params.has_key?("gifts")
    return unless params[:gifts].has_key?(:ids)
    return if  params[:gifts][:ids] == ''
    ids = params[:gifts][:ids].split(',')
    gs = Gift.find(ids)
    puts "ids = #{ids}"
    gifts = Gift.where("id in (?)", ids)

    # set error timestamp
    gifts.each do |gift|
      puts gift.api_picture_url
      gift.api_picture_url_on_error_at = Time.now
      gift.save!
    end # each

    # get new picture urls
    # todo: 1 - catch deleted picture / status
    # todo: 2 - maybe app friend is not allowed to see picture in facebook
    # todo: 3 - max request picture url once every hour
    # todo: 4 - gifts/index - should check for error marked pictured and fix urls that couldn't be fixed in here (see 2)
    return unless session[:access_token]
    api = Koala::Facebook::API.new(session[:access_token])
    gifts.each do |gift|
      api_request = "#{gift.api_gift_id}?fields=full_picture"
      # todo: add exception handler
      api_response = api.get_object(api_request)
      gift.api_picture_url = api_response["full_picture"]
      gift.api_picture_url_updated_at = Time.now
      gift.api_picture_url_on_error_at = nil
      gift.save!
    end # each

  end # missing_api_picture_urls

end

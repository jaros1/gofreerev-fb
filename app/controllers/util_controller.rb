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
    #       Koala::Facebook::ClientError (type: GraphMethodException, code: 100, message: Unsupported get request. [HTTP 400]):
    # todo: 2 - maybe app friend is not allowed to see picture in facebook
    # todo: 3 - max request picture url once every hour
    # todo: 4 - gifts/index - should check for error marked pictured and fix urls that couldn't be fixed in here (see 2)
    return unless session[:access_token]
    api = Koala::Facebook::API.new(session[:access_token])
    gifts.each do |gift|
      next if gift.deleted_at_api == 'Y'
      api_request = "#{gift.api_gift_id}?fields=full_picture"
      # todo: add exception handler
      begin
        api_response = api.get_object(api_request)
      rescue Koala::Facebook::ClientError => e
        puts 'Koala::Facebook::ClientError'
        puts "e.fb_error_type = #{e.fb_error_type}"
        puts "e.fb_error_code = #{e.fb_error_code}"
        puts "e.fb_error_subcode = #{e.fb_error_subcode}"
        puts "e.fb_error_message = #{e.fb_error_message}"
        puts "e.http_status = #{e.http_status}"
        puts "e.response_body = #{e.response_body}"
        puts "e.fb_error_type.class.name = #{e.fb_error_type.class.name}"
        puts "e.fb_error_code.class.name = #{e.fb_error_code.class.name}"
        # Koala::Facebook::ClientError
        # e.fb_error_type = GraphMethodException
        # e.fb_error_code = 100
        # e.fb_error_subcode =
        # e.fb_error_message = Unsupported get request.
        # e.http_status = 400
        # e.response_body = {"error":{"message":"Unsupported get request.","type":"GraphMethodException","code":100}}
        # e.fb_error_type.class.name = String
        # e.fb_error_code.class.name = Fixnum
        # todo: identical error response if picture is deleted or if user is not allowed to see picture
        if e.fb_error_type == 'GraphMethodException' and e.fb_error_code == 100
          user_id_created_by = User.facebook_user_prefix + gift.api_gift_id.split('_').first
          if @user.user_id !=  user_id_created_by
            # picture may have or may not have been deleted in facebook.
            # User may not have permission to read picture on wall
            # keep api_picture_url_on_error_at timestamp and continue
            # the picture url will be checked by owner at a later time
            puts "Could not get new picture url. Could be deleted picture. Could be api permission problem. Keep error and let owner check picture url at a later time"
            next
          end # if
          # picture was not found.
          # it could be a fb permission problem but most likely the picture has been deleted
          # keep api_picture_url_on_error_at so that we known about when the picture was been deleted
          # gifts in app is not deleted automatically. Could affect the balance. Could be connected with other gifts.
          # allows users to cleanup their FB profile without destroying data in app
          puts "Gift has been deleted on #{@user.api_name_without_brackets}. Keep in #{APP_NAME} as the gift could have been used in balance and in connected gifts (todo)"
          gift.picture = 'N'
          gift.api_picture_url = nil
          gift.api_picture_url_updated_at = nil
          gift.deleted_at_api = 'Y'
          gift.save!
          next
        end # if
        # Koala::Facebook::ClientError
        # e.fb_error_type = GraphMethodException
        # e.fb_error_code = 100
        # e.fb_error_subcode =
        # e.fb_error_message = Unsupported get request.
        # e.http_status = 400
        # e.response_body = {"error":{"message":"Unsupported get request.","type":"GraphMethodException","code":100}}
        # e.fb_error_type.class.name = String
        # e.fb_error_code.class.name = Fixnum
        # others errors
        raise
      end # rescue
      # save new url
      gift.api_picture_url = api_response["full_picture"]
      gift.api_picture_url_updated_at = Time.now
      gift.api_picture_url_on_error_at = nil
      gift.save!
    end # each

  end # missing_api_picture_urls

end

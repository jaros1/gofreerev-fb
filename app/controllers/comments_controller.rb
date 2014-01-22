class CommentsController < ApplicationController

  before_filter :login_required

  # POST /comments
  # POST /comments.json
  # Parameters: {"utf8"=>"✓", "comment"=>{"gift_id"=>"j0N0uppxbj1nmDfsWBbk", "new_deal_yn"=>"Y", "price"=>"1", "comment"=>"25"}, "commit"=>"Gem"}
  def create
    @errors2 = []
    @api_comment = nil
    gift_row_id = nil
    begin
      # start with empty ajax response
      return append_create_comment_error(nil, '.invalid_request_no_comment_form') unless params.has_key?(:comment)
      gift = Gift.find_by_gift_id(params[:comment][:gift_id])
      return append_create_comment_error(nil, '.invalid_request_unknown_gift') unless gift
      return append_create_comment_error(nil, '.invalid_request_invalid_gift') unless gift.visible_for?(@users)
      gift_row_id = gift.id
      # get user from @users. Must be giver, receiver or friend of giver or receiver.
      user = @users.find { |user2| gift.visible_for?([user2]) }
      logger.debug2 "user_id = #{user.user_id}"
      comment = Comment.new
      comment.gift_id = gift.gift_id if gift
      comment.comment = params[:comment][:comment].to_s.force_encoding('UTF-8')
      if params[:comment][:new_deal_yn] == 'Y'
        comment.new_deal_yn = params[:comment][:new_deal_yn]
        comment.price = params[:comment][:price].gsub(',', '.').to_f unless invalid_price?(params[:comment][:price])
        comment.currency = @users.first.currency
      end
      # add api_comments. provider must be in api_gifts and in login in @users
      gift_providers = gift.api_gifts.collect { |ag| ag.provider }
      @users.each do |user|
        next unless gift_providers.index(user.provider)
        api_comment = ApiComment.new
        api_comment.gift_id = gift.gift_id
        api_comment.comment_id = comment.comment_id
        api_comment.provider = user.provider
        api_comment.user_id = user.user_id
        comment.api_comments << api_comment
      end
      return append_create_comment_error(gift_row_id, '.no_providers') if comment.api_comments.size == 0

      # validate comment - price= accepts only float and model can not return invalid price errors
      comment.valid?
      comment.errors.add :price, :invalid if params[:comment][:new_deal_yn] == 'Y' and invalid_price?(params[:comment][:price])
      if comment.errors.size > 1
        append_create_comment_error(gift_row_id, '.comment_error', {:error => comment.errors.full_messages.join(', ') })
      else
        comment.save!
      end

      # return new comment to browser
      @api_comment = comment.api_comments.shuffle.first

    rescue Exception => e
      logger.error2  "Exception: #{e.message.to_s}"
      logger.error2  "Backtrace: " + e.backtrace.join("\n")
      @api_comment = nil
      append_create_comment_error(gift_row_id, '.exception', :error => e.message)
    end
  end # create

  # Get /comments
  # params:
  #   gift_id: required
  #   first_comment_id: optional. Used in ajax request from gifts/index page to get more comments for a gift
  def index
    # find gift
    @error = t '.gift_id_is_missing' unless params[:gift_id].to_s != ""
    if !@error
      @gift = Gift.find_by_id(params[:gift_id])
      @error = t '.gift_was_not_found' unless @gift
    end
    # check if user may see gift. Must be giver, receiver, friend with giver or friend with receiver
    if !@gift.visible_for?(@users)
      @gift = nil
      @error = t '.gift_not_friends'
    end
    if !@error and params[:first_comment_id].to_s != ""
      first_comment = Comment.find_by_id(params[:first_comment_id])
      @error = t '.comment_not_found' if !first_comment
    end
    @error = t '.gift_comment_mismatch' if !@error and first_comment and first_comment.gift_id != @gift.gift_id

    if !@error
      @api_comments = @gift.api_comments_with_filter(params[:first_comment_id])
    end

    respond_to do |format|
      if !@error
        @first_comment_id = params[:first_comment_id]
        format.html { render }
        format.json { render json: @comment, status: :ok, location: @comment }
        format.js
      else
        @gift = @first_comment_id = nil
        format.html { render  }
        format.json { render json: @error, status: :unprocessable_entity }
        format.js
      end
    end # respond_to

  end # index

  def update
  end

  # ajax request from gifts/index page
  def destroy
    comment = nil
    @errors2 = []
    @link_id = nil
    begin
      id = params[:id]
      comment = Comment.find_by_id(id)
      if !comment
        logger.debug2 "Comment with id #{id} was not found"
        append_destroy_comment_error(comment, '.unknown_comment')
        return
      end
      if !comment.show_delete_comment_link?(@users)
        logger.debug2 "User can not delete comment with #{id}"
        append_destroy_comment_error(comment, '.invalid_comment')
        return
      end
      # delete mark comment
      # delete marked comment will be ajax removed from gifts/index page for current user now
      # delete marked comment will be ajax removed from gifts/index page for other users in util/new_messages_count request
      # old delete marked comments will be deleted from database in util/new_messages_count
      comment.deleted_at = Time.new
      comment.updated_by = login_user_ids.join(',')
      if comment.errors.size > 1
        append_destroy_comment_error(comment, '.comment_error', {:error => comment.errors.full_messages.join(', ') })
      else
        comment.save!
      end
      # hide row with comment
      @link_id = comment.table_row_id
    rescue Exception => e
      logger.error2 "Exception: #{e.message.to_s}"
      logger.error2 "Backtrace: " + e.backtrace.join("\n")
      @link_id = nil
      append_destroy_comment_error(comment, '.exception', :error => e.message)
    end
  end # destroy

  private
  def append_create_comment_error (gift_row_id, key, options = {})
    table = gift_row_id ? "gift-#{gift_row_id}-comment-new-errors" : "tasks_errors"
    logger.debug2 "table = #{table}, key = #{key}"
    @errors2 << { :msg => t(key, options), :id => table }
  end

  private
  def append_destroy_comment_error (comment, key, options = {})
    table = comment ? "gift-#{comment.gift.id}-comment-#{comment.id}-errors" : "tasks_errors"
    logger.debug2 "table = #{table}, key = #{key}"
    @errors2 << { :msg => t(key, options), :id => table }
  end

end

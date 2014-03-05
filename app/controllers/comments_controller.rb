class CommentsController < ApplicationController

  before_filter :login_required

  # POST /comments
  # POST /comments.json
  # Parameters: {"utf8"=>"✓", "comment"=>{"gift_id"=>"j0N0uppxbj1nmDfsWBbk", "new_deal_yn"=>"Y", "price"=>"1", "comment"=>"25"}, "commit"=>"Gem"}
  def create
    # start with empty ajax response
    @errors2 = []
    @api_comment = nil
    gift_row_id = nil
    begin
      return append_create_comment_error(gift_row_id, '.invalid_request_no_comment_form') unless params.has_key?(:comment)
      gift = Gift.find_by_gift_id(params[:comment][:gift_id])
      return append_create_comment_error(gift_row_id, '.invalid_request_unknown_gift') unless gift
      return append_create_comment_error(gift_row_id, '.invalid_request_invalid_gift') unless gift.visible_for?(@users)
      gift_row_id = gift.id
      # get user from @users. Must be giver, receiver or friend of giver or receiver.
      user = @users.find { |user2| gift.visible_for?([user2]) }
      logger.debug2 "user_id = #{user.user_id}"
      return append_create_comment_error(gift_row_id, '.deleted_user') if user.deleted_at
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
      format_ajax_response

    rescue Exception => e
      logger.error2  "Exception: #{e.message.to_s}"
      logger.error2  "Backtrace: " + e.backtrace.join("\n")
      @api_comment = nil
      append_create_comment_error(gift_row_id, '.exception', :error => e.message)
    end
  end # create

  # Get /comments - always ajax from get older comments link
  # params:
  #   gift_id: required
  #   first_comment_id: Used in ajax request from gifts/index page to get more comments for a gift
  def index
    @errors2 = []
    @gift = nil
    @api_comments = nil
    gift = nil
    begin
      # find gift
      if params[:gift_id].to_s == ""
        @errors2 <<  { :msg => t('.gift_id_is_missing'), :id => 'tasks_errors' }
        return
      end
      gift = Gift.find_by_id(params[:gift_id])
      if !gift
        @errors2 << { :msg => t('.gift_not_found'), :id => 'tasks_errors'}
        return
      end
      # gift was found.
      # any ajax error messages are now ajax injected into row under gifts link in gifts/index page
      # check if user may see gift. Must be giver, receiver, friend with giver or friend with receiver
      if !gift.visible_for?(@users)
        @errors2 << { :msg => t('.gift_not_friends'), :id => "gift-#{gift.id}-links-errors" }
        return
      end
      # check first_comment_id
      if params[:first_comment_id].to_s == ""
        @errors2 <<  { :msg => t('.first_comment_id_is_missing'), :id => "gift-#{gift.id}-links-errors" }
        return
      end
      first_comment = Comment.find_by_id(params[:first_comment_id])
      if !first_comment
        @errors2 << { :msg => t('.first_comment_not_found'),:id => "gift-#{gift.id}-links-errors" }
        return
      end
      if first_comment.gift_id != gift.gift_id
        @errors2 << { :msg => t('.gift_comment_mismatch'),:id => "gift-#{gift.id}-links-errors" }
        return
      end
      # ok - get next set older comments (comment.id < params[:first_comment_id])
      @first_comment_id = first_comment.id
      @api_comments = gift.api_comments_with_filter(@users, first_comment.id)
      @gift = gift
    rescue Exception => e
      # todo: refactor exception handling - almust identical for all gift action links
      logger.error2 "Exception: #{e.message.to_s}"
      logger.error2 "Backtrace: " + e.backtrace.join("\n")
      @errors2 << {:msg => t('.exception', :error => e.message.to_s, :raise => I18n::MissingTranslationData),
                   :id => gift ? "gift-#{gift.id}-links-errors" : "tasks_errors"}
      logger.error2 "@errors2 = #{@errors2}"
      @old_first_comment_id = nil
      @api_comments = nil
    end
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
      @users.remove_deleted_users
      if !comment.show_delete_comment_link?(@users)
        logger.debug2 "One or more user accounts are being deleted. User can not delete comment with #{id}"
        append_destroy_comment_error(comment, '.deleted_user')
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
    format_ajax_response
  end

  private
  def append_destroy_comment_error (comment, key, options = {})
    table = comment ? "gift-#{comment.gift.id}-comment-#{comment.id}-errors" : "tasks_errors"
    logger.debug2 "table = #{table}, key = #{key}"
    @errors2 << { :msg => t(key, options), :id => table }
  end

end

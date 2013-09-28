class CommentsController < ApplicationController

  before_filter :login_required

  # POST /comments
  # POST /comments.json
  def create
    # todo: add security - can user see gift?
    # todo: error handling - return row with error message - same format as after success
    # Parameters: {"utf8"=>"✓", "comment"=>{"gift_id"=>"j0N0uppxbj1nmDfsWBbk", "new_deal_yn"=>"Y", "price"=>"1", "comment"=>"25"}, "commit"=>"Gem"}
    @comment = Comment.new
    @comment.gift_id = params[:comment][:gift_id]
    @comment.user_id = @user.user_id
    @comment.comment = params[:comment][:comment].to_s.force_encoding('UTF-8')
    if params[:comment][:new_deal_yn] == 'Y'
      @comment.new_deal_yn = params[:comment][:new_deal_yn]
      # todo: validate price - use same server validation as for gift.price
      @comment.price = params[:comment][:price].to_f
      @comment.currency = @user.currency
    end

    respond_to do |format|
      if @comment.save
        puts "comment saved"
        format.html { redirect_to @comment, notice: 'Comment was successfully created.' }
        format.json { render json: @comment, status: :created, location: @comment }
        format.js
      else
        puts "comment not saved"
        format.html { render action: "new" }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
        format.js
      end
    end
  end # create

  # Get /comments
  # params:
  #   gift_id: required
  #   first_comment_id: optional. Used in ajax request from gifts/index page to get more comments for a gift
  def index
    # find gift
    @error = my_t '.gift_id_is_missing' unless params[:gift_id].to_s != ""
    if !@error
      @gift = Gift.find_by_id(params[:gift_id])
      @error = my_t '.gift_was_not_found' unless @gift
    end
    # check if user may see gift. Must be giver, receiver, friend with giver or friend with receiver
    if !@error and !@gift.giver.friend?(@user) and !@gift.receiver.friend?(@user)
      @gift = nil
      @error = my_t '.gift_not_friends'
    end
    if !@error and params[:first_comment_id].to_s != ""
      first_comment = Comment.find_by_id(params[:first_comment_id])
      @error = my_t '.comment_not_found' if !first_comment
    end
    @error = my_t '.gift_comment_mismatch' if !@error and first_comment and first_comment.gift_id != @gift.gift_id

    if !@error
      @comments = @gift.comments_with_filter(params[:first_comment_id])
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

  def destroy
  end
end

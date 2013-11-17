class CommentsController < ApplicationController

  before_filter :login_required

  # POST /comments
  # POST /comments.json
  # Parameters: {"utf8"=>"✓", "comment"=>{"gift_id"=>"j0N0uppxbj1nmDfsWBbk", "new_deal_yn"=>"Y", "price"=>"1", "comment"=>"25"}, "commit"=>"Gem"}
  def create
    gift = Gift.find_by_gift_id(params[:comment][:gift_id])
    puts "invalid request - gift with id #{params[:comment][:gift_id]} was not found" if !gift
    if gift and !gift.visible_for(@user)
      puts "invalid request - user #{@user.user_id} #{@user.user_name} can not comment gift id #{gift.id}"
      gift = nil
    end
    # todo: error handling - return row with error message - same format as after success?
    @comment = Comment.new
    @comment.gift_id = gift.gift_id if gift
    @comment.user_id = @user.user_id
    @comment.comment = params[:comment][:comment].to_s.force_encoding('UTF-8')
    if params[:comment][:new_deal_yn] == 'Y'
      @comment.new_deal_yn = params[:comment][:new_deal_yn]
      @comment.price = params[:comment][:price].gsub(',','.').to_f unless invalid_price?(params[:comment][:price])
      @comment.currency = @user.currency
    end

    respond_to do |format|
      # price= accepts only float and model can not return invalid price errors
      @comment.valid?
      @comment.errors.add :price, :invalid if params[:comment][:new_deal_yn] == 'Y' and invalid_price?(params[:comment][:price])
      if @comment.errors.size == 0
        @comment.save
        puts "comment saved"
        format.html { redirect_to @comment, notice: 'Comment was successfully created.' }
        format.json { render json: @comment, status: :created, location: @comment }
        format.js
      else
        puts "comment not saved. error = " + @comment.errors.full_messages.join(', ')
        puts "currency = #{@comment.currency}"
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
    @error = t '.gift_id_is_missing' unless params[:gift_id].to_s != ""
    if !@error
      @gift = Gift.find_by_id(params[:gift_id])
      @error = t '.gift_was_not_found' unless @gift
    end
    # check if user may see gift. Must be giver, receiver, friend with giver or friend with receiver
    if !@error and !@gift.giver.friend?(@user) and !@gift.receiver.friend?(@user)
      @gift = nil
      @error = t '.gift_not_friends'
    end
    if !@error and params[:first_comment_id].to_s != ""
      first_comment = Comment.find_by_id(params[:first_comment_id])
      @error = t '.comment_not_found' if !first_comment
    end
    @error = t '.gift_comment_mismatch' if !@error and first_comment and first_comment.gift_id != @gift.gift_id

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

  # ajax request from gifts/index page
  def destroy
    id = params[:id]
    comment = Comment.find_by_id(id)
    if !comment
      puts "Comment with id #{id} was not found - silently ignore ajax request"
      render :nothing => true
      return
    end
    if !comment.show_delete_comment_link?(@user)
      puts "User can not delete comment with #{id} - silently ignore ajax request"
      render :nothing => true
      return
    end
    # delete mark comment
    # comment will be removed from gifts/index page now for current user
    comment.deleted_at = Time.new
    comment.save
    @link_id = comment.table_row_id
  end # destroy

end

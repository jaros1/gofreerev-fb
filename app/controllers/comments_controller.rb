class CommentsController < ApplicationController

  # POST /products
  # POST /products.json
  def create
    @comment = Comment.new
    @comment.gift_id = params[:comment][:gift_id]
    @comment.user_id = @user.user_id
    @comment.comment = params[:comment][:comment]

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
  end

  def update
  end

  def destroy
  end
end

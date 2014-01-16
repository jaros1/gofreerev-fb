class ApiComment < ActiveRecord::Base

  #create_table "api_comments", force: true do |t|
  #  t.string   "gift_id",    limit: 20
  #  t.string   "comment_id", limit: 20
  #  t.string   "provider",   limit: 20
  #  t.string   "user_id",    limit: 40
  #  t.datetime "created_at"
  #  t.datetime "updated_at"
  #end

  belongs_to :gift, :class_name => 'Gift', :primary_key => :gift_id, :foreign_key => :gift_id
  belongs_to :user, :class_name => 'User', :primary_key => :user_id, :foreign_key => :user_id
  belongs_to :comment, :class_name => 'Comment', :primary_key => :comment_id, :foreign_key => :comment_id


  # 4) user_id - required - not encrypted - readonly
  validates_presence_of :user_id
  attr_readonly :user_id


  # number of older comments for gift
  # used in gifts/index page to display "show <n> more comments"
  attr_accessor :no_older_comments







end

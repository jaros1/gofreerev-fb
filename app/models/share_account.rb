class ShareAccount < ActiveRecord::Base
  has_many :users, :class_name => 'User', :primary_key => :id, :foreign_key => :share_account_id, :dependent => :nullify
end

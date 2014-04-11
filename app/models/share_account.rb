class ShareAccount < ActiveRecord::Base
  has_many :users, :class_name => 'User', :primary_key => :id, :foreign_key => :share_account_id, :dependent => :nullify

  # to combine users from different providers to a "single" account
  # user have to login for each provider to see friends and gifts from each provider
  # but balance total can be shared across providers
  def self.next_share_account_id (share_level, offline_access_yn)
    sa = ShareAccount.new
    sa.share_level = share_level
    sa.offline_access_yn = offline_access_yn
    sa.save!
    sa.id
  end # self.next_user_combination

end

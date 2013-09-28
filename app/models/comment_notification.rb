class CommentNotification < ActiveRecord::Base

  self.table_name = 'comments_notifications'

  belongs_to :comment
  belongs_to :notification
end

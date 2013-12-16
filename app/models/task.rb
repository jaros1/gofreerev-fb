class Task < ActiveRecord::Base

  # send task to ajax queue before render response
  def self.add_task (session_id, task, priority=5)
    at = Task.new
    at.session_id = session_id
    at.task = task
    at.priority = priority
    at.save!
  end

end

class AjaxTask < ActiveRecord::Base

  # send task to ajax queue before render response
  def self.add_task (session_id, task)
    at = AjaxTask.new
    at.session_id = session_id
    at.task = task
    at.save!
  end

end

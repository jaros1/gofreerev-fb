class Sequence < ActiveRecord::Base

  def self.status_update_at
    name = 'status_update_at_seq'
    transaction do
      s = Sequence.find_by_name(name)
      if !s
        s = Sequence.new
        s.name = name
        s.value = 0
      end
      s.value = s.value + 1
      s.save!
      return s.value
    end
  end # self.status_update_at

end

class Sequence < ActiveRecord::Base

  private
  def self.get_status_update_at
    name = 'status_update_at_seq'
    s = Sequence.find_by_name(name)
    if !s
      s = Sequence.new
      s.name = name
      s.value = 0
      s.save!
    end
    s
  end # self.get_status_update_at

  public
  def self.status_update_at
    Sequence.get_status_update_at.value
  end # self.status_update_at

  public
  def self.next_status_update_at
    transaction do
      s = Sequence.get_status_update_at
      s.value = s.value + 1
      s.save!
      return s.value
    end # do
  end # self.status_update_at

end

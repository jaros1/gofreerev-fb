class CreateFlashes < ActiveRecord::Migration
  def change
    create_table :flashes do |t|
      t.text :message
      t.timestamps
    end
  end
end

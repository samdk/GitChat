class AddTimeToCommit < ActiveRecord::Migration
  def self.up
    add_column :commits, :time, :datetime
  end

  def self.down
    remove_column :commits, :time
  end
end

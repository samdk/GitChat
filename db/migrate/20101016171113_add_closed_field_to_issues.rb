class AddClosedFieldToIssues < ActiveRecord::Migration
  def self.up
    add_column :issues, :open, :boolean, :default => true
  end

  def self.down
    remove_column :issues, :open
  end
end

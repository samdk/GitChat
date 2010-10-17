class AddStubFieldToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :stub, :boolean, :default => true
  end

  def self.down
    remove_column :users, :stub
  end
end

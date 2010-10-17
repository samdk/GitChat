class AddRepoUserJoin < ActiveRecord::Migration
  def self.up
    create_table :repositories_users, :id => false do |t|
      t.integer :user_id
      t.integer :repository_id
    end
  end

  def self.down
    drop_table :repositories_users
  end
end

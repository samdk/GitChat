class CreateChatsUsersJoin < ActiveRecord::Migration
  def self.up
    create_table :chats_users, :id => false do |t|
      t.integer :user_id
      t.integer :chat_id
    end
  end

  def self.down
    drop_table :chats_users
  end
end

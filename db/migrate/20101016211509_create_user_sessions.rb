class CreateUserSessions < ActiveRecord::Migration
  def self.up
    create_table :user_sessions do |t|
      t.timestamps
      t.string  :oauth_key
      t.string  :session_key
      t.references :user
      t.datetime  :last_seen
    end
  end

  def self.down
    drop_table :user_sessions
  end
end

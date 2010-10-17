class ChangedUserSessions < ActiveRecord::Migration
  def self.up
    rename_column 'user_sessions', 'oauth_key', 'access_token'
  end

  def self.down
    rename_column 'user_sessions', 'access_token' , 'oauth_key' 
  end
end

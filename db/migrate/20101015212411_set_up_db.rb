class SetUpDb < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.timestamps
      t.string  :profile_link
      t.string  :gravatar
      t.string  :username
      t.string  :real_name
      t.boolean :seen_before,      :default => false
    end
    
    create_table :chats do |t|
      t.timestamps
      t.references :repository
    end
    
    create_table :messages do |t|
      t.timestamps
      t.references :author
      t.references :issue
      t.references :commit
      t.references :chat
      t.datetime   :time
      t.text       :text
    end
    
    create_table :chats_messages, :id => false do |t|
      t.integer :message_id
      t.integer :chat_id
    end
    
    create_table :repositories do |t|
      t.timestamps
      t.string     :link
      t.string     :name
      t.references :creator
      t.references :parent_repo
      t.boolean    :private
    end
    
    create_table :repositories_repositories, :id => false do |t|
      t.integer :this_repository_id
      t.integer :other_repository_id
    end
    
    create_table :feed_items do |t|
      t.timestamps
      t.string :type
      t.datetime :time
      t.references :issue
      t.references :commit
    end
    
    create_table :issues do |t|
      t.timestamps
      t.references :creator
      t.string :title
      t.text :text
      t.string :github_id
      t.references :repositories
      t.references :closer
      t.string :close_msg
      t.datetime :created_date
      t.datetime :closed_date
    end
    
    create_table :commits do |t|
      t.timestamps
      t.string :hash
      t.references :repository
      t.string :commit_msg
      t.references :author
      t.string :tree
      t.string :parent
    end
  end
  def self.down
    drop_table :users
    drop_table :chats
    drop_table :messages
    drop_table :chats_messages
    drop_table :repositories
    drop_table :repositories
    drop_table :repositories_repositories
    drop_table :feed_items
    drop_table :issues
    drop_table :commits
  end
end

class RemoveFeedItems < ActiveRecord::Migration
  def self.up
    drop_table("feed_items")
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration.new
  end
end

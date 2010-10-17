class CleanupCommit < ActiveRecord::Migration
  def self.up
    remove_column "commits", "tree"
    remove_column "commits", "parent"
    add_column :commits, :branch, :string
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration.new
  end
end

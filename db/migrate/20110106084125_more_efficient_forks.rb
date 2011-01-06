class MoreEfficientForks < ActiveRecord::Migration
  def self.up
    drop_table("repositories_repositories")
    create_table :fork_lists do |t|
      t.integer :parent_id
    end

    add_column :repositories, :fork_id, :integer
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration.new
  end
end

class FixPluralizationInIssues < ActiveRecord::Migration
  def self.up
    rename_column :issues, :repositories_id, :repository_id
  end

  def self.down
    rename_column :issues, :repository_id, :repositories_id
  end
end

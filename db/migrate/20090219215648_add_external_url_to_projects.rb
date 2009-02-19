class AddExternalUrlToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :external_url, :string
  end

  def self.down
    remove_column :projects, :external_url
  end
end

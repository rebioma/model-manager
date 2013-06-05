class ChangeAscmodelAutoInc < ActiveRecord::Migration
  def up
  	change_column :asc_model, :id, :primary_key
  end

  def down
  end
end

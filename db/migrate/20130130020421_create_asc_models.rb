class CreateAscModels < ActiveRecord::Migration
  def change
    create_table :asc_models do |t|

      t.timestamps
    end
  end
end

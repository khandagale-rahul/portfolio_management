class CreateApiConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :api_configurations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :api_name, null: false, index: true
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.timestamps
    end

    add_index :api_configurations, [ :user_id, :api_name ], unique: true
  end
end

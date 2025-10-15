class CreateHoldings < ActiveRecord::Migration[8.0]
  def change
    create_table :holdings do |t|
      t.references :user, foreign_key: true, null: false
      t.integer :broker
      t.string :exchange
      t.string :trading_symbol
      t.jsonb :data

      t.timestamps
    end
  end
end

class CreateInstrumentHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :instrument_histories do |t|
      t.references :master_instrument, null: false, foreign_key: true
      t.integer :unit, index: true, null: false
      t.integer :interval, null: false
      t.datetime :date, null: false
      t.decimal :open, precision: 15, scale: 2
      t.decimal :high, precision: 15, scale: 2
      t.decimal :low, precision: 15, scale: 2
      t.decimal :close, precision: 15, scale: 2
      t.bigint :volume

      t.timestamps
    end

    add_index :instrument_histories, [ :master_instrument_id, :unit, :interval, :date ],
              unique: true, name: "index_instrument_histories_unique"
  end
end

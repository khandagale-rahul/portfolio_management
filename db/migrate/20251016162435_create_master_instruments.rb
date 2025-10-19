class CreateMasterInstruments < ActiveRecord::Migration[8.0]
  def change
    create_table :master_instruments do |t|
      t.string :name
      t.string :exchange
      t.string :exchange_token
      t.decimal :ltp, precision: 10, scale: 2
      t.decimal :previous_day_ltp, precision: 10, scale: 2
      t.integer :zerodha_instrument_id
      t.integer :upstox_instrument_id

      t.timestamps
    end

    add_index :master_instruments, :zerodha_instrument_id, unique: true
    add_index :master_instruments, :upstox_instrument_id, unique: true
  end
end

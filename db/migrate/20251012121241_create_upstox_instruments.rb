class CreateUpstoxInstruments < ActiveRecord::Migration[8.0]
  def change
    create_table :upstox_instruments do |t|
      t.timestamps
    end
  end
end

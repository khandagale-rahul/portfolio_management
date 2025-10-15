class CreateInstruments < ActiveRecord::Migration[8.0]
  def change
    create_table :instruments do |t|
      t.string :type, null: false
      t.string :symbol
      t.string :name
      t.string :exchange
      t.string :segment
      t.string :identifier
      t.string :exchange_token
      t.decimal :tick_size, precision: 10, scale: 5
      t.integer :lot_size
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    add_index :instruments, :type
    add_index :instruments, :symbol
    add_index :instruments, :exchange
    add_index :instruments, :identifier
    add_index :instruments, :raw_data, using: :gin
  end
end

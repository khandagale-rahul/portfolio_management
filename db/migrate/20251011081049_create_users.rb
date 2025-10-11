class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :phone_number, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, :phone_number, unique: true
  end
end

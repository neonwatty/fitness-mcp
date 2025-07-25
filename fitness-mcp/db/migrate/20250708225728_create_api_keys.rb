class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :api_key_hash
      t.datetime :revoked_at

      t.timestamps
    end
  end
end

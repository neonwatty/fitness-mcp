class CreateSetEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :set_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :exercise
      t.integer :reps
      t.decimal :weight
      t.datetime :timestamp

      t.timestamps
    end
  end
end

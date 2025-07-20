class CreateWorkoutAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :workout_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :assignment_name
      t.datetime :scheduled_for
      t.text :config

      t.timestamps
    end
  end
end

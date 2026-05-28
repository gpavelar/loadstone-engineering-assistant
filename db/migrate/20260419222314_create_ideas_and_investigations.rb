class CreateIdeasAndInvestigations < ActiveRecord::Migration[7.2]
  def change
    create_table :ideas do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.datetime :archived_at
      t.timestamps
    end
    add_index :ideas, [ :user_id, :archived_at ]

    create_table :investigations do |t|
      t.references :idea, null: false, foreign_key: { on_delete: :cascade }
      t.text :prompt
      t.string :status, null: false, default: "queued"
      t.references :conversation, foreign_key: true
      t.text :error_message
      t.timestamps
    end
    add_index :investigations, [ :idea_id, :created_at ]
  end
end

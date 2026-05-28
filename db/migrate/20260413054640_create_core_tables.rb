class CreateCoreTables < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :jira_account_id
      t.string :github_username
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.string :skill
      t.jsonb :tool_calls, default: {}
      t.timestamps
    end
  end
end

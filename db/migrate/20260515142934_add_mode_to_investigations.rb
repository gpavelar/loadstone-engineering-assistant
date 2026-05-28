class AddModeToInvestigations < ActiveRecord::Migration[7.2]
  def change
    add_column :investigations, :mode, :string
  end
end

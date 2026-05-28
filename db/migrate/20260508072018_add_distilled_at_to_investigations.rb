class AddDistilledAtToInvestigations < ActiveRecord::Migration[7.2]
  def change
    add_column :investigations, :distilled_at, :datetime
  end
end

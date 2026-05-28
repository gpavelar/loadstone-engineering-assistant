class CreateSolidQueueTables < ActiveRecord::Migration[7.2]
  def change
    load Rails.root.join("db/queue_schema.rb")
  end
end

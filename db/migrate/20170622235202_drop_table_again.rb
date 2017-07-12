class DropTableAgain < ActiveRecord::Migration[5.1]
  def change
    drop_table :tickets
  end
end

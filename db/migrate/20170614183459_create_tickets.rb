class CreateTickets < ActiveRecord::Migration[5.1]
  def change
    create_table :tickets do |t|
      t.string :access_code
      t.boolean :code_used, :default => false

    end
  end
end

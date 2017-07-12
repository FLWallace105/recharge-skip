class CreateTableAgain < ActiveRecord::Migration[5.1]
  def change
    create_table :tickets do |t|
      t.string :influencer_code
      t.index :influencer_code, unique: true
      t.boolean :code_used, :default => false
    end

  end
end

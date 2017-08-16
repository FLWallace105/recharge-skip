class Influencers < ActiveRecord::Migration[5.1]
  def up
    create_table :influencers do |t|
      t.string :first_name
      t.string :last_name
      t.string :address1
      t.string :address2
      t.string :city
      t.string :state
      t.string :zip
      t.string :email
      t.string :phone
      t.string :bra_size
      t.string :top_size
      t.string :bottom_size
      t.boolean :three_item
      t.boolean :processed
      t.datetime :time_order_submitted
      


    end
  end

  def down
    drop_table :influencers
  end

end

class CreateCustomerTable < ActiveRecord::Migration[5.1]
  def up
    create_table :customer_tables do |t|
      t.bigint :subscription_id
      t.bigint :address_id
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :next_charge_scheduled_at
      t.datetime :cancelled_At
      t.string :product_title
      t.decimal :price,  :precision => 10, :scale => 2
      t.integer :quantity
      t.string :status
      t.bigint :shopify_product_id
      t.bigint :shopify_variant_id
      t.string :sku
      t.string :order_interval_unit
      t.integer :order_interval_frequency
      t.integer :charge_interval_frequency
      t.integer :order_day_of_month
      t.integer :order_day_of_week
      t.jsonb :properties


    end
  end

  def down
    drop_table :customer_tables
  end

  
end

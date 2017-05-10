#test_shopify_api.rb

require 'shopify_api'
require 'dotenv'

Dotenv.load

APIKEY = ENV['ELLIE_STAGING_API_KEY']
PASSWORD = ENV['ELLIE_STAGING_PASSWORD']
SHOPNAME = ENV['SHOPNAME']

ShopifyAPI::Base.site = "https://#{APIKEY}:#{PASSWORD}@#{SHOPNAME}.myshopify.com/admin"

variant1 = ShopifyAPI::Variant.find(27320774021)
puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
#puts variant1.inspect
puts variant1.price
product_id = variant1.product_id
puts product_id.inspect
product1 = ShopifyAPI::Product.find(product_id)
puts product1.title
puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
my_array = my_raw_header.split('/')
my_result = my_array[0].to_i/my_array[1].to_f
puts my_result
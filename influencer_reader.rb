#code_reader.rb -- reads in access codes for ticket
require 'csv'
require 'dotenv'
require 'pg'
require 'httparty'
require 'sinatra/activerecord'

SHOP_WAIT = ENV['SHOPIFY_SLEEP_TIME']
INFLUENCER_TAG = ENV['INFLUENCER_TAG']
INFLUENCER_ORDER = ENV['INFLUENCER_ORDER']
INFLUENCER_PRODUCT = ENV['INFLUENCER_PRODUCT']
INFLUENCER_PRODUCT_ID = ENV['INFLUENCER_PRODUCT_ID']
NEW_CUST_TAGS = ENV['NEW_CUST_TAGS']
SHOPIFY_ELLIE_3PACK_ID = ENV['SHOPIFY_ELLIE_3PACK_ID']
SHOPIFY_ELLIE_3PACK_PRODUCT = ENV['SHOPIFY_ELLIE_3PACK_PRODUCT']

module InfluencerUtility
    class ReadInfluencer
        def initialize
            Dotenv.load

            $apikey = ENV['ELLIE_STAGING_API_KEY']
            $password = ENV['ELLIE_STAGING_PASSWORD']
            $shopname = ENV['SHOPNAME']
            $shopify_wait = ENV['SHOPIFY_SLEEP_TIME']
            
          
            #nothing for now
        end

        def readincodes
            uri = URI.parse(ENV['DATABASE_URL'])
            conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
            my_insert = "insert into influencers (first_name, last_name, address1, address2, city, state, zip, email, phone, bra_size, top_size, bottom_size, three_item) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"
            conn.prepare('statement1', "#{my_insert}")
            CSV.foreach('kylie_sample_influencer.csv', :headers => true) do |row|
                #puts row.inspect
                first_name = row['FirstName']
                last_name = row['LastName']
                address1 = row['Address1']
                address2 = row['Address2']
                city = row['City']
                state = row['State']
                zip = row['zip']
                email = row['email']
                phone = row['phone(optional)']
                bra_size = row['BraSize']
                top_size = row['TopSize']
                bottom_size = row['BottomSize']
                three_item = row['3Item']
                puts "#{first_name}, #{last_name}, #{address1}, #{address2}, #{city}, #{state}, #{zip}, #{email}, #{phone}, #{bra_size}, #{top_size}, #{bottom_size}, #{three_item}"
                if three_item.downcase == "yes" || three_item.downcase == "y"
                    three_item = true
                else
                    three_item = false
                end


                #puts row[0]
                #mycode = row[0].to_str
                #puts mycode
                conn.exec_prepared('statement1', [first_name, last_name, address1, address2, city, state, zip, email, phone, bra_size, top_size, bottom_size, three_item])
            end
                conn.close
        end

        def create_influencer_order
            start_time = Time.now
            uri = URI.parse(ENV['DATABASE_URL'])
            conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
          
            myquery = "select * from influencers where processed is not true order by id asc"
            
            results = conn.exec(myquery)
            results.each do |row|
                #puts row.inspect
                id = row['id']
                first_name = row['first_name']
                last_name = row['last_name']
                address1 = row['address1']
                address2 = row['address2']
                city = row['city']
                state = row['state']
                zip = row['zip']
                email = row['email']
                phone = row['phone']
                bra_size = row['bra_size']
                top_size = row['top_size']
                bottom_size = row['bottom_size']
                three_item = row['three_item']
                puts "#{first_name}, #{last_name}, #{address1}, #{address2}, #{city}, #{state}, #{zip}, #{email}, #{phone}, #{bra_size}, #{top_size}, #{bottom_size}, #{three_item}"
                ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
                my_customer = ShopifyAPI::Customer.search(query: email)
                puts my_customer.inspect
                puts "sleeping four seconds"
                sleep SHOP_WAIT.to_i
                if my_customer != []
                    puts "Customer exists in Shopify. Tagging as influencer."
                    shopify_id = my_customer[0].attributes['id']
                    puts "Customer Shopify ID = #{shopify_id}"
                    customer_tags = my_customer[0].attributes['tags']
                    puts "Customer tags = #{customer_tags}"
                    #first get customer tags, then split into array, then add influencer tag, then uniq array!
                    #then join to string, then submit tag string to tag_shopify_influencer
                    tag_array = customer_tags.split(', ')
                    tag_array << INFLUENCER_TAG
                    tag_array.uniq!
                    new_cust_tags = tag_array.join(", ")
                    puts "Tagging Customer with new tags: #{new_cust_tags}"
                    
                    #assign new tags to customer and also note
                    my_customer[0].attributes['tags'] = new_cust_tags
                    my_customer[0].attributes['note'] = "Influencer done through API"
                    my_customer[0].save
                    sleep SHOP_WAIT.to_i
            

                else
                    puts "Customer does NOT exist in Shopify, creating them with an influencer tag"
                    shopify_id = create_shopify_influencer_cust(first_name, last_name, email, phone, address1, address2, city, state, zip, $apikey, $password, $shopname, SHOP_WAIT)
                    puts "New customer shopify_id = #{shopify_id}"
            
                    #tag customer here
                    #NEW_CUST_TAGS
                    #tag_shopify_influencer(shopify_id, NEW_CUST_TAGS, $apikey, $password, $shopname, SHOP_WAIT)
                    new_customer = ShopifyAPI::Customer.find(shopify_id)
                    

                    puts new_customer.inspect
                    new_customer.attributes['tags'] = NEW_CUST_TAGS
                    new_customer.attributes['note'] = "Influencer done through API"
                    new_customer.save
            
                    

                end
                #add order here
                #ck for either 3pc or 5pc and construct order from that
                #puts three_item
                if three_item == 't'
                    puts "We need to process this order as a three item order"
                    add_shopify_three_pack_order(email, bottom_size, bra_size, top_size, first_name, last_name, address1, address2, phone, city, state, zip, $apikey, $password, $shopname, SHOPIFY_ELLIE_3PACK_ID, INFLUENCER_ORDER, SHOP_WAIT)
                    #code to add in access time and set processed = f


                else
                    puts "We need to process this order as a FIVE PIECE BOX order"
                    myaccessories1 = "One Size"
                    myaccessories2 = "One Size"
    
                    add_shopify_order(email, myaccessories1, myaccessories2, bottom_size, bra_size, top_size, first_name, last_name, address1, address2, phone, city, state, zip, $apikey, $password, $shopname, INFLUENCER_PRODUCT_ID, INFLUENCER_ORDER, SHOP_WAIT)

                end
                mytime = DateTime.now.strftime("%Y-%m-%d %H:%M:%S")
                my_update = "update influencers set processed = \'t\', time_order_submitted = \'#{mytime}\' where id = #{id}"
                conn.exec(my_update)
                end_time = Time.now
                duration = end_time - start_time
                puts "Running: --------> #{duration} seconds."
                if duration.ceil > 480
                    puts "We have been running #{duration} seconds and must exit"
                    exit
                end
                

            end
            conn.close
        end



        def create_shopify_influencer_cust(firstname, lastname, email, phone, address1, address2, city, state, zip, apikey, password, shopname, shop_wait)
            #POST /admin/customers.json
            my_new_customer = {
                    "customer": {
                    "first_name": firstname,
                    "last_name": lastname,
                    "email": email,
                    "phone": phone,
                    
                    "addresses": [
                    {
                      "address1": address1,
                      "address2": address2,
                      "city": city,
                      "province": state,
                      "phone": phone,
                      "zip": zip,
                      "last_name": lastname,
                      "first_name": firstname,
                      "country": "United States"
                    }
                  ]
            
                }
              }
          
          my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
          my_addon = "/customers.json"
          total_url = my_url + my_addon
          puts "Adding new influencer"
          puts total_url
          puts my_new_customer
          customer_response = HTTParty.post(total_url, :body => my_new_customer)
          puts customer_response
          puts "Done adding new influencer, now checking shopify call limits:"
          headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
          check_shopify_call_limit(headerinfo, shop_wait)
          customer_id = customer_response['customer']['id']
          return customer_id
        
        
        end



        def check_shopify_call_limit(headerinfo, shop_wait)
            puts "raw Shopify call limit info: #{headerinfo}"
            header_data = headerinfo.split('/')
            my_numerator = header_data[0].to_i
            my_denominator = header_data[1].to_i
            percentage = (my_numerator/my_denominator.to_f).round(2)
            puts "Used #{percentage} of Shopify call limits"
            if percentage >= 0.7
              puts "Sleeping #{shop_wait}"
              sleep shop_wait
            end
          
        end


          def add_shopify_order(myemail, myaccessories1, myaccessories2, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, apikey, password, shopname, prod_id, influencer_tag, shop_wait)
            puts "Adding Order for Influencer -- "
            puts "prod_id=#{prod_id}"
            my_order = {
                     "order": {
                      "email": myemail, 
                      "send_receipt": true,
                      "send_fulfillment_receipt": true,
                      "note": "Influencer Order through API",
                      "tags": influencer_tag,
                      "line_items": [
                      {
                      "product_id": prod_id,
                      "sku": "722457737550",
                      "quantity": 1,
                      "price": 0.00,
                      "title": INFLUENCER_PRODUCT,
                      "properties": [
                            {
                                "name": "accessories",
                                "value": myaccessories1
                            },
                            {
                                "name": "equipment",
                                "value": myaccessories2
                            },
                            {
                                "name": "leggings",
                                "value": myleggings
                            },
                            {
                                "name": "main-product",
                                "value": "true"
                            },                    
                            {
                                "name": "sports-bra",
                                "value": mysportsbra
                            },
                            {
                                "name": "tops",
                                "value": mytops
                            }
                        ]
                      }
                    ], 
                    "customer": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "email": myemail
            },
            "billing_address": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "address1": myaddress1,
              "address2": myaddress2,
              "phone": myphone,
              "city": mycity,
              "province": mystate,
              "country": "United States",
              "zip": myzip
            },
            "shipping_address": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "address1": myaddress1,
              "address2": myaddress2,
              "phone": myphone,
              "city": mycity,
              "province": mystate,
              "country": "United States",
              "zip": myzip
            }
            
                    
                    }
                  }
              
              #puts my_order
              my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
              my_addon = "/orders.json"
              total_url = my_url + my_addon
              puts total_url
              response = HTTParty.post(total_url, :body => my_order)
              puts response
              puts "Done adding orders, now checking for shopify call limits:"
              headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
              check_shopify_call_limit(headerinfo, shop_wait)
        
        end



        def add_shopify_three_pack_order(myemail, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, apikey, password, shopname, prod_id, influencer_tag, shop_wait)
            puts "Adding Order for Influencer -- "
            puts "prod_id=#{prod_id}"
            my_order = {
                     "order": {
                      "email": myemail, 
                      "send_receipt": true,
                      "send_fulfillment_receipt": true,
                      "note": "Influencer Order through API",
                      "tags": influencer_tag,
                      "line_items": [
                      {
                      "product_id": prod_id,
                      "quantity": 1,
                      "price": 0.00,
                      "title": SHOPIFY_ELLIE_3PACK_PRODUCT,
                      "properties": [
                            
                            {
                                "name": "leggings",
                                "value": myleggings
                            },
                            {
                                "name": "main-product",
                                "value": "true"
                            },                    
                            {
                                "name": "sports-bra",
                                "value": mysportsbra
                            },
                            {
                                "name": "tops",
                                "value": mytops
                            }
                        ]
                      }
                    ], 
                    "customer": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "email": myemail
            },
            "billing_address": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "address1": myaddress1,
              "address2": myaddress2,
              "phone": myphone,
              "city": mycity,
              "province": mystate,
              "country": "United States",
              "zip": myzip
            },
            "shipping_address": {
              "first_name": myfirstname,
              "last_name": mylastname,
              "address1": myaddress1,
              "address2": myaddress2,
              "phone": myphone,
              "city": mycity,
              "province": mystate,
              "country": "United States",
              "zip": myzip
            }
            
                    
                    }
                  }
              
              #puts my_order
              my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
              my_addon = "/orders.json"
              total_url = my_url + my_addon
              puts total_url
              response = HTTParty.post(total_url, :body => my_order)
              puts response
              puts "Done adding orders, now checking for shopify call limits:"
              headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
              check_shopify_call_limit(headerinfo, shop_wait)
        
        end


    end
end


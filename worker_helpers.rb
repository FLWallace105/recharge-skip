#worker_helpers.rb


module FixMonth
  
  def unskip_month_recharge(subscriber_month)
    puts subscriber_month.inspect
    
    subscriber_month = subscriber_month << 1
    my_new_year = subscriber_month.strftime("%Y")
    my_new_month = subscriber_month.strftime("%m")
    my_new_day = subscriber_month.strftime("%d")

    my_new_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
    puts my_new_date
    
    local_data = {
             "date" => my_new_date
                }
    local_data = local_data.to_json
    puts local_data
    return local_data
    
  end

  def reset_charge_date_post(subscriber_id, headers, body)
    reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscriber_id}/set_next_charge_date", :headers => headers, :body => body)
    puts "Changed Subscription Info, Details below:"
    puts reset_subscriber_date
    #puts "#{subscriber_id}, #{headers}, #{body}"

  end

  def request_customer_email(shopify_id, headers)
    get_customer_email = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => headers)
     customer_email = get_customer_email.parsed_response
     cust_email = customer_email['customers']
     #puts cust_email.inspect
     #puts cust_email[0]['email']
     my_customer_email = cust_email[0]['email']
     #puts "My customer_email = #{my_customer_email}" 
     return my_customer_email

  end

  def request_subscriber_id(shopify_id, headers, alt_title)
    my_subscription_id = ''
    orig_sub_date = ''
    other_three_month = "VIP 3 Month Box"
    three_month_box = "VIP 3 Monthly Box"
    get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => headers)
    subscriber_info = get_sub_info.parsed_response
    #puts subscriber_info.inspect
    subscriptions = get_sub_info.parsed_response['subscriptions']
    puts subscriptions.inspect
    subscriptions.each do |subs|
        puts subs.inspect
        if subs['product_title'] == "Monthly Box" || subs['product_title'] == alt_title || subs['product_title'] == three_month_box || subs['product_title'] == other_three_month
          #puts "Subscription scheduled at: #{subs['next_charge_scheduled_at']}"
          orig_sub_date = subs['next_charge_scheduled_at']
          my_subscription_id = subs['id']        
          end
      end
    my_subscriber_data = {'my_subscription_id' => my_subscription_id, 'orig_sub_date' => orig_sub_date }
    return my_subscriber_data
  end

  def skip_to_next_month(subscription_id, my_sub_date, headers)
      my_next_month = my_sub_date >> 1
      my_new_year = my_next_month.strftime("%Y")
      my_new_month = my_next_month.strftime("%m")
      my_new_day = my_next_month.strftime("%d")
      my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
      my_data = {
            "date" => my_new_sub_date
                }
      my_data = my_data.to_json
      #puts my_data
      reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => headers, :body => my_data)
      check_recharge_limits(reset_subscriber_date)
      puts "Changed Subscription Info, Details below:"
      puts reset_subscriber_date

  end  

  def check_change_date_ok(current_month, my_subscription_id, orig_sub_date, new_date, headers)
      my_sub_date = DateTime.parse(orig_sub_date)
      #proposed_date = DateTime.parse(new_date)
      proposed_date = DateTime.strptime(new_date, "%m-%d-%Y")
      proposed_month = proposed_date.strftime("%B")
      if proposed_month == current_month
        puts "changing shipment date in this month"
        #make sure change day of month > today day of the month
        today_date = Date.today.strftime("%e").to_i
        proposed_day = proposed_date.strftime("%e").to_i
        puts "today_date = #{today_date} and proposed_day = #{proposed_day}"
        my_temp_stuff = proposed_day - today_date
        puts "my_temp_stuff = #{my_temp_stuff}"
        if my_temp_stuff > 0
          puts "Can change date, it is later than today"
          new_year = proposed_date.strftime("%Y")
          new_month = proposed_date.strftime("%m")
          new_day = proposed_date.strftime("%d")
          my_new_sub_date = "#{new_year}-#{new_month}-#{new_day}T00:00:00"
          body = {
                 "date" => my_new_sub_date
                     }
          body = body.to_json
          reset_charge_date_post(my_subscription_id, headers, body)

        else
          puts "You can't change the charge/shipment date to one in the past or today, must be in the future"
        end
      else
        puts "The proposed_month date change is #{proposed_month} which is not this month: #{current_month}"
        puts "Cant do anything"
      end

  end


  def request_recharge_id(shopify_id, my_get_header)
      get_info = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
      my_info = get_info.parsed_response
      puts my_info.inspect
      cust_id = my_info['customers'][0]['id']
      puts cust_id.inspect
      sleep 3
      return cust_id
  end

  def request_address_id(cust_id, my_get_header)
    customer_addresses = HTTParty.get("https://api.rechargeapps.com/customers/#{cust_id}/addresses", :headers => my_get_header)
    my_addresses = customer_addresses.parsed_response
    puts my_addresses.inspect
    address_id = my_addresses['addresses'][0]['id']
    puts "address_id = #{address_id}"
    puts "Must sleep 3 seconds"
    sleep 3
    return address_id
  end

  def check_for_duplicate_subscription(shopify_id, shopify_variant_id, product_title, my_get_header, preview)
    all_subscriptions_customer = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => my_get_header)
    #puts all_subscriptions_customer.inspect
    my_return_date = Date.today + 1
    next_month = Date.today >> 1
    puts "Checking for duplicates ..."
    submit_order_flag = false
    puts "We want to avoid duplicate orders for ... #{product_title}, variant_id #{shopify_variant_id}"

    all_subscriptions_customer.parsed_response['subscriptions'].each do |mysub|
        puts mysub.inspect
        local_variant_id = mysub['shopify_variant_id']
        local_status = mysub['status']
        #local_sku = mysub['sku']
        local_product_title = mysub['product_title']
        today_date = Date.today + 1
        
        current_month = Date.today.strftime("%B")
        alt_vip_title = "#{current_month} VIP Box"
        alt_title = "#{current_month} Box"
        three_month_box = "VIP 3 Monthly Box"
        old_three_month_box = "VIP 3 Month Box"
        #puts "Local Title = #{local_product_title}"
        puts "variant_id = #{local_variant_id}, status=#{local_status}, local_title=#{local_product_title}"
        if shopify_variant_id.to_s == local_variant_id.to_s && local_status == "ACTIVE"  
          puts "Sorry, duplicate order can't add this!"
          submit_order_flag = false
        elsif local_product_title == product_title && local_status == "ACTIVE"
          puts "Sorry, duplicate order for title, looks like you already added a variant with this title!"
          submit_order_flag = false
        #Check to see if ship date for a Monthly Box or some variant of Monthly Box has passed
      elsif (local_product_title == "Monthly Box" || local_product_title == alt_vip_title || local_product_title == alt_title || local_product_title == three_month_box || local_product_title == old_three_month_box) && local_status == "ACTIVE"
          #Only if they have a Monthly box can they add on an order duh!
          submit_order_flag = true
          local_charge_date = mysub['next_charge_scheduled_at']
          puts "local_charge_date = #{local_charge_date}"
          my_charge_date = DateTime.parse(local_charge_date)
          my_return_date = my_charge_date
          puts "#{my_charge_date}, #{today_date}"
          if my_charge_date < today_date 
            puts "Box has already shipped, sorry can't add ... charge date is #{local_charge_date.inspect}"
            submit_order_flag = false
          end
          #Put check in here to see if the box has been skipped next month, then don't create add ons
          charge_date_month = my_charge_date.strftime("%B")
          if preview == false
            if charge_date_month != current_month
              puts "Can't add the upsell -- Customer skipped month to #{charge_date_month}"
              submit_order_flag = false
            end
          else
            #Logic is that we check to see if next_charge_date is one month ahead of next month as its preview last three days
            next_month_name = next_month.strftime("%B")
            puts "Checking for upsell skip month."
            puts  "Next month is #{next_month_name} and next charge date is #{charge_date_month}"
            if next_month_name != charge_date_month
              puts "Can't add the upsell, looks like the customer has skipped next month"
              puts "Skipping this upsell"
              submit_order_flag = false
            end

          end


        end
      end
      my_return_data = {"process_order" => submit_order_flag, "charge_date" => my_return_date}
      return my_return_data
  end

  def check_recharge_limits(api_info)
      my_api_info = api_info.response['x-recharge-limit']
      api_array = my_api_info.split('/')    
      my_numerator = api_array[0].to_i
      my_denominator = api_array[1].to_i
      api_percentage_used = my_numerator/my_denominator.to_f
      puts "API Call percentage used is #{api_percentage_used.round(2)}"
      if api_percentage_used > 0.6
        puts "Must sleep #{RECH_WAIT} seconds"
        sleep RECH_WAIT.to_i
      end

  end

  def add_shopify_order(myemail, myaccessories1, myaccessories2, myleggings, mysportsbra, mytops, myfirstname, mylastname, myaddress1, myaddress2, myphone, mycity, mystate, myzip, apikey, password, shopname, prod_id, influencer_tag, shop_wait)
    puts "Adding Order for Influencer -- "
    puts "prod_id=#{prod_id}"
    my_order = {
             "order": {
              "email": myemail, 
              "tags": influencer_tag,
              "line_items": [
              {
              "product_id": prod_id,
              "quantity": 1,
              "price": 0.00,
              "title": "Monthly Box",
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

  def tag_shopify_influencer(shopify_id, new_tags, apikey, password, shopname, shop_wait)
    my_customer_tag = {
             "customer":  {
             "id": shopify_id,
              
              "tags": new_tags,
              "note": "Influencer done through API"
              }
            }
      my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
      my_addon = "/customers/#{shopify_id}.json"
      total_url = my_url + my_addon
      puts "Tagging Customer"
      puts total_url
      puts my_customer_tag
      tag_response = HTTParty.put(total_url, :body => my_customer_tag)
      puts tag_response
      #Get header response
      headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      check_shopify_call_limit(headerinfo, shop_wait)
      puts "Done adding customer tags"

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

def check_duplicate_orders(shopify_id, apikey, password, shopname, influencer_product, shop_wait)
  #GET /admin/customers/#{id}/orders.json
  my_url = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
  my_addon = "/customers/#{shopify_id}/orders.json"
  total_url = my_url + my_addon
  puts total_url
  puts "Checking for duplicate orders"
  customer_orders = HTTParty.get(total_url)
  headerinfo = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
  check_shopify_call_limit(headerinfo, shop_wait)
  #puts customer_orders
  #Get today's date
  my_today = Date.today
  my_current_year = my_today.strftime('%Y')
  my_current_month = my_today.strftime('%B')
  my_current = "#{my_current_month}-#{my_current_year}"
  create_new_order = true

  puts "-----------------------"
  my_orders = customer_orders['orders']
  my_orders.each do |orderinfo|
      puts "----------------"
      #puts JSON.pretty_generate(orderinfo, {:indent => "\t"})
      created_at = orderinfo['created_at']
      order_name = orderinfo['name']
      order_created_at = DateTime.strptime(created_at, '%Y-%m-%dT%H:%M:%S')
      order_year = order_created_at.strftime('%Y')
      order_month = order_created_at.strftime('%B')
      order_current = "#{order_month}-#{order_year}"
      puts "Information for order #{order_name}:"
      puts "Order Created -> #{order_current}, Now => #{my_current}"
      order_title = orderinfo['line_items'][0]['title']
      puts "order_title = #{order_title}, checking against product #{influencer_product}"
      if order_current == my_current && order_title == influencer_product
        create_new_order = false
      end
      puts "================"
    end
return create_new_order

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

end
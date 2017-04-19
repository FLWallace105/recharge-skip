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
    get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => headers)
    subscriber_info = get_sub_info.parsed_response
    #puts subscriber_info.inspect
    subscriptions = get_sub_info.parsed_response['subscriptions']
    puts subscriptions.inspect
    subscriptions.each do |subs|
        puts subs.inspect
        if subs['product_title'] == "Monthly Box" || subs['product_title'] == alt_title
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
    sleep 3
    return address_id
  end

  def check_for_duplicate_subscription()

  
  end

end
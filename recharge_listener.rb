#recharge_listener.rb
require 'sinatra/base'
require 'httparty'
require 'dotenv'
require "resque"
require 'shopify_api'
require 'active_support/core_ext'

require_relative 'worker_helpers'

class SkipIt < Sinatra::Base


configure do

  enable :logging
  set :server, :puma
  Dotenv.load
  set :protection, :except => [:json_csrf]

  mime_type :application_javascript, 'application/javascript'
  mime_type :application_json, 'application/json'
  #$recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
  $recharge_access_token = ENV['RECHARGE_STAGING_ACCESS_TOKEN']
  $my_get_header =  {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}"
        }
  $my_change_charge_header = {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }

  #uncomment below for push to Heroku.
  uri2 = URI.parse(ENV["REDIS_URL"])
  REDIS = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)

  #SHOPIFY env variables
  $apikey = ENV['ELLIE_STAGING_API_KEY']
  $password = ENV['ELLIE_STAGING_PASSWORD']
  $shopname = ENV['SHOPNAME']
  $shopify_wait = ENV['SHOPIFY_SLEEP_TIME']
  $recharge_wait = ENV['RECHARGE_SLEEP_TIME']
  SHOP_WAIT = ENV['SHOPIFY_SLEEP_TIME']
  RECH_WAIT = ENV['RECHARGE_SLEEP_TIME']



end

def initialize
    #Dotenv.load
    @key = ENV['SHOPIFY_API_KEY']
    @secret = ENV['SHOPIFY_SHARED_SECRET'] 
    @app_url = "staging-skip-month.herokuapp.com"
    @tokens = {}
    super
  end

  get '/install' do
  shop = "elliestaging.myshopify.com"
  scopes = "read_orders,read_products"

  # construct the installation URL and redirect the merchant
  install_url =
    "http://#{shop}/admin/oauth/authorize?client_id=#{@key}&scope=#{scopes}"\
    "&redirect_uri=http://#{@app_url}/auth/shopify/callback"

  redirect install_url
end

get '/auth/shopify/callback' do
  # extract shop data from request parameters
  shop = request.params['shop']
  code = request.params['code']
  hmac = request.params['hmac']

  # perform hmac validation to determine if the request is coming from Shopify
  h = request.params.reject{|k,_| k == 'hmac' || k == 'signature'}
  query = URI.escape(h.sort.collect{|k,v| "#{k}=#{v}"}.join('&'))
  digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, query)

  if not (hmac == digest)
    return [403, "Authentication failed. Digest provided was: #{digest}"]
  end

  # if we don't have an access token for this particular shop,
    # we'll post the OAuth request and receive the token in the response
    if @tokens[shop].nil?
      url = "https://#{shop}/admin/oauth/access_token"

      payload = {
        client_id: @key,
        client_secret: @secret,
        code: code}

      response = HTTParty.post(url, body: payload)

      # if the response is successful, obtain the token and store it in a hash
      if response.code == 200
        @tokens[shop] = response['access_token']
      else
        return [500, "Something went wrong."]
      end
    end

    # now that we have the token, we can instantiate a session
    session = ShopifyAPI::Session.new(shop, @tokens[shop])
    @my_session = session
    ShopifyAPI::Base.activate_session(session)

    # create webhook for order creation if it doesn't exist
    if not ShopifyAPI::Webhook.find(:all).any?
      webhook = {
        topic: 'orders/create',
        address: "https://#{@app_url}/giftbasket/webhook/order_create",
        format: 'json'}

      ShopifyAPI::Webhook.create(webhook)
    end

    
    redirect '/hello'

end

get '/hello' do
  "Hello, success"
end

post '/funky-next-month-preview' do
  content_type :application_javascript
  status 200
  puts "Doing Funky Skip Next Month Preview"
  puts params.inspect

end

post '/next-month-skip' do
  content_type :application_javascript
  status 200
  puts "Doing Skip Next Month Preview"
  puts params.inspect
  Resque.enqueue(SkipPreviewMonth, params)

end

post '/preview-upsells' do
  content_type :application_javascript
  status 200
  puts "Doing Preview Month Upsell"
  puts params.inspect
  
  Resque.enqueue(UpsellPreviewMonth, params)


end



post '/recharge' do
  content_type :application_javascript
  status 200
  puts "doing GET stuff"
  puts params.inspect
  shopify_id = params['shopify_id']
  puts shopify_id
  action = params['action']

  #stuff below for Heroku
  Resque.redis = REDIS
  skip_month_data = {'shopify_id' => shopify_id, 'action' => action}
  Resque.enqueue(SkipMonth, skip_month_data)


end

post '/next-month-preview' do
  content_type content_type :application_javascript
  
  shopify_id = params['shopify_id']
  new_date = params['new_date']
  action = params['action']
  #customer_data = {"new_date" => new_date}
  #customer_data = customer_data.to_json
  #send_back = "previewDate(#{customer_data});"
  #body send_back
  #puts send_back

  #status 200
  puts "Processing Next Month Preview Ship Request"
  puts params.inspect
  preview_month_data = {"shopify_id" => shopify_id, "ship_date" => new_date, "action" => action}
  Resque.redis = REDIS
  Resque.enqueue(PreviewMonth, preview_month_data)
end

post '/recharge-new-ship-date' do
  content_type :application_javascript
  status 200

  puts "Doing change ship date"
  puts params.inspect
  shopify_id = params['shopify_id']
  new_date = params['new_date']
  action = params['action']
  choosedate_data = {"shopify_id" => shopify_id, "new_date" => new_date, 'action' => action}

  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(ChooseDate, choosedate_data)

end

get '/recharge-unskip' do
  content_type :application_javascript
  status 200

  puts "Doing unskipping task"
  puts params.inspect
  shopify_id = params['shopify_id']
  action = params['action']

  unskip_data = {"shopify_id" => shopify_id, "action" => action }

  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(UnSkip, unskip_data)

end

get '/customer_size_returner' do
  content_type :application_json
  puts params.inspect
  action = params['action']
  shopify_id = params['shopify_id']
  puts "Shopify_id = #{shopify_id} and action = #{action}"
  sleep 6

  my_data = {"shopify_id" => shopify_id, "action" => action}
  customer_data = return_cust_sizes(my_data)
  puts customer_data.inspect
  customer_data = customer_data.to_json
  send_back = "custSize(#{customer_data})"
  body send_back
  puts send_back

  puts "Done now"

end

post '/upsells' do
  puts "Doing upsell task"
  puts params.inspect


  content_type :application_json
  customer_data = {"return_value" => "hi_there"}
  customer_data = customer_data.to_json
  send_back = "myUpsells(#{customer_data})"
  body send_back
  puts send_back
  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(UpsellProcess, params)

end

post '/upsell_remove' do
  puts "Doing removing Upsell products from box subscription"
  puts params.inspect
  content_type :application_json
  customer_data = {"return_value" => "yeah_ok_removing_dude"}
  customer_data = customer_data.to_json
  send_back = "myUpsellsRemove(#{customer_data})"
  body send_back
  puts send_back

  Resque.redis = REDIS
  Resque.enqueue(UpsellRemove, params)


end


post '/change_cust_size' do
  puts "Doing changing customer sizes"
  puts params.inspect
  #stuff below for Heroku
  Resque.redis = REDIS
  Resque.enqueue(ChangeCustSizes, params)

end



helpers do

  def return_cust_sizes(my_data)
    #first check to make sure it is correct action
    action = my_data['action']
    shopify_id = my_data['shopify_id']
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    # --------- define customer size variables and instantiate the customer size array
    leggings_size = ''
    bra_size = ''
    tops_size = ''
    customer_sizes = {}
    orig_sub_date = ''
    # ----------------
    if action == 'need_cust_sizes'
      puts "Getting Customer Sizes"
      my_subscription_id = ''
      orig_sub_date = ''
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
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
          sizes_stuff = subs['properties']
          puts sizes_stuff.inspect
          sizes_stuff.each do |stuff|
            puts stuff.inspect
              case stuff['name']
                when 'leggings'
                    leggings_size = stuff['value']
                when 'sports-bra'
                    bra_size = stuff['value']
                when 'tops'
                    tops_size = stuff['value']
              end #case

            end

          end
        end
      #set customer sizes
      customer_sizes = {"leggings" => leggings_size, "bra_size" => bra_size, "tops_size" => tops_size}
      my_subscriber_data = {'next_charge_date' => orig_sub_date, 'cust_size_data' => customer_sizes }
      puts my_subscriber_data.inspect
      return my_subscriber_data

    else
      puts "Wrong action, action #{action} is not need_cust_sizes"
      puts "cant do anything"
    end

  end


  def get_subs_date(shopify_id)
    #Get alt_title
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    orig_sub_date = ""

    get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
    subscriber_info = get_sub_info.parsed_response
    #puts subscriber_info.inspect
    subscriptions = get_sub_info.parsed_response['subscriptions']
    puts subscriptions.inspect
    subscriptions.each do |subs|
      puts subs.inspect
      if subs['product_title'] == "Monthly Box" || subs['product_title'] == alt_title
         puts "Subscription scheduled at: #{subs['next_charge_scheduled_at']}"

         end
     end
     orig_sub_date ="\"#{orig_sub_date}\""

  end

end

class SkipPreviewMonth
  extend FixMonth
  @queue = "skip_preview_month"
  def self.perform(params)
    puts "We have the following params --> #{params.inspect}"
    shopify_id = params['shopify_id']
    action = params['action']
    if action == "skip_next_month"
      my_today_date = Date.today
      next_month = my_today_date >> 1
      current_month = my_today_date.strftime('%B')
      next_month_name = next_month.strftime('%B')
      puts "This is month #{current_month} and next month is #{next_month_name}"
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)   
      my_api_info = get_sub_info.response['x-recharge-limit']
      puts "Recharge says we have the following api call limits: #{my_api_info}"
      api_array = my_api_info.split('/')
      #puts api_array.inspect
      my_numerator = api_array[0].to_i
      my_denominator = api_array[1].to_i
      api_percentage_used = my_numerator/my_denominator.to_f
      puts "Which is #{api_percentage_used.round(2)}"
      if api_percentage_used > 0.6
        puts "Must sleep #{RECH_WAIT} seconds"
        sleep RECH_WAIT.to_i
      end
      mysubs = get_sub_info.parsed_response
      subscriptions = mysubs['subscriptions']
      subscriptions.each do |mys|
        if mys['status'] != "CANCELLED"
          puts "-------------"
          puts mys.inspect           
          puts "-------------"
          puts ""
          puts "======================="
          next_charge_scheduled = mys['next_charge_scheduled_at']
          next_charge_date = DateTime.strptime(next_charge_scheduled, '%Y-%m-%dT%H:%M:%S')
          next_charge_month = next_charge_date.strftime('%B')
          puts "next_charge_month is #{next_charge_month} and system next month is #{next_month_name}"
          if next_month_name == next_charge_month
            puts "We can skip next month as a preview"
            subscription_id = mys['id']
            puts "Skipping Subscription ID #{subscription_id}"
            skip_to_next_month(subscription_id, next_charge_date, $my_change_charge_header)
          else
            puts "We can't skip next month, the next charge is scheduled at: #{next_charge_scheduled}"
          end
          puts "======================="
        end
      end
      


    else
      puts "Action is #{action}, not skip_next_month, we cannot do anything, wrong parameters sent"  
    end

  end

end




class PreviewMonth
  extend FixMonth
  @queue = "preview_month"
  def self.perform(preview_month_data)
    puts "Now processing customer preview request ..."
    puts preview_month_data.inspect
    my_action = preview_month_data['action']
    if my_action == "get_preview_month"
      last_day_current_month = Date.today.end_of_month
      
      puts "Last day of current month = #{last_day_current_month}"
      shopify_id = preview_month_data['shopify_id']
      new_date = preview_month_data['ship_date']
      cust_requested_date = DateTime.strptime(new_date, '%Y-%m-%d')
      cust_month = cust_requested_date.strftime('%B')
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      sleep RECH_WAIT.to_i
      puts "Sleeping #{RECH_WAIT} seconds."
      mysubs = get_sub_info.parsed_response
      allsubscriptions = mysubs['subscriptions']
      allsubscriptions.each do |subs|
          if subs['status'] != "CANCELLED" && !!(subs['product_title'] =~/box/i)
            puts "------------------"
            puts subs.inspect
            next_charge = subs['next_charge_scheduled_at']
            puts "Next Charge Scheduled at: #{next_charge}"
            #2017-06-20T00:00:00
            actual_scheduled = DateTime.strptime(next_charge, '%Y-%m-%dT%H:%M:%S')
            actual_month = actual_scheduled.strftime('%B')

            puts "Customer Month Requested is #{cust_month} and actual charge month is #{actual_month}"
            # Check to see if actual_scheduled is greater than the last day of the month
            puts "Last Day of the month is #{last_day_current_month.to_s}"
            

            if last_day_current_month >= actual_scheduled
              puts "We can't allow customer to accept next month, looks like customer's next charge date is still pending last three days of the month."
            elsif     
              subscription_id = subs['id']
              puts "Accepting Next Month for subscription id #{subscription_id}" 

              body = { "date" => new_date }.to_json
              
              reset_charge_date_post(subscription_id, $my_change_charge_header, body)

            end
            puts "------------------"
          end
        end
      


    else
      puts "Sorry, the action is #{my_action}, not get_preview_month therefore we cannot process this request."
    end
  end
end

class UpsellRemove
  extend FixMonth
  @queue = "upsellremove"
  def self.perform(remove_add_on_data)
    puts "Now removing add on to box ..."
    puts remove_add_on_data.inspect
    endpoint_info = remove_add_on_data['endpoint_info']
    if endpoint_info == "upsell_remove"
      product_title = remove_add_on_data['shopify_product_title']
      shopify_id = remove_add_on_data['shopify_id']
      product_id = remove_add_on_data['shopify_product_id']
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      puts "Must sleep #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subscriber_stuff = get_sub_info.parsed_response
      #puts subscriber_stuff.inspect
      subscriptions = subscriber_stuff['subscriptions']
      #puts subscriptions.inspect
      subscriptions.each do |mysub|
        if mysub['status'] != "CANCELLED" && mysub['shopify_product_id'].to_i == product_id.to_i
          puts "-----------"
          puts mysub.inspect
          puts "Product Title sent = #{product_title}"
          puts "Product_id sent = #{product_id}"
          puts "-----------"
          cancel_subscription_id = mysub['id']
          puts "Canceling subscription #{cancel_subscription_id}"
          #-- now cancel the subscription.
          #POST /subscriptions/<subscription_id>/cancel
          my_data = {"cancellation_reason" => "Customer Through API/Website"}.to_json
          my_cancel = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{cancel_subscription_id}/cancel", :headers => $my_change_charge_header, :body => my_data)
          my_response = my_cancel.parsed_response
          puts "Recharges sent back: #{my_response}"
          puts "Must Sleep now #{RECH_WAIT} seconds"
          sleep RECH_WAIT.to_i

          end
        end

    else
      puts "We can't do anything, the endpoint_info is #{endpoint_info} not upsell_remove"
      puts "Sorry but rules are rules."
    end

  end

end

class ChangeCustSizes
  extend FixMonth
  @queue = "changecustsizes"
  def self.perform(cust_sizes_data)
    puts "We are Processing the Customer Size Data"
    puts cust_sizes_data.inspect
    my_action = cust_sizes_data['action']
    my_shopify_id = cust_sizes_data['shopify_id']
    cust_sizes_hash = cust_sizes_data['cust_sizes']
    puts "my_action = #{my_action}"
    if my_action == "change_cust_sizes"
      puts "my_shopify_id = #{my_shopify_id}"
      puts "cust_sizes_hash = #{cust_sizes_hash.inspect}"
      bottom_sizes = cust_sizes_hash['bottom_size']
      #puts "bottom_sizes = #{bottom_sizes}"
      bottom_sizes = bottom_sizes.gsub(/\s+/, " ").strip
      top_sizes = cust_sizes_hash['top_size']
      top_sizes = top_sizes.gsub(/\s+/, " ").strip
      bra_sizes = cust_sizes_hash['bra_size']
      bra_sizes = bra_sizes.gsub(/\s+/, " ").strip

      puts "Cust Sizes now bottom=#{bottom_sizes}, top=#{top_sizes}, bra=#{bra_sizes}"
      #cust_id = request_recharge_id(my_shopify_id, $my_get_header)
      #puts "cust_id =#{cust_id}"
      #puts "sleeping 3"
      #sleep 3
      #address_id = request_address_id(cust_id, $my_get_header)
      #puts "sleeping 3 again"
      #sleep 3

      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"

      my_subscription_id = ''

      my_subscriber_data = request_subscriber_id(my_shopify_id, $my_get_header, alt_title)

      my_subscription_id = my_subscriber_data['my_subscription_id']
      puts "My Subscriber ID = #{my_subscription_id}"
      my_data_recharge = {"properties" => [{"name" => "leggings", "value" => bottom_sizes }, {"name" => "sports-bra", "value" =>bra_sizes }, {"name" => "tops", "value" => top_sizes }]}.to_json
      puts my_data_recharge
      send_size_change_recharge = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{my_subscription_id}", :headers => $my_change_charge_header, :body => my_data_recharge)
      puts send_size_change_recharge

    else
      puts "Action is #{my_action}"
      puts "We can't do anything, must be change_cust_sizes"

      end

  end

end

class UpsellPreviewMonth
  extend FixMonth
  @queue = "upsellpreview"
  def self.perform(params)
    puts "Unpacking the Preview Month upsell info"
    puts params.inspect
    puts "---------------"
    my_action = params['endpoint_info']
    variant_id = params['shopify_variant_id']
    shopify_id = params['shopify_id']
    if my_action == "cust_upsell" && variant_id != '' && !variant_id.nil?
      #go ahead and do stuff
      puts "processing this order"
      cust_id = request_recharge_id(shopify_id, $my_get_header)
      puts "cust_id =#{cust_id}"
      address_id = request_address_id(cust_id, $my_get_header)
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      #puts "OK HERE"
      my_variant = ShopifyAPI::Variant.find(variant_id)
      puts "found variant #{my_variant.id}"
      my_customer_size = my_variant.option1
      puts "Customer size = #{my_customer_size}"
      #create customer line item properties for history
      line_item_properties = [ { "name" => "size", "value" => my_customer_size } ]
      my_raw_price = my_variant.price.to_f
      puts "my_raw_price = #{my_raw_price}"
      my_true_variant_id = variant_id.to_i
      true_price = my_raw_price
      my_product_id = my_variant.product_id.to_i
      my_product = ShopifyAPI::Product.find(my_product_id)
      my_product_title = my_product.title
      puts "Found #{my_product_title}"
      #puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      puts "Shopify Header Info: #{my_raw_header}"
      my_array = my_raw_header.split('/')
      my_result = my_array[0].to_i/my_array[1].to_f
      if my_result > 0.75
        puts "Too many calls, must sleep #{SHOP_WAIT} seconds"
        sleep SHOP_WAIT
      end
      puts "my_product_title=#{my_product_title}, my_true_variant_id=#{my_true_variant_id}, true_price=#{true_price}, my_product_id = #{my_product_id}"
      #hard-code quantity=1 and today's date for next-charge
      quantity = 1
      preview = true
      
      submit_order_hash = check_for_duplicate_subscription(shopify_id, my_true_variant_id, my_product_title, $my_get_header, preview)
      submit_order_flag = submit_order_hash['process_order']
      process_order_date = submit_order_hash['charge_date']
      puts "submit_order_flag = #{submit_order_flag}"
      


      if submit_order_flag == false
          puts "This is a duplicate order, I can't send to Recharge as there already exists an ACTIVE subscription with this variant_id #{variant_id} or title #{product_title}."
      else
          puts "OK, submitting order"
          data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => process_order_date, "product_title" => my_product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => my_true_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "0", "charge_interval_frequency" => "0", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          puts data_send_to_recharge
          puts "sleeping #{RECH_WAIT}"
          sleep RECH_WAIT.to_i
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => $my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
        end


    else
      puts "WARNING ERROR: Action is #{my_action} and it must be cust_upsell, or else variant_id is nil and variant_id = #{variant_id}, we can't do anything here, not processing this upsell."
    end
  end
end

class UpsellProcess
  extend FixMonth
  @queue = "upsellprocess"
  def self.perform(upsellprocess_data)
    puts "Unpacking upsellprocess_data:"
    puts upsellprocess_data.inspect
    my_action = upsellprocess_data['endpoint_info']
    variant_id = upsellprocess_data['shopify_variant_id']
    #check for correct action and end if incorrect
    if my_action == "cust_upsell" && variant_id != '' && !variant_id.nil?
      #go ahead and do stuff
      puts "processing this order"
      shopify_id = upsellprocess_data['shopify_id']

      variant_id = upsellprocess_data['shopify_variant_id']
      puts "variant_id=#{variant_id}"
      puts "processing customer upsell products"
      cust_id = request_recharge_id(shopify_id, $my_get_header)
      puts "cust_id =#{cust_id}"
      address_id = request_address_id(cust_id, $my_get_header)
      #New code 5-8-17: take variant_id and request to Shopify
      #Product_title, product_id, price
      #puts "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      ShopifyAPI::Base.site = "https://#{$apikey}:#{$password}@#{$shopname}.myshopify.com/admin"
      #puts "OK HERE"
      my_variant = ShopifyAPI::Variant.find(variant_id)
      puts "found variant #{my_variant.id}"
      my_customer_size = my_variant.option1
      puts "Customer size = #{my_customer_size}"
      #create customer line item properties for history
      line_item_properties = [ { "name" => "size", "value" => my_customer_size } ]
      my_raw_price = my_variant.price.to_f
      puts "my_raw_price = #{my_raw_price}"
      my_true_variant_id = variant_id.to_i
      true_price = my_raw_price
      my_product_id = my_variant.product_id.to_i
      my_product = ShopifyAPI::Product.find(my_product_id)
      my_product_title = my_product.title
      puts "Found #{my_product_title}"
      #puts ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      my_raw_header = ShopifyAPI::response.header["HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT"]
      puts "Shopify Header Info: #{my_raw_header}"
      my_array = my_raw_header.split('/')
      my_result = my_array[0].to_i/my_array[1].to_f
      if my_result > 0.75
        puts "Too many calls, must sleep #{SHOP_WAIT} seconds"
        sleep SHOP_WAIT
      end



      puts "my_product_title=#{my_product_title}, my_true_variant_id=#{my_true_variant_id}, true_price=#{true_price}, my_product_id = #{my_product_id}"
      #hard-code quantity=1 and today's date for next-charge
      quantity = 1
      tomorrow = Date.today + 1

      my_charge_date = tomorrow.strftime("%Y-%m-%d")


      #data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => next_charge_scheduled, "product_title" => product_title, "price" => price_float, "quantity" => quantity, "shopify_variant_id" => variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "1", "charge_interval_frequency" => "1"}.to_json
      #puts data_send_to_recharge


      puts "----"
      preview = false
      submit_order_hash = check_for_duplicate_subscription(shopify_id, my_true_variant_id, my_product_title, $my_get_header, preview)
      submit_order_flag = submit_order_hash['process_order']
      process_order_date = submit_order_hash['charge_date']
      puts "submit_order_flag = #{submit_order_flag}"



      if submit_order_flag == false
          puts "This is a duplicate order, I can't send to Recharge as there already exists an ACTIVE subscription with this variant_id #{variant_id} or title #{product_title}."
      else
          puts "OK, submitting order"
          data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => process_order_date, "product_title" => my_product_title, "shopify_product_id" => my_product_id,  "price" => true_price, "quantity" => "#{quantity}", "shopify_variant_id" => my_true_variant_id, "order_interval_unit" => "month", "order_interval_frequency" => "0", "charge_interval_frequency" => "0", "number_charges_until_expiration" => "1", "properties" => line_item_properties }.to_json
          puts data_send_to_recharge
          puts "sleeping #{RECH_WAIT}"
          sleep RECH_WAIT.to_i
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => $my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
        end


    else
      #don't do anything, incorrect parameters
      puts "We can't do anything: endpoint_info = #{my_action}"
    end

  end
end


class Upsell
  extend FixMonth
  @queue = "upsell"
  def self.perform(upsell_data)
    puts "Unpacking request data"
    puts upsell_data.inspect
    action = upsell_data['action']
    shopify_id = upsell_data['shopify_id']
    product_title = upsell_data['product_title']

    next_charge = upsell_data['next_charge']
    price = upsell_data['price']
    quantity = upsell_data['quantity']
    sku = upsell_data['sku'].to_i
    shopify_variant_id = upsell_data['shopify_variant_id'].to_i
    size = upsell_data['size']
    #create properties array here, be CAREFUL MUST BE NAME-VALUE pairs
    property_json = {"name" => "size", "value" => "S"}
    properties = [property_json]


    if action == 'cust_upsell'
        puts "processing customer upsell products"
        cust_id = request_recharge_id(shopify_id, $my_get_header)
        address_id = request_address_id(cust_id, $my_get_header)
        #puts product_title, next_charge, price, quantity, shopify_variant_id, size
        #redo date into something Recharge can handle.
        next_charge_scheduled_at_date = DateTime.strptime(next_charge, "%m-%d-%Y")
        next_charge_scheduled = next_charge_scheduled_at_date.strftime("%Y-%m-%d")
        #next_charge_scheduled = "#{next_charge_scheduled}"
        data_send_to_recharge = {"address_id" => address_id, "next_charge_scheduled_at" => next_charge_scheduled, "product_title" => product_title, "price" => price, "quantity" => quantity, "shopify_variant_id" => shopify_variant_id, "sku" => sku, "order_interval_unit" => "month", "order_interval_frequency" => "0", "charge_interval_frequency" => "0", "number_charges_until_expiration" => "1", "properties" => properties}.to_json
        puts data_send_to_recharge


        #puts $my_change_charge_header
        #Before sending, request all subscriptions and avoid submitting duplicates.


        submit_order_flag = check_for_duplicate_subscription(shopify_id, shopify_variant_id, $my_get_header)

        if submit_order_flag
          puts "Sleeping #{RECH_WAIT} seconds."
          sleep RECH_WAIT.to_i
          puts "Submitting order as a new upsell subscription"
          send_upsell_to_recharge = HTTParty.post("https://api.rechargeapps.com/subscriptions", :headers => $my_change_charge_header, :body => data_send_to_recharge)
          puts send_upsell_to_recharge.inspect
        else
          puts "This is a duplicate order, I can't send to Recharge as there already exists an ACTIVE subscription with this variant_id #{shopify_variant_id}."
        end


    else
      puts "Wrong action received from browser: #{action}, action must be cust_upsell ."
    end

  end
end


class UnSkip
  extend FixMonth
  @queue = "unskip"
  def self.perform(unskip_data)
    puts unskip_data.inspect
    shopify_id = unskip_data['shopify_id']
    action = unskip_data['action']
    #first check to see if we are doing the correct action
    if action == 'unskip_month'
      puts "shopify_id = #{shopify_id}"
      #Get alt_title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''

      my_subscriber_data = request_subscriber_id(shopify_id, $my_get_header, alt_title)
      orig_sub_date = my_subscriber_data['orig_sub_date']
      my_subscription_id = my_subscriber_data['my_subscription_id']
      puts "My Subscriber ID = #{my_subscription_id}, my original date = #{orig_sub_date}"


     puts "Must sleep for #{RECH_WAIT} secs"
     sleep RECH_WAIT.to_i

     my_customer_email = request_customer_email(shopify_id, $my_get_header)

     puts "My customer_email = #{my_customer_email}"
     puts "Must sleep for #{RECH_WAIT} secs again"
     sleep RECH_WAIT.to_i
     customer_next_subscription_date = DateTime.parse(orig_sub_date)
     customer_previous_month = customer_next_subscription_date << 1
     customer_previous_month_name = customer_previous_month.strftime("%B")
     puts "Customer Previous Month Name = #{customer_previous_month_name}"
     puts "Current Month = #{current_month}"
     if current_month == customer_previous_month_name
        puts "Unskipping Month"
        my_data = ""
        my_data = unskip_month_recharge(customer_next_subscription_date)
        puts my_data.inspect
        puts "My Subscription ID = #{my_subscription_id}"
        reset_charge_date_post(my_subscription_id, $my_change_charge_header, my_data)


     else
        puts "Months to unskip don't match, not doing anything"

     end


    else
      puts "Sorry that action is not unskip_month we won't do anything"

    end



  end
end


class ChooseDate
  extend FixMonth
  @queue = "choosedate"
  def self.perform(choosedate_data)
    puts choosedate_data.inspect
    shopify_id = choosedate_data['shopify_id']
    new_date = choosedate_data['new_date']
    action = choosedate_data['action']

    puts "shopify_id = #{shopify_id}"
    puts "new_date = #{new_date}"
    puts "action = #{action}"
    my_today_date = Date.today
    puts "Today's Date is #{my_today_date.to_s}"
    if action == 'change_date'
      puts "Changing the date for charge/shipping"
      #Get alt_title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''
      plain_title = "#{current_month} Box"
      alt_title = "#{current_month} VIP Box"
      three_month_box = "VIP 3 Monthly Box"
      old_three_month_box = "VIP 3 Month Box"
      orig_sub_date = ""
      my_subscription_id = ''
      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      mysubs = get_sub_info.parsed_response
      puts mysubs
      puts "Must sleep for #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subsonly = mysubs['subscriptions']
      subsonly.each do |subs|
        if subs['status'] != "CANCELLED"
            product_title = subs['product_title']
            if product_title == "VIP 3 Monthly Box" || product_title == "Monthly Box" || product_title ==   alt_title || product_title = plain_title || product_title == old_three_month_box
              puts subs.inspect
              my_subscription_id = subs['id']
              orig_sub_date = subs['next_charge_scheduled_at']
              puts "subscription created at #{subs['created_at']}"
              temp_sub_created = subs['created_at'].split('T')
              my_temp_sub_create = temp_sub_created[0]
              puts my_temp_sub_create
              subscription_created_at = Date.parse(my_temp_sub_create)
              sub_created_at_str = subscription_created_at.strftime('%B')
              today_str = my_today_date.strftime('%B')
              puts "Subscription created at: #{sub_created_at_str}, today month is #{today_str}"
              puts "#{my_subscription_id}, #{orig_sub_date}"
              if today_str != sub_created_at_str
                check_change_date_ok(current_month, my_subscription_id, orig_sub_date, new_date,$my_change_charge_header)
              elsif
                puts "We cannot change date, today month is #{today_str} and subscription_created_at is month #{sub_created_at_str} "
                end
              end
          end
        end


    else
      puts "Action must be change_date, and action is #{action} so we can't do anything."
    end

  end
end

class SkipMonth
  extend FixMonth
  @queue = "skipthismonth"
  def self.perform(skip_month_data)
    puts skip_month_data.inspect
    action = skip_month_data['action']
    shopify_id = skip_month_data['shopify_id']

    if action == 'skip_month'
      current_month = Date.today.strftime("%B")
      plain_title = "#{current_month} Box"
      alt_title = "#{current_month} VIP Box"
      three_month_box = "VIP 3 Monthly Box"
      old_three_month_box = "VIP 3 Month Box"
      orig_sub_date = ""
      my_subscription_id = ''
      puts "Got Here to request data from Recharge."

      get_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions?shopify_customer_id=#{shopify_id}", :headers => $my_get_header)
      mysubs = get_sub_info.parsed_response
      puts "Must sleep for #{RECH_WAIT} seconds"
      sleep RECH_WAIT.to_i
      subsonly = mysubs['subscriptions']
      subsonly.each do |subs|

        if subs['status'] != "CANCELLED"
            product_title = subs['product_title']
            if product_title == "VIP 3 Monthly Box" || product_title == "Monthly Box" || product_title ==   alt_title || product_title = plain_title || product_title == old_three_month_box
              puts subs.inspect
              my_subscription_id = subs['id']
              orig_sub_date = subs['next_charge_scheduled_at']
              puts "#{my_subscription_id}, #{orig_sub_date}"
              #Now check to see if the subscriber can skip to next month, i.e. their current
              #next_subscription date is this month. If not, do nothing.
              my_sub_date = DateTime.parse(orig_sub_date)
              subscriber_actual_next_charge_month = my_sub_date.strftime("%B")
              puts "Subscriber next charge month = #{subscriber_actual_next_charge_month}"
              puts "Current month is #{current_month}"
              if current_month == subscriber_actual_next_charge_month
                 puts "Skipping charge to next month"
                 skip_to_next_month(my_subscription_id, my_sub_date, $my_change_charge_header)

              else
                 puts "We can't do anything, the next_charge_month is #{subscriber_actual_next_charge_month} which is not the current month -- #{current_month}"
              end


            end
          end
        end

    else
      puts "We can't do anything, action is #{action} which is not skip_month dude!"
    end

  end

end


class MyParamHandler
  @queue = "skipbox"
  def self.perform(shopify_id)
    #get the recharge customer_id
    #recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
    #puts "recharge_access_token = #{$recharge_access_token}"
    @my_header = {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}"
        }
    @my_change_charge_header = {
            "X-Recharge-Access-Token" => "998616104d0b4668bcffa0cfde15392e",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }

    get_info = HTTParty.get("https://api.rechargeapps.com/customers?shopify_customer_id=#{shopify_id}", :headers => @my_header)
    my_info = get_info.parsed_response
    puts my_info.inspect
    my_recharge_id = my_info['customers'][0]['id']
    puts my_recharge_id
    puts "Must sleep for two seconds"
    sleep 2
    #get all charges to find right one
    charges_customer = HTTParty.get("https://api.rechargeapps.com/charges?customer_id=#{my_recharge_id}&status=queued", :headers => @my_header )
    all_charges = charges_customer.parsed_response
    puts "Must sleep again for two seconds"
    sleep 2

    puts all_charges['charges'].inspect

    my_charges = all_charges['charges']
    #puts my_charges.inspect
    #puts my_charges.class
    #puts my_charges.size

    #Get the Alternate title, pattern April VIP Box etc.
    current_month = Date.today.strftime("%B")
    alt_title = "#{current_month} VIP Box"
    alt_3month_title = "VIP 3 Monthly Box"
    old_3month_box = "VIP 3 Month Box"
    alt_month_plain_title = "#{current_month} Box"

    #Define scope of subscription_id to use later
    subscription_id = ""


    my_charges.each do |myc|
      #puts myc.inspect
      #puts "----------"
      #puts myc['line_items'].inspect
      #puts "-----------"
      myc['line_items'].each do |line|
        puts ""
        puts line.inspect


        if line['title'] == "Monthly Box" || line['title'] == alt_title || line['title'] == alt_3month_title || line['title'] == alt_month_plain_title || line['title'] == old_3month_box
          subscription_id = line['subscription_id']
          puts "Found Subscription id = #{subscription_id}"
          #Here we skip the subscription to the next month
          subscription_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header )
          my_subscription = subscription_info.parsed_response
          puts "Gotta sleep again sorry two seconds"
          sleep 2
          subscription_date = my_subscription['subscription']['next_charge_scheduled_at']
          puts "subscription_date = #{subscription_date}"
          my_sub_date = DateTime.parse(subscription_date)
          #Check to make sure they are not skipping next month
          subscriber_actual_next_charge_month = my_sub_date.strftime("%B")
          puts subscriber_actual_next_charge_month
          puts current_month
          if subscriber_actual_next_charge_month == current_month

            my_next_month = my_sub_date >> 1
            my_day_month = my_sub_date.strftime("%e").to_i

            next_month_name = my_next_month.strftime("%B")
            #puts next_month_name
            #Constructors for new subscription charge date
            my_new_year = my_next_month.strftime("%Y")
            my_new_month = my_next_month.strftime("%m")
            my_new_day = my_next_month.strftime("%d")

            month_31 = ["January", "March", "May", "July", "August", "October", "December"]
            month_30 = ["April", "June", "September", "November"]

            if month_31.include? next_month_name
              puts "No need to adjust next month day, it has 31 days!"
              #Just advance subscription date by one day
              my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_new_day}T00:00:00"
              my_data = {
              "date" => my_new_sub_date
                  }
              my_data = my_data.to_json
              reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
              puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
          elsif month_30.include? next_month_name
            puts "We need to fix day 31 for this month since this month has only 30"
            if my_day_month == 31
              my_day_month = 30
              puts "New Day for Charge: #{my_day_month}"
              end
            my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_day_month}T00:00:00"
            my_data = {
              "date" => my_new_sub_date
                 }
            my_data = my_data.to_json
            reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
            puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
          else
            puts "we need to fix days 29-31 since Feb has only 28 and eff leap year"
            if my_day_month > 28
              my_day_month = 28
              puts "New Day for Charge in Feb: #{my_day_month}"
            end
            my_new_sub_date = "#{my_new_year}-#{my_new_month}-#{my_day_month}T00:00:00"
            my_data = {
              "date" => my_new_sub_date
                }
            my_data = my_data.to_json
            reset_subscriber_date = HTTParty.post("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_charge_header, :body => my_data)
            puts "Changed Subscription Info, Details below:"
            puts reset_subscriber_date
        end
          else
            #we can't skip the month because it is next month
            puts "Sorry We Can't Skip next month as it is next month"
          end




        end
        puts ""
        end


      end
      puts "Done with skipping this subscription, #{subscription_id}"
  end
end



end

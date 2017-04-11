#recharge_listener.rb
require 'sinatra'
require 'httparty'
require 'dotenv'
require "resque"
require_relative 'worker_helpers'

class SkipIt < Sinatra::Base


configure do 
  
  enable :logging
  set :server, :puma
  Dotenv.load
  mime_type :application_javascript, 'application/javascript'
  $recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
  $my_get_header =  {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}"
        }
  $my_change_charge_header = {
            "X-Recharge-Access-Token" => "#{$recharge_access_token}",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }
  
  uri2 = URI.parse(ENV["REDIS_URL"])
  REDIS = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)
  
  end






get '/recharge' do
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



get '/recharge-new-ship-date' do
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




helpers do
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
     orig_sub_date

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


     puts "Must sleep for 3 secs"
     sleep 3
     
     my_customer_email = request_customer_email(shopify_id, $my_get_header)

     puts "My customer_email = #{my_customer_email}" 
     puts "Must sleep for 3 secs again"
     sleep 3
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

    if action == 'change_date'
      puts "Changing the date for charge/shipping"
      #Get alt_title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''
      #puts "#{shopify_id}, #{$my_get_header}, #{alt_title}"
      subscriber_data = request_subscriber_id(shopify_id, $my_get_header, alt_title)
      my_subscription_id = subscriber_data['my_subscription_id']
      orig_sub_date = subscriber_data['orig_sub_date']
      puts "Subscription_id = #{my_subscription_id}, original_subscription_date = #{orig_sub_date}"
      puts "Must sleep 3 seconds"
      sleep 3
      my_customer_email = request_customer_email(shopify_id, $my_get_header)

      puts "My customer_email = #{my_customer_email}" 
      puts "Must sleep for 3 secs again"
      sleep 3
      check_change_date_ok(current_month, my_subscription_id, orig_sub_date, new_date,$my_change_charge_header)
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
      alt_title = "#{current_month} VIP Box"
      orig_sub_date = ""
      my_subscription_id = ''

      my_subscriber_data = request_subscriber_id(shopify_id, $my_get_header, alt_title)
      orig_sub_date = my_subscriber_data['orig_sub_date']
      my_subscription_id = my_subscriber_data['my_subscription_id']
      puts "My Subscriber ID = #{my_subscription_id}, my original date = #{orig_sub_date}"


     puts "Must sleep for 3 secs"
     sleep 3
     
     my_customer_email = request_customer_email(shopify_id, $my_get_header)

     puts "My customer_email = #{my_customer_email}" 
     puts "Must sleep for 3 secs again"
     sleep 3
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
        
      
        if line['title'] == "Monthly Box" || line['title'] == alt_title
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

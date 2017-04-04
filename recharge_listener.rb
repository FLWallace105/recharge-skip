#recharge_listener.rb
require 'sinatra'
require 'httparty'
require 'dotenv'
require "resque"

class SkipIt < Sinatra::Base


configure do 
  
  enable :logging
  set :server, :puma
  Dotenv.load
  $recharge_access_token = ENV['RECHARGE_ACCESS_TOKEN']
  end



get '/' do
  puts "got here"
  'Hello world!'

end

post '/recharge' do
  puts "doing post stuff"
  puts params.inspect
  #'Hello Post'
  #should get here but doesnt sadly

end

get '/recharge' do
  '200'
  puts "doing GET stuff"
  puts params.inspect
  #'Hello Get unhappy here'
  shopify_id = params['shopify_id']
  puts shopify_id
  #stuff below for Heroku 
  uri2 = URI.parse(ENV["REDIS_URL"])
  REDIS = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)
  Resque.redis = REDIS
  
  
  Resque.enqueue(MyParamHandler, shopify_id)
  


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
    #get all charges to find right one
    charges_customer = HTTParty.get("https://api.rechargeapps.com/charges?customer_id=#{my_recharge_id}&status=queued", :headers => @my_header )
    all_charges = charges_customer.parsed_response

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
          subscription_date = my_subscription['subscription']['next_charge_scheduled_at']
          puts "subscription_date = #{subscription_date}"
          my_sub_date = DateTime.parse(subscription_date)
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


        end
        puts ""
        end
      
      
      end
      puts "Done with skipping this subscription, #{subscription_id}"
  end  
end



end

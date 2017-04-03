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
  #uri2 = URI.parse(ENV["REDIS_URL"])
  #REDIS = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)
  #Resque.redis = REDIS
  
  
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
    my_charges.each do |myc|
      puts myc.inspect
      puts myc['line_items'][0]['price'].inspect
      title = myc['line_items'][0]['title']
      subscription_id = myc['line_items'][0]['subscription_id']
      puts title
      current_month = Date.today.strftime("%B")
      alt_title = "#{current_month} VIP Box"
      puts alt_title
      if title == "Monthly Box" || title == alt_title
        #puts "Got here"
        customer_charge_id = myc['id']
        puts "customer_charge_id = #{customer_charge_id}"   
        puts "subscription_id = #{subscription_id}"
        end
      end
  end

end



end

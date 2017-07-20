#tag_customers.rb
require 'httparty'
require 'active_support/core_ext'
require 'pg'
require 'dotenv'




module TagCustomer
  class RechargeInfo

      def initialize
        Dotenv.load
        @my_token = ENV['RECHARGE_STAGING_ACCESS_TOKEN']
        uri = URI.parse(ENV['DATABASE_URL'])
        @conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
        
        @my_get_header =  {
            "X-Recharge-Access-Token" => "#{@my_token}"
        }

        @my_change_charge_header = {
            "X-Recharge-Access-Token" => "#{@my_token}",
            "Accept" => "application/json",
            "Content-Type" =>"application/json"
        }
        

      end


      def create_webhook(myip, action)
        puts myip
        if action == "create"
            url = "https://api.rechargeapps.com/webhooks"
            data = {
                "address" => "https://#{myip}/subscription_created",
                "topic" => "subscription/created"
            }
            data = data.to_json
        elsif action == "delete"
            url = "https://api.rechargeapps.com/webhooks"
            data = {
                "address" => "https://#{myip}/subscription_deleted",
                "topic" => "subscription/cancelled"
            }
            data = data.to_json
        end
        
        puts "data to create webhook = #{data}"
        my_webhook = HTTParty.post(url, :headers => @my_change_charge_header, :body => data )
        puts my_webhook.inspect

      end

      def list_webhook
        url = "https://api.rechargeapps.com/webhooks"
        webhook_list = HTTParty.get(url, :headers => @my_get_header)
        webhooks = webhook_list.parsed_response
        puts webhooks.inspect

      end

      def delete_webhook(*args)
        args.each do |myarg|
            url = "https://api.rechargeapps.com/webhooks/#{myarg}"
            puts "now url = #{url}"
            my_delete = HTTParty.delete(url, :headers => @my_change_charge_header)
            delete_info = my_delete.parsed_response
            puts delete_info.inspect
            end

      end



      def get_subscriptions
        num_subs = HTTParty.get("https://api.rechargeapps.com/subscriptions/count", :headers => @my_get_header)
        subs_raw = num_subs.parsed_response
        puts subs_raw
        subs_parsed = JSON.parse(subs_raw)
        total_subscribers = subs_parsed['count'].to_i
        puts total_subscribers
        page_size = 250
        
        pages = (total_subscribers/page_size.to_f).ceil
        puts "We have #{pages} pages to parse through"
        

        1.upto(pages) do |page|
            #GET /customers?limit=250 
            #GET /customers?page=2 
            
            subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions?limit=250&page=#{page}", :headers => @my_get_header)
            my_subscriptions = subscriptions.parsed_response
            #puts my_subscriptions
            single_subs = my_subscriptions['subscriptions']
            single_subs.each do |mysub|
                puts mysub.inspect
                end
            puts "-----------------------"
            puts "Done with page #{page}"
            sleep 4
            end


      end



    end
end
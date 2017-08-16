require './recharge_listener'
require 'resque/tasks'
#require 'standalone_migrations'
require_relative "tag_customers"
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'
#require './recharge_listener'
require_relative "influencer_reader"


#StandaloneMigrations::Tasks.load_tasks

desc "load influencer orders into database"
task :load_influencer do |t|
  InfluencerUtility::ReadInfluencer.new.readincodes

end

desc "create influencer orders from database to shopify"
task :create_influencer_order do |t|
  InfluencerUtility::ReadInfluencer.new.create_influencer_order
end  


desc "get customer subscriptions"
task :show_customers do |t|
  
  TagCustomer::RechargeInfo.new.get_subscriptions
end



desc "create subscription webhook, args create or delete only"
task :create_webhook, [:ngrok, :action] do |t, args|

  myngrok = args[:ngrok]
  myaction = args[:action]
  TagCustomer::RechargeInfo.new.create_webhook(myngrok, myaction)
end



desc "list webhooks"
task :list_webhooks do |t|
  TagCustomer::RechargeInfo.new.list_webhook
  end

desc "remove webhook"
task :remove_webhook, [:args] do |t, args|
  TagCustomer::RechargeInfo.new.delete_webhook(*args)
  end

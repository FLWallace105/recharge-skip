web: bundle exec rackup config.ru -p $PORT
worker: COUNT=4 QUEUE=* rake resque:work QUEUE='*'

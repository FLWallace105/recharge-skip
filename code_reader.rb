#code_reader.rb -- reads in access codes for ticket
require 'csv'
require 'dotenv'
require 'pg'
require 'sinatra/activerecord'

module TicketUtility
    class ReadTicket
        def initialize
            Dotenv.load
            #nothing for now
        end

        def readincodes
            uri = URI.parse(ENV['DATABASE_URL'])
            conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
            my_insert = "insert into tickets (influencer_code) values ($1)"
            conn.prepare('statement1', "#{my_insert}")
            CSV.foreach('100_unique_codes.csv') do |row|
                #puts row[0]
                mycode = row[0].to_str
                puts mycode
                conn.exec_prepared('statement1', [mycode])
            end
        end

        


    end
end
TicketUtility::ReadTicket.new.readincodes

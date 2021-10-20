# frozen_string_literal: true

require('kafka')
require('mysql2')
require('logger')
require('byebug')
require('active_record')
require('standalone_migrations')
require_relative('./replicate')
require_relative('../config/connect')
require_relative('../models/truck')
include(Replicate)
retries ||= 3

def main
  logger = Logger.new(STDOUT)
  #* 1: Making connection with the replia DB
  ActiveRecord::Base.establish_connection(Connect.load_db_config['replica_db'])
  begin
    ActiveRecord::Base.connection.execute('SET GLOBAL FOREIGN_KEY_CHECKS=0;')
  rescue StandardError
    nil
  end #* mySQL

  #* 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  kafka = Kafka.new(['localhost:9092'])
  consumer_trucks = kafka.consumer(group_id: 'group_trucks')
  consumer_trucks.subscribe('dbserver1.dipper_development.trucks',
                            start_from_beginning: false)
  Replicate.replicating_template('trucks', consumer_trucks, logger)
rescue StandardError => e
  logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  main unless (retries -= 1).zero? #* 3 retries
end

main

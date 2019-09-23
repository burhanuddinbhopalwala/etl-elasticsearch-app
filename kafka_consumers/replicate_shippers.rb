# frozen_string_literal: true

require("kafka")
require("mysql2")
require("logger")
require("byebug")
require("active_record")
require("standalone_migrations")
require_relative("./replicate.rb")
require_relative("../config/connect.rb")
require_relative("../models/shipper.rb")
include(Replicate)
retries ||= 3

def main
  logger = Logger.new(STDOUT)
  #* 1: Making shnection with the replia DB
  ActiveRecord::Base.establish_connection(Connect.load_db_config["replica_db"])
  ActiveRecord::Base.connection.execute("SET GLOBAL FOREIGN_KEY_CHECKS=0;") rescue nil #* mySQL

  #* 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  kafka = Kafka.new(["localhost:9092"])
  consumer_shippers = kafka.consumer(group_id: "group_shippers")
  consumer_shippers.subscribe("dbserver1.dipper_development.shippers", start_from_beginning: false)
  Replicate.replicating_template("shippers", consumer_shippers, logger)
rescue StandardError => e
  logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  main unless ($retries -= 1).zero? #* 3 retries
end

main

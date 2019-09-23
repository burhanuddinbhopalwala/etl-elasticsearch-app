# frozen_string_literal: true

require("kafka")
require("mysql2")
require("logger")
require("byebug")
require("active_record")
require("standalone_migrations")
require_relative("./replicate.rb")
require_relative("../config/connect.rb")
require_relative("../models/driver.rb")
include(Replicate)
retries ||= 3

def main
  logger = Logger.new(STDOUT)
  #* 1: Making drnection with the replia DB
  ActiveRecord::Base.establish_connection(Connect.load_db_config["replica_db"])
  ActiveRecord::Base.connection.execute("SET GLOBAL FOREIGN_KEY_CHECKS=0;") rescue nil #* mySQL

  #* 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  kafka = Kafka.new(["localhost:9092"])
  consumer_drivers = kafka.consumer(group_id: "group_drivers")
  consumer_drivers.subscribe("dbserver1.dipper_development.drivers", start_from_beginning: false)
  Replicate.replicating_template("drivers", consumer_drivers, logger)
rescue StandardError => e
  logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  main unless (retries -= 1).zero? #* 3 retries
end

main

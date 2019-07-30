# frozen_string_literal: true

require("kafka")
require("mysql2")
require("logger")
require("byebug")
require("active_record")
require("standalone_migrations")
require_relative("./replicate.rb")
require_relative("../config/connect.rb")
require_relative("../models/alert_subscription.rb")
include(Replicate)
retries ||= 3

def main
  logger = Logger.new(STDOUT)
  #* 1: Making connection with the replia DB
  ActiveRecord::Base.establish_connection(Connect.load_db_config["replica_db"])
  ActiveRecord::Base.connection.execute("SET GLOBAL FOREIGN_KEY_CHECKS=0;") #* mySQL

  #* 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  kafka = Kafka.new(["localhost:9092"])
  consumer_alert_subscriptions = kafka.consumer(group_id: "group_alert_subscriptions")
  consumer_alert_subscriptions.subscribe("dbserver1.dipper_development.alert_subscriptions", start_from_beginning: false)
  Replicate.replicating_template("alert_subscriptions", consumer_alert_subscriptions, logger)
rescue StandardError => e
  logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  main unless (retries -= 1).zero? #* 3 retries
end

main

# frozen_string_literal: true

require("kafka")
require("mysql2")
require("logger")
require("byebug")
require("active_record")
require("standalone_migrations")
require_relative("../config/connect.rb")
retries ||= 3

def main
  logger = Logger.new(STDOUT)
  #* 1: Making connection with the replia DB
  ActiveRecord::Base.establish_connection(Connect.load_db_config["replica_db"])
  ActiveRecord::Base.connection.execute("SET GLOBAL FOREIGN_KEY_CHECKS=0;") rescue nil #* mySQL

  #* 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  kafka = Kafka.new(["localhost:9092"])
  consumer_ddl = kafka.consumer(group_id: "group_dbserver1")
  consumer_ddl.subscribe("dbserver1", start_from_beginning: false)
  replicating_ddl(consumer_ddl, logger)
rescue StandardError => e
  logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  main unless (retries -= 1).zero? #* 3 retries
end

def replicating_ddl(kafka, logger)
  logger.info("IN THREAD_DDL")
  kafka.each_message do |message|
    message = JSON.parse(message.value)
    next if message["payload"].nil?

    ddl_sqls = message["payload"]["ddl"].to_s.split(",")
    ddl_sqls.each do |ddl_sql|
      begin
        ActiveRecord::Base.connection.execute(ddl_sql + ";")
      rescue StandardError => e
        logger.error("REPLICATION ERROR FOR DDL: #{ddl_sql}, DUE TO: #{e.message}")
      end
    end
    logger.info("REPLICATION DONE FOR DDL: #{ddl_sqls}")
  end
end

main

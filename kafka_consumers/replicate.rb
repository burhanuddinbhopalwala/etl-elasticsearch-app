# frozen_string_literal: true

require("kafka")
require("mysql2")
require("logger")
require("byebug")
require("require_all")
require("active_record")
require("elasticsearch")
require("standalone_migrations")
require_relative("../config/connect.rb")
require_all("../models/")

module Replicate
  def correct_all_datetime_formats(payload_after, _logger)
    payload_after.keys.each do |key|
      next unless key.include?("date") || key.include?("time") || key.include?("eta") || key.include?("delete")
      next if payload_after[key].nil?

      begin
        DateTime.parse(payload_after[key])
        next
      rescue StandardError => e #* ArgumentError
        # logger.error("DATETIME PARSE ERROR CORRECTING FOR #{payload_after[key]}")
        payload_after[key] = Time.at((payload_after[key].to_i / 1000)).to_s
        # logger.info("CORRECT DATETIME #{payload_after[key]}")
      end
    end
  end

  def replicating_template(table_name, consumer, logger)
    model = table_name.classify.constantize
    print_table_name = table_name.upcase
    consumer.each_message do |message|
      message = JSON.parse(message.value)
      next if message["payload"].nil?

      master_operation = message["payload"]["op"]
      payload_before = message["payload"]["before"]
      payload_after = message["payload"]["after"]
      unless payload_after.nil?
        correct_all_datetime_formats(payload_after, logger)
        payload_after.delete("created_at")
        payload_after.delete("updated_at")
      end
      if master_operation == "c"
        ar = model.new(payload_after)
        #* ar: ActiveRecord
        begin
          ar.save!
          logger.info("#{print_table_name} INSERTED FOR ID: #{ar.id}")
        rescue StandardError => e
          #* Most probably because of refrential integrity
          logger.error("#{print_table_name} REPLICATION FAILED: BECAUSE #{e.message} FOR ID #{ar.id}")
          next
        end
      elsif master_operation == "u"
        ar = model.find_by_id(payload_after["id"])
        unless ar.present?
          ar = model.new(payload_after)
          begin
            ar.save!
          rescue StandardError
            next
          end #* For processing create events with errors, then update
          logger.info("#{print_table_name} NOT FOUND WHILE UPDATING HENCE CREATED FOR MASTER ID: #{payload_after['id']}")
          next
        end
        payload_after.delete("id")
        begin
          ar.update!(payload_after)
          logger.info("#{print_table_name} UPDATED FOR ID: #{ar.id}")
        rescue StandardError => e
          #* Most probably because of refrential integrity
          logger.error("#{print_table_name} REPLICATION FAILED: BECAUSE #{e.message} FOR ID #{ar.id}")
          next
        end
      elsif master_operation == "d"
        ar = model.find_by_id(payload_before["id"])
        unless ar.present?
          logger.info("#{print_table_name} NOT FOUND WHILE DELETION FOR MASTER ID: #{payload_before['id']}")
          next
        end
        begin
          ar.destroy!
          logger.info("#{print_table_name} DELETED FOR ID: #{ar.id}")
        rescue StandardError => e
          #* Most probably because of refrential integrity
          logger.error("#{print_table_name} REPLICATION FAILED: BECAUSE #{e.message} FOR ID #{ar.id}")
          next
        end
      end
    end
  end

  # def main
  #   logger = Logger.new(STDOUT)
  #   # 1: Making connection with the replia DB
  #   ActiveRecord::Base.establish_connection(Connect.load_db_config["replica_db"])
  #   ActiveRecord::Base.connection.execute("SET GLOBAL FOREIGN_KEY_CHECKS=0;") # mySQL

  #   # 2: Kafka consumer, extracting messasges topic wise and updating on the DB
  #   kafka = Kafka.new(["localhost:9092"])

  #   # 3: Making consumers
  #   consumer_users = kafka.consumer(group_id: "group_users")
  #   consumer_shippers = kafka.consumer(group_id: "group_shippers")
  #   consumer_truckers = kafka.consumer(group_id: "group_truckers")
  #   consumer_consigners = kafka.consumer(group_id: "group_consigners")
  #   consumer_drivers = kafka.consumer(group_id: "group_drivers")
  #   consumer_trucks = kafka.consumer(group_id: "group_trucks")
  #   consumer_consigner_trips = kafka.consumer(group_id: "group_consigner_trips")
  #   consumer_route_pois = kafka.consumer(group_id: "group_route_pois")
  #   consumer_trip_configs = kafka.consumer(group_id: "group_trip_configs")
  #   consumer_alert_subscriptions = kafka.consumer(group_id: "group_alert_subscriptions")

  #   # 4: Consumer subscription
  #   consumer_users.subscribe("dbserver1.dipper_development.users", start_from_beginning: false)
  #   consumer_shippers.subscribe("dbserver1.dipper_development.shippers", start_from_beginning: false)
  #   consumer_truckers.subscribe("dbserver1.dipper_development.truckers", start_from_beginning: false)
  #   consumer_consigners.subscribe("dbserver1.dipper_development.consigners", start_from_beginning: false)
  #   consumer_drivers.subscribe("dbserver1.dipper_development.drivers", start_from_beginning: false)
  #   consumer_trucks.subscribe("dbserver1.dipper_development.trucks", start_from_beginning: false)
  #   consumer_consigner_trips.subscribe("dbserver1.dipper_development.consigner_trips", start_from_beginning: false)
  #   consumer_route_pois.subscribe("dbserver1.dipper_development.route_pois", start_from_beginning: false)
  #   consumer_trip_configs.subscribe("dbserver1.dipper_development.trip_configs", start_from_beginning: false)
  #   consumer_alert_subscriptions.subscribe("dbserver1.dipper_development.alert_subscriptions", start_from_beginning: false)

  #   # 5: Threading according to the priority, main thread @0
  #   thread_users = Thread.new { replicating_template("users", consumer_users, logger) }
  #   thread_shippers = Thread.new { replicating_template("shippers", consumer_shippers, logger) }
  #   thread_truckers = Thread.new { replicating_template("truckers", consumer_truckers, logger) }
  #   thead_consigners = Thread.new { replicating_template("consigners", consumer_consigners, logger) }
  #   thread_drivers = Thread.new { replicating_template("drivers", consumer_drivers, logger) }
  #   thread_trucks = Thread.new { replicating_template("trucks", consumer_trucks, logger) }
  #   thread_consigner_trips = Thread.new { replicating_template("consigner_trips", consumer_consigner_trips, logger) }
  #   thread_route_pois = Thread.new { replicating_template("route_pois", consumer_route_pois, logger) }
  #   thread_trip_configs = Thread.new { replicating_template("trip_configs", consumer_trip_configs, logger) }
  #   thread_alert_subscriptions = Thread.new { replicating_template("alert_subscriptions", consumer_alert_subscriptions, logger) }

  #   # 6:Running threads
  #   thread_users.join
  #   thread_shippers.join
  #   thread_truckers.join
  #   thead_consigners.join
  #   thread_drivers.join
  #   thread_trucks.join
  #   thread_consigner_trips.join
  #   thread_route_pois.join
  #   thread_trip_configs.join
  #   thread_alert_subscriptions.join
  # rescue StandardError => e
  #   logger.error("REPLICATION FAILING: Because of #{e.message}, RESTARTING")
  #   main unless (retries -= 1).zero? # 3 retries
  # end
end

#main

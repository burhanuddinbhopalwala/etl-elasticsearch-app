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
require_relative("../models/consigner_trip.rb")

def convert_to_datatype(payload, key)
  (payload.delete(key) && return) if payload[key].nil?
  return if key.include?("code") #* DEFAULT STRING/ TEXT MAPPING

  #* TRYING FOR DATE PARSING
  if key.include?("eta") || key.include?("date") || key.include?("time")
    (payload[key] = DateTime.parse(payload[key])) && return
  end
rescue StandardError => e
  begin
    (payload.delete(key) && return) if key.include?("eta") || key.include?("date") || key.include?("time")
    #* TRYING FOR INTEGER PARSING
    raise(ArgumentError, "invalid float") unless Integer(payload[key])

    (payload[key] = Integer(payload[key])) && return
  rescue StandardError => e
    #* TRYING FOR FLOAT PARSING
    begin
      raise(ArgumentError, "invalid float") unless Float(payload[key])

      (payload[key] = Float(payload[key])) && return
    rescue StandardError => e
      #* DEFAULT STRING/ TEXT
      return
    end
  end
end

def process_dynamic_string(payload, logger)
  unless payload.blank?
    begin
      payload = JSON.parse(payload)
      payload.keys
    rescue StandardError => e
      logger.error("JSON PARSE ERROR: #{e.message}")
      begin
        payload = eval(payload)
        payload.keys
        logger.info("RESOLVED JSON PARSE ERROR")
      rescue StandardError => e
        logger.error("ERROR: #{e.message}")
        begin
          if e.message.include?("no implicit conversion of Array into String")
            payload = payload[0]
            payload.keys
            logger.info("RESOLVED JSON PARSE ERROR")
          else
            raise("ERROR PARSING")
          end
        rescue StandardError
          logger.error("ERROR PARSING, REPLACING DATA_STRING TO EMPTY HASH")
          payload = {}
        end
      end
    end
    (payload = payload["consigner_trip"]) if payload.key?("consigner_trip")
    payload.keys.each do |key|
      convert_to_datatype(payload, key)
    end
    payload["iron_quantity_kg"] = rand(100)
    begin
      if payload.keys.any? { |key| key.to_s.match(/lat/) } &&
         payload.keys.any? { |key| key.to_s.match(/long/) }
        payload["destination_lat_lon"] = {}
        payload["destination_lat_lon"]["lat"] = payload["destination_latitude"].to_f
        payload["destination_lat_lon"]["lon"] = payload["destination_longitude"].to_f
        payload.delete("destination_latitude")
        payload.delete("destination_longitude")
      end
    rescue StandardError => e
      logger.error("LAT LONG PARSE ERROR")
    end
  end
  payload
end

def replicating_consigner_trips_to_elasticsearch(kafka, client, logger)
  logger.info("IN THREAD_ELASTICSEARCH_CONSINER_TRIPS")
  slot = 0
  count = 0
  final_bulk_payload = []
  kafka.each_message do |message|
    message = JSON.parse(message.value)
    next if message["payload"].nil?

    payload_before = message["payload"]["before"]
    payload_after = message["payload"]["after"]
    if payload_after.nil?
      begin
        client.delete(index: "master_index", type: "master_type", id: payload_before["id"])
      rescue StandardError => e
        logger.error("ETL INDEXING ERROR FOR DELETING THE DOC, FOR #{payload_before['id']}
          BECAUSE: #{e.message}")
      end
      next
    end
    begin
      payload = payload_after
      data_string = payload["data_string"]
      payload["data_string"] = process_dynamic_string(data_string, logger) unless data_string.nil?
      payload["is_active"] == 1 ? (payload["is_active"] = true) : (payload["is_active"] = false)
      #* CUSTOM FIELDS
      payload["loading_in_out_mins_diff"] = if payload["loading_in_time"].nil? || payload["loading_out_time"].nil?
                                              0
                                            else
                                              ((payload["loading_out_time"] - payload["loading_in_time"]) / 60).to_i
                                            end
      payload["unloading_in_out_mins_diff"] = if payload["unloading_in_time"].nil? || payload["unloading_out_time"].nil?
                                                0
                                              else
                                                ((payload["unloading_out_time"] - payload["unloading_in_time"]) / 60).to_i
                                              end
      begin
        begin
          if payload.keys.any? { |key| key.to_s.match(/consigner_lat/) } &&
             payload.keys.any? { |key| key.to_s.match(/consigner_long/) }
            payload["consigner_lat_lon"] = {}
            payload["consigner_lat_lon"]["lat"] = payload["consigner_lat"].to_f
            payload["consigner_lat_lon"]["lon"] = payload["consigner_long"].to_f
            payload.delete("consigner_lat")
            payload.delete("consigner_long")
          end
          if payload.keys.any? { |key| key.to_s.match(/consignee_lat/) } &&
             payload.keys.any? { |key| key.to_s.match(/consignee_long/) }
            payload["consignee_lat_lon"] = {}
            payload["consignee_lat_lon"]["lat"] = payload["consignee_lat"].to_f
            payload["consignee_lat_lon"]["lon"] = payload["consignee_long"].to_f
            payload.delete("consignee_lat")
            payload.delete("consignee_long")
          end
        rescue StandardError => e
          logger.error("ETL INDEXING ERROR LAT LONG PARSE ERROR FOR #{payload['id']}")
        end
        temp_hash = { index:  { _index: "master_index", _type: "master_type", _id: payload["id"], data: payload } }
        final_bulk_payload << temp_hash
        count += 1
        logger.info("WAITING FOR 500 MESSAGES FOR BULK INDEX, RECEIVED #{count}")
        if count == 500
          logger.info("RECEIVED 500 MESSAGES, BULK INDEX STARTED")
          begin
            client.bulk(body: final_bulk_payload)
          rescue StandardError
            logger.info("BULK STORE ERROR")
          end
          final_bulk_payload.clear
          count = 0
          slot += 1
          logger.info("BULK INDEX DONE FOR 500 SLOT: #{slot}")
        end
      rescue StandardError => e
        logger.error("ETL INDEXING ERROR FOR ID: #{payload['id']} BECAUSE: #{e.message}")
        next
      end
    rescue StandardError => e
      logger.error("ELASTICSEARCH ERROR INDEXING FROM ETL BECAUSE: #{e.message} FOR ID: #{payload_after['id']}")
      next
    end
    logger.info("ELASTICSEARCH INDEXED FROM ETL WITH ID: #{payload_after['id']}")
  end
end

def fetching_data_from_kafka(client, logger)
  logger.info("STARTED MAKING CONNECTION FROM KAFKA")
  kafka = Kafka.new(["localhost:9092"])
  es_consumer_consigner_trips = kafka.consumer(group_id: "group_es_consigner_trips")
  es_consumer_consigner_trips.subscribe("dbserver1.dipper_development.consigner_trips", start_from_beginning: false)
  logger.info("FETCHING DATA FROM KAFKA")
  begin
    replicating_consigner_trips_to_elasticsearch(es_consumer_consigner_trips, client, logger)
  rescue StandardError => e
    logger.error("STOPPING ETL ERROR FOR ELASTICSEARCH INDEXING BECAUSE: #{e.message}")
  end
rescue StandardError => e
  logger.error("ERROR IN CONNECTING FROM KAFKA BECAUSE: #{e.message}")
  nil
end

def main
  logger = Logger.new(STDOUT)
  #* 1: Making connection with the Master DB for old records
  logger.info("CREATING MASTER DB CONNECTION")
  ActiveRecord::Base.establish_connection(Connect.load_db_config["master_db"])

  #* 2: Making ES Client
  logger.info("CREATING ELASTICSEARCH CLIENT")
  elasticsearch_config = Connect.load_elasticsearch_config["production"]
  client = Elasticsearch::Client.new(
    url: "https://#{elasticsearch_config['username']}:#{elasticsearch_config['password']}@#{elasticsearch_config['host']}:#{elasticsearch_config['port']}",
    log: true
  )
  
  #* 3: Fetching data from kafka and transforming
  logger.info("STARTED GETTING DATA FROM ETL PIPELINE")
  fetching_data_from_kafka(client, logger)
rescue StandardError => e
  logger.error("ETL ES INDEXING FAILING: BECUASE OF: #{e.message}")
end

main

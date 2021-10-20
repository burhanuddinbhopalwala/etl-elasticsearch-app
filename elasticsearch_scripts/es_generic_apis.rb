# frozen_string_literal: true

#* 1: Importing require's
require('kafka')
require('mysql2')
require('logger')
require('byebug')
require('require_all')
require('active_record')
require('elasticsearch')
require('standalone_migrations')
require_relative('../config/connect')
require_relative('../models/consigner_trip')

def get_aggregation_by_consigner_code(consigner_code = 'HZL', field = 'iron_quantity_kg', op = 'avg')
  tries ||= 3
  logger = Logger.new(STDOUT)
  #* 2: Making ES Client
  logger.info('CREATING ELASTICSEARCH CLIENT')
  elasticsearch_config = Connect.load_elasticsearch_config['production']
  client = Elasticsearch::Client.new(
    url: "https://#{elasticsearch_config['username']}:#{elasticsearch_config['password']}@#{elasticsearch_config['host']}:#{elasticsearch_config['port']}",
    log: true
  )
  client.indices.refresh(index: 'master_index')
  #* 3: Started fetching results
  logger.info("ES API FETCHING STARTED AT #{(Time.now + (5.5 * 60 * 60)).to_s.sub!(
    '+0000', ''
  )}")
  begin
    Timeout.timeout(50) do
      if op == 'avg'
        @response = client.search(index: 'master_index',
                                  body: {
                                    query: { match: { consigner_code: consigner_code } },
                                    aggregations: { "result": { "avg": { "field": field } } }
                                  })
      elsif op == 'sum'
        @response = client.search(index: 'master_index',
                                  body: {
                                    query: { match: { consigner_code: consigner_code } },
                                    aggregations: { "result": { "sum": { "field": field } } }
                                  })
      elsif op == 'min'
        @response = client.search(index: 'master_index',
                                  body: {
                                    query: { match: { consigner_code: consigner_code } },
                                    aggregations: { "result": { "min": { "field": field } } }
                                  })
      elsif op == 'max'
        @response = client.search(index: 'master_index',
                                  body: {
                                    query: { match: { consigner_code: consigner_code } },
                                    aggregations: { "result": { "max": { "field": field } } }
                                  })
      end
    end
  rescue StandardError => e
    retry unless (tries -= 1).zero?
    logger.info("ES API ERROR BECAUSE OF #{e.message} AT #{(Time.now + (5.5 * 60 * 60)).to_s.sub!(
      '+0000', ''
    )}")
    # SendMail.mail_for("ES API error, error: #{error.message().to_s()}")
    exit
  end
  #* 4: Sending response
  logger.info("ES RESULT FOR #{consigner_code}, #{field}, #{op}: #{@response['aggregations']['result']['value']}")
  @response['aggregations']['result']
end

#* 5: Calling API
response = get_aggregation_by_consigner_code('HZL', 'iron_quantity_kg', 'avg')
puts(response)
get_aggregation_by_consigner_code('HZL', 'iron_quantity_kg', 'sum')
get_aggregation_by_consigner_code('HZL', 'iron_quantity_kg', 'min')
get_aggregation_by_consigner_code('HZL', 'iron_quantity_kg', 'max')

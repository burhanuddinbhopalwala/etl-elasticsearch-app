# frozen_string_literal: true

class Connect
  def self.load_db_config
    #* db_configuration_file = File.join(File.expand_path('..', __FILE__), "..", "db", "database.yaml")
    db_configuration_file = File.join(File.expand_path(__dir__),
                                      'database.yaml')
    YAML.load(File.read(db_configuration_file))
  end

  def self.load_elasticsearch_config
    elasticsearch_configuration_file = File.join(File.expand_path(__dir__),
                                                 'elasticsearch.yaml')
    YAML.load(File.read(elasticsearch_configuration_file))
  end
end

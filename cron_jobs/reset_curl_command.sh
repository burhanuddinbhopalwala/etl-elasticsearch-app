#!/bin/sh
echo "CHECKING FOR CURL"
connectors=$(curl localhost:8083/connectors)
connectorsLength=${#connectors[@]} 
# if [ "$connectorsLength" -eq 0 ];
# then
    echo "CONNECTOR NOT EXISTS, CURL POST COMMAND!"
	curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{ "name": "dipper-connector", "config": { "connector.class": "io.debezium.connector.mysql.MySqlConnector", "tasks.max": "1", "database.hostname": "35.154.141.143", "database.port": "3306", "database.user": "kafka_connect", "database.password": "debezium_etl", "database.server.id": "184054", "database.server.name": "dbserver1", "database.whitelist": "dipper_development", "table.whitelist":"dipper_development.users,dipper_development.shippers,dipper_development.truckers,dipper_development.consigners,dipper_development.drivers,dipper_development.trucks,dipper_development.consigner_trips,dipper_development.route_pois,dipper_development.trip_configs,dipper_development.alert_subscriptions,dipper_development.poi_configs,dipper_development.default_poi_configs", "database.history.kafka.bootstrap.servers": "kafka:9092", "database.history.kafka.topic": "dbhistory.dipper_development", "event.deserialization.failure.handling.mode": "ignore", "inconsistent.schema.handling.mode": "ignore", "snapshot.mode": "schema_only"}}'
# else
#     echo "CONNECTOR EXISTS!"
# fi


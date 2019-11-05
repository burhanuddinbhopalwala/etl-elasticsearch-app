#!/usr/bin/perl

use strict;
use warnings;
use Proc::ProcessTable;

my $table = Proc::ProcessTable->new;

my $found_mysqld = 0;
my $found_docker_zookeeper = 0;
my $found_docker_kafka = 0;
my $found_docker_kafka_connect = 0;
my $found_ddls_etl = 1;
my $found_elasticsearch_etl = 0;
my $found_users = 0;
my $found_shippers = 0;
my $found_consigners = 0;
my $found_truckers = 0;
my $found_drivers = 0;
my $found_trucks = 0;
my $found_consigner_trips = 0;
my $found_route_pois = 0;
my $found_trip_configs = 0;
my $found_alert_subscriptions = 0;
my $found_poi_configs = 0;
my $found_default_poi_configs = 0;

print("\n------------Check process script started---------");
for my $process (@{$table->table}) {
  # print("\n", $process->fname, $process->cmndline; # For checking exisiting processes
  if($process->cmndline =~ /mysqld.pid/) {
    $found_mysqld = 1;
    print("\n Found mysql at: ", "".localtime(time));
  }

  if($process->cmndline =~ /docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 2181/) {
    $found_docker_zookeeper = 1;
    print("\n Found zookeeper at: ", "".localtime(time));
  }

  if($process->cmndline =~ /docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 9092/) {
    $found_docker_kafka = 1;
    print("\n Found kafka at: ", "".localtime(time));
  }

  if($process->cmndline =~ /docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8083/) {
    $found_docker_kafka_connect = 1;
    print("\n Found kafka-connect at: ", "".localtime(time));
  }

  if($process->cmndline =~ /replicate_ddls.rb/) {
    $found_ddls_etl = 1;
    print("\n Found ddls_etl at: ", "".localtime(time));
  }

  if($process->cmndline =~ /elasticsearch_etl_v2.rb/) {
    $found_elasticsearch_etl = 1;
    print("\n Found elasticsearch_etl at: ", "".localtime(time));
  }

  if($process->cmndline =~ /users.rb/) {
    $found_users = 1;
    print("\n Found users at: ", "".localtime(time));
  }

  if($process->cmndline =~ /shippers.rb/) {
    $found_shippers = 1;
    print("\n Found shippers at: ", "".localtime(time));
  }

  if($process->cmndline =~ /consigners.rb/) {
    $found_consigners = 1;
    print("\n Found consigners at: ", "".localtime(time));
  }

  if($process->cmndline =~ /truckers.rb/) {
    $found_truckers = 1;
    print("\n Found truckers at: ", "".localtime(time));
  }

  if($process->cmndline =~ /drivers.rb/) {
    $found_drivers = 1;
    print("\n Found drivers at: ", "".localtime(time));
  }

  if($process->cmndline =~ /trucks.rb/) {
    $found_trucks = 1;
    print("\n Found trucks at: ", "".localtime(time));
  }

  if($process->cmndline =~ /consigner_trips.rb/) {
    $found_consigner_trips = 1;
    print("\n Found consigner_trips at: ", "".localtime(time));
  }

  if($process->cmndline =~ /route_pois.rb/) {
    $found_route_pois = 1;
    print("\n Found route_pois at: ", "".localtime(time));
  }

  if($process->cmndline =~ /trip_configs.rb/) {
    $found_trip_configs = 1;
    print("\n Found trip_configs at: ", "".localtime(time));
  }

  if($process->cmndline =~ /alert_subscriptions.rb/) {
    $found_alert_subscriptions = 1;
    print("\n Found alert_subscriptions at: ", "".localtime(time));
  }

  if($process->cmndline =~ /poi_configs.rb/) {
    $found_poi_configs = 1;
    print("\n Found poi_configs at: ", "".localtime(time));
  }

  if($process->cmndline =~ /default_poi_configs.rb/) {
    $found_default_poi_configs = 1;
    print("\n Found default_poi_configs at: ", "".localtime(time));
  }
}

#* STARTING/ RESTARING MYSQL SERVICE
if($found_mysqld == 0) {
  print("\n Trying restarting mysql service at: ", "".localtime(time));
  system("sudo service mysql restart");
  print("\n Restarted mysql service at: ", "".localtime(time));
  system("sleep 15s");
}

sub restartingETL() {
  #* 1: STOPPING RUNNING DOCKERS AND EXISTING KAFKA CONSUMERS 
  print("\n Stopping and removing existing dockers first");
  system("cd ~/burhanuddin_etl_and_elasticsearch_project && sudo docker-compose down && sudo docker system prune --force");
  system("ps -aux | grep '[.]rb' | awk '{print \$2}' | xargs -rn 1 kill -9");
  
  #* 2: CLEANING ZOOKEEPER AND KAFKA LOGS
  print("\n Clearing zookeeper and kafka data");
  system("cd /vol/zookeeper/data/ && sudo rm -rf *");
  system("cd /vol/zookeeper/txns/ && sudo rm -rf *");
  system("cd /vol/kafka/data/ && sudo rm -rf *");
  system("cd /vol/kafka/logs/ && sudo rm -rf *");
  
  #* 3: RESTARTING ALL THE DOCKERS 
  print("\n Trying restarting all dockers at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project && sudo docker-compose up -d");
  print("\n Restarted all the dockers at: ", "".localtime(time));
  system("sleep 2m");
  
  #* 4: DEBEZIUM CURL COMMAND
  system("./reset_curl_command.sh");
  system("sleep 15s");
  
  #* 5: RESTARTING ALL KAFKA CONSUMERS 
  #* WARNING: COMMENT BELOW 3 LINES OF DDL KAFKA CONSUMER WHILE RE/RUNNING ETL FIRST TIME FOR "snapshot.mode": "initial"
  # print("\n Trying restarting ddls_etl at: ", "".localtime(time));
  # system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_ddls.rb >> ../logs/replicate_ddls.log &");
  # print("\n Restarted ddls_etl at: ", "".localtime(time));
  print("\n Trying restarting elasticsearch_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/elasticsearch_scripts/ && nohup ruby elasticsearch_etl_v2.rb >> ../logs/elasticsearch_etl.log &");
  print("\n Restarted elasticsearch_etl at: ", "".localtime(time));
  
  print("\n Trying restarting users_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_users.rb >> ../logs/replicate_users.log &");
  print("\n Restarted users_etl at: ", "".localtime(time));
  
  print("\n Trying restarting shippers_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_shippers.rb >> ../logs/replicate_shippers.log &");
  print("\n Restarted shippers_etl at: ", "".localtime(time));
  
  print("\n Trying restarting consigners_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_consigners.rb >> ../logs/replicate_consigners.log &");
  print("\n Restarted consigners_etl at: ", "".localtime(time));
  
  print("\n Trying restarting truckers_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_truckers.rb >> ../logs/replicate_truckers.log &");
  print("\n Restarted truckers at: ", "".localtime(time));
  
  print("\n Trying restarting drivers_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_drivers.rb >> ../logs/replicate_drivers.log &");
  print("\n Restarted drivers_etl at: ", "".localtime(time));
  
  print("\n Trying restarting trucks_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_trucks.rb >> ../logs/replicate_trucks.log &");
  print("\n Restarted trucks_etl at: ", "".localtime(time));
  
  print("\n Trying restarting consigner_trips_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_consigner_trips.rb >> ../logs/replicate_consigner_trips.log &");
  print("\n Restarted consigner_trips_etl at: ", "".localtime(time));
  
  print("\n Trying restarting route_pois_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_route_pois.rb >> ../logs/replicate_route_pois.log &");
  print("\n Restarted route_pois_etl at: ", "".localtime(time));
  
  print("\n Trying restarting trip_configs_etl at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_trip_configs.rb >> ../logs/replicate_trip_configs.log &");
  print("\n Restarted trip_configs_etl at: ", "".localtime(time));
  
  print("\n Trying restarting alert_subscriptions at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_alert_subscriptions.rb >> ../logs/replicate_alert_subscriptions.log &");
  print("\n Restarted alert_subscriptions_etl at: ", "".localtime(time));

  print("\n Trying restarting poi_configs at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_poi_configs.rb >> ../logs/replicate_poi_configs.log &");
  print("\n Restarted poi_configs_etl at: ", "".localtime(time));

  print("\n Trying restarting default_poi_configs at: ", "".localtime(time));
  system("cd ~/burhanuddin_etl_and_elasticsearch_project/kafka_consumers/ && nohup ruby replicate_default_poi_configs.rb >> ../logs/replicate_default_poi_configs.log &");
  print("\n Restarted default_poi_configs_etl at: ", "".localtime(time));
}

#* STARTING ALL THE DOCKERS
if($found_docker_zookeeper == 0 || $found_docker_kafka == 0 || $found_docker_kafka_connect == 0 ||
$found_ddls_etl == 0 || $found_elasticsearch_etl == 0 || $found_users == 0 || $found_shippers == 0 || 
$found_consigners == 0 || $found_truckers == 0 || $found_drivers == 0 || $found_trucks == 0 || 
$found_consigner_trips == 0 || $found_route_pois == 0 || $found_trip_configs == 0 || 
$found_alert_subscriptions == 0) {
  print("\n Restarting entire ETL");
  restartingETL();
  print("\n Restarted entire ETL");
}

#* FOR MAIL TRACKING
#my($mailprog) = "/usr/sbin/sendmail";
#my($from_address) = "support@xyz.com";
#my($to_address) = "b.bhopalwala@xyz.com";
#open (MAIL, "|$mailprog -t $to_address") || die "Can't open $mailprog!\n";
#print MAIL "To: $to_address\n";
#print MAIL "From: $from_address\n";
#print MAIL "Subject: http://ip_address Script Mail - ";
#print MAIL "test";
#print MAIL "Body";
#close (MAIL);

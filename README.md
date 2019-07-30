# etl-elasticsearch-app

Extract Transform Load (ETL) pipeline through debezium (cdc), corresponding connector, kafka and kafka-connect, for repliacting the data in replica DB and into Elasticsearch, for real time streaming and event processing and data visualization through kibana. #etl #debezium #kafka #kafka-connect #mySQL #elasticsearch #kibana #ELK stack

### Implementation includes:

![ScreenShot](/data/images/ksql-debezium-es.png)

## Getting started

1: Install [docker](https://docs.docker.com/install/) 

2: Install [zookeeper + kafka + kakfa-connect](https://debezium.io/docs/tutorial/)

2: Then, simply follow setup.txt for getting started

## Usage

You can find the reference to the attached kafka consumers, to write your own kafka consumers and start etl process as per your needs

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. Please make sure to update tests as appropriate.

## Authors

-   **Burhanuddin Bhopalwala** - _Initial work_ - [GitHub](https://github.com/burhanuddinbhopalwala)

## Acknowledgments

-   https://www.docker.com/
-   https://kafka.apache.org/

## License

[MIT](https://choosealicense.com/licenses/mit/)

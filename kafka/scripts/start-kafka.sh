#!/bin/sh

# Optional ENV variables:
# * ADVERTISED_HOST: the external ip for the container, e.g. `docker-machine ip \`docker-machine active\``
# * ADVERTISED_PORT: the external port for Kafka, e.g. 9092
# * ZK_CHROOT: the zookeeper chroot that's used by Kafka (without / prefix), e.g. "kafka"
# * LOG_RETENTION_HOURS: the minimum age of a log file in hours to be eligible for deletion (default is 168, for 1 week)
# * LOG_RETENTION_BYTES: configure the size at which segments are pruned from the log, (default is 1073741824, for 1GB)
# * NUM_PARTITIONS: configure the default number of log partitions per topic

# Configure advertised host/port if we run in helios
if [ ! -z "$HELIOS_PORT_kafka" ]; then
    ADVERTISED_HOST=`echo $HELIOS_PORT_kafka | cut -d':' -f 1 | xargs -n 1 dig +short | tail -n 1`
    ADVERTISED_PORT=`echo $HELIOS_PORT_kafka | cut -d':' -f 2`
fi

# Set the external host and port
if [ -z "$ADVERTISED_HOST" ]; then
    ADVERTISED_HOST=`route -n | awk '/UG[ \t]/{print $2}'`
fi

echo "ssl.keystore.location=/etc/ssl/server.keystore.jks" >> $KAFKA_HOME/config/server.properties
echo "ssl.keystore.password=kafka_ex" >> $KAFKA_HOME/config/server.properties
echo "ssl.key.password=kafka_ex" >> $KAFKA_HOME/config/server.properties
echo "ssl.secure.random.implementation=SHA1PRNG" >> $KAFKA_HOME/config/server.properties
echo "security.inter.broker.protocol=PLAINTEXT" >> $KAFKA_HOME/config/server.properties


if [ ! -z "$ADVERTISED_HOST" ] && [ ! -z "$ADVERTISED_PORT" ]; then
    echo "listeners=SSL://$ADVERTISED_HOST:$ADVERTISED_PORT,PLAINTEXT://:9093" >> $KAFKA_HOME/config/server.properties
fi

# Set the zookeeper chroot
if [ ! -z "$ZK_CHROOT" ]; then
    # wait for zookeeper to start up
    until /usr/share/zookeeper/bin/zkServer.sh status; do
      sleep 0.1
    done

    # create the chroot node
    echo "create /$ZK_CHROOT \"\"" | /usr/share/zookeeper/bin/zkCli.sh || {
        echo "can't create chroot in zookeeper, exit"
        exit 1
    }

    # configure kafka
    sed -r -i "s/(zookeeper.connect)=(.*)/\1=localhost:2181\/$ZK_CHROOT/g" $KAFKA_HOME/config/server.properties
fi

# Allow specification of log retention policies
if [ ! -z "$LOG_RETENTION_HOURS" ]; then
    echo "log retention hours: $LOG_RETENTION_HOURS"
    sed -r -i "s/(log.retention.hours)=(.*)/\1=$LOG_RETENTION_HOURS/g" $KAFKA_HOME/config/server.properties
fi
if [ ! -z "$LOG_RETENTION_BYTES" ]; then
    echo "log retention bytes: $LOG_RETENTION_BYTES"
    sed -r -i "s/#(log.retention.bytes)=(.*)/\1=$LOG_RETENTION_BYTES/g" $KAFKA_HOME/config/server.properties
fi

# Configure the default number of log partitions per topic
if [ ! -z "$NUM_PARTITIONS" ]; then
    echo "default number of partition: $NUM_PARTITIONS"
    sed -r -i "s/(num.partitions)=(.*)/\1=$NUM_PARTITIONS/g" $KAFKA_HOME/config/server.properties
fi

# Enable/disable auto creation of topics
if [ ! -z "$AUTO_CREATE_TOPICS" ]; then
    echo "auto.create.topics.enable: $AUTO_CREATE_TOPICS"
    echo "auto.create.topics.enable=$AUTO_CREATE_TOPICS" >> $KAFKA_HOME/config/server.properties
fi

create-topics.sh &

if [ ! -z "$TIMESTAMP_DIFFERENCE" ]; then
    echo "log.message.timestamp.difference.max.ms=${TIMESTAMP_DIFFERENCE}" >> $KAFKA_HOME/config/server.properties
fi

#Force container to be able to resolve its hostname
HOST_IP="$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"
echo "$HOST_IP $ADVERTISED_HOST" >> /etc/hosts

# Run Kafka
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties

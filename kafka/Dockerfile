# Kafka and Zookeeper

FROM openjdk:8u212-jre

ENV DEBIAN_FRONTEND noninteractive
ENV SCALA_VERSION 2.12
ENV KAFKA_VERSION 2.2.0
ENV KAFKA_HOME /opt/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION"

# Install Kafka, Zookeeper and other needed things
RUN apt-get update && \
    apt-get install -y zookeeper wget supervisor dnsutils && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    wget -q http://apache.mirrors.spacedump.net/kafka/"$KAFKA_VERSION"/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz -O /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz && \
    tar xfz /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz -C /opt && \
    rm /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz

RUN apt-get update && \
    apt-get install -y net-tools && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

RUN sed -i.bak 's/#delete/delete/g' $KAFKA_HOME/config/server.properties
RUN echo "\nauto.create.topics.enable=false" >> $KAFKA_HOME/config/server.properties
ADD scripts/create-topics.sh /usr/bin/create-topics.sh
ADD scripts/start-kafka.sh /usr/bin/start-kafka.sh

# Supervisor config
ADD supervisor/kafka.conf supervisor/zookeeper.conf /etc/supervisor/conf.d/

# 2181 is zookeeper, 9092 is kafka
EXPOSE 2181 9092

CMD ["supervisord", "-n"]

#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis" ]; then
    exit 0
fi

if [ -d /vagrant ]; then
  LOG="/vagrant/consul_${HOSTNAME}.log"
else
  LOG="consul.log"
fi

touch /var/vagrant_redis
echo "$REDIS_MASTER_IP     $REDIS_MASTER_NAME" >> /etc/hosts
echo "$REDIS_SLAVE_IP     $REDIS_SLAVE_NAME" >> /etc/hosts

 # copy a consul service definition directory
 sudo mkdir -p /etc/consul.d

# check for redis hostname => master
if [[ "${HOSTNAME}" =~ "master" ]]; then
 sudo cp /usr/local/bootstrap/conf/master.redis.conf /etc/redis/redis.conf
 sudo chown redis:redis /etc/redis/redis.conf
 sudo chmod 640 /etc/redis/redis.conf
 echo "requirepass $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
 sudo cp -p /usr/local/bootstrap/conf/consul.d/redis.json /etc/consul.d/redis.json
else 
 sudo cp /usr/local/bootstrap/conf/slave.redis.conf /etc/redis/redis.conf
 sudo chown redis:redis /etc/redis/redis.conf
 sudo chmod 640 /etc/redis/redis.conf
 echo "requirepass $REDIS_SLAVE_PASSWORD" | sudo tee -a /etc/redis/redis.conf
 echo "slaveof $REDIS_MASTER_IP 6379" | \
    sudo tee -a /etc/redis/redis.conf
 echo "masterauth $REDIS_MASTER_PASSWORD" | sudo tee -a /etc/redis/redis.conf
 sudo cp -p /usr/local/bootstrap/conf/consul.d/redisSlave.json /etc/consul.d/redisSlave.json
fi

sudo systemctl restart redis-server
sudo killall -1 consul

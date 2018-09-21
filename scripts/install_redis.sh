#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

IP=${LEADER_IP}

if [ "${TRAVIS}" == "true" ]; then
  IP="127.0.0.1"
fi

register_redis_service_with_consul () {
    
    echo 'Start to register service with Consul Service Discovery'

    # configure Audit Backend
    tee redis_service.json <<EOF
    {
      "service": {
        "name": "redis",
        "tags": ["primary"],
        "address": "",
        "meta": {
          "meta": "The Redis Service"
        },
        "port": 6379,
        "enable_tag_override": false,
        "checks": [
          {
            "args": ["/usr/local/bootstrap/scripts/consul_redis_ping.sh"],
            "interval": "10s"
          },
          {
              "args": ["/usr/local/bootstrap/scripts/consul_redis_verify.sh"],
              "interval": "10s"
          }
        ]
      }
    }
EOF
  
  curl \
      --request PUT \
      --data @redis_service.json \
      http://127.0.0.1:8500/v1/agent/service/register
   
    echo 'Register service with Consul Service Discovery Complete'
}

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_redis" ]; then
    exit 0
fi

# install this package in base image in the future
which jq &>/dev/null || {
  sudo apt-get update
  sudo apt-get install -y jq
}

touch /var/vagrant_redis
echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts

sudo VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token` VAULT_ADDR="http://${LEADER_IP}:8200" consul-template -template "/usr/local/bootstrap/conf/master.redis.ctpl:/etc/redis/redis.conf" -once
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf

# restart redis, register the service with consul and restart consul agent
sudo systemctl restart redis-server
register_redis_service_with_consul
sudo killall -1 consul



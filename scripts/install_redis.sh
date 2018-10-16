#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

echo 'Start Setup of Redis Deployment Environment'
IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ "${TRAVIS}" == "true" ]; then
  IP="127.0.0.1"
fi

if [ "${TRAVIS}" == "true" ]; then
  LEADER_IP="127.0.0.1"
fi

register_redis_service_with_consul () {
    
    echo 'Start to register service with Consul Service Discovery'

    # configure redis service definition
    tee redis_service.json <<EOF
    {
      "ID": "redis",
      "Name": "redis",
      "Tags": [
        "primary",
        "v1"
      ],
      "Address": "${IP}",
      "Port": 6379,
      "Meta": {
        "redis_version": "4.0"
      },
      "EnableTagOverride": false,
      "Connect": { "sidecar_service": {} },
      "Checks": [
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
EOF
  
  # Register the service in consul via the local Consul agent api
  curl -s \
      -v \
      --request PUT \
      --data @redis_service.json \
      http://127.0.0.1:8500/v1/agent/service/register

  # List the locally registered services via local Consul api
  curl -s \
    -v \
    http://127.0.0.1:8500/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  curl -s \
  -v \
  http://${LEADER_IP}:8500/v1/catalog/services | jq -r .
   
    echo 'Register service with Consul Service Discovery Complete'
}

sudo echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts

sudo VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token` VAULT_ADDR="http://${LEADER_IP}:8200" consul-template -template "/usr/local/bootstrap/conf/master.redis.ctpl:/etc/redis/redis.conf" -once
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf

# restart redis, register the service with consul and restart consul agent
sudo service redis-server restart
register_redis_service_with_consul
sudo killall -1 consul
sleep 5

# start the new service mesh proxy
sudo consul connect proxy -sidecar-for redis &

echo "Redis Server Build Complete"



#!/usr/bin/env bash
setup_environment () {
  set -x
  source /usr/local/bootstrap/var.env
  echo 'Start Setup of Redis Deployment Environment'

  IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
  IP=${CIDR%%/24}

  if [ -d /vagrant ]; then
    LOG="/vagrant/logs/redis_proxy_${HOSTNAME}.log"
  else
    LOG="redis_proxy_${HOSTNAME}.log"
  fi

  if [ "${TRAVIS}" == "true" ]; then
    IP="127.0.0.1"
    LEADER_IP=${IP}
  fi

}
register_redis_service_with_consul () {
    
    echo 'Start to register service with Consul Service Discovery'

    cat <<EOF | sudo tee /etc/consul.d/redis.json
    {
      "service": {
        "name": "redis",
        "port": 6379,
        "connect": { "sidecar_service": {} }
      }
      
    }
EOF
  
  # Register the service in consul via the local Consul agent api
  consul reload
  sleep 5

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

configure_redis () {
  sudo echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts
  sudo VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token` VAULT_ADDR="http://${LEADER_IP}:8200" consul-template -template "/usr/local/bootstrap/conf/master.redis.ctpl:/etc/redis/redis.conf" -once
  sudo chown redis:redis /etc/redis/redis.conf
  sudo chmod 640 /etc/redis/redis.conf
  # restart redis, register the service with consul and restart consul agent
  sudo service redis-server restart
}

start_redis_proxy_service () {
  # start the new service mesh proxy
  sudo consul connect proxy -sidecar-for redis >${LOG} &
  sleep 2
  sudo cat ${LOG}
  echo "Redis Server Build Complete"
}

setup_environment
configure_redis
register_redis_service_with_consul
start_redis_proxy_service







#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

echo 'Start Setup of Webtier Deployment Environment'
IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ "${TRAVIS}" == "true" ]; then
  IP="127.0.0.1"
fi

if [ "${TRAVIS}" == "true" ]; then
  LEADER_IP="127.0.0.1"
fi

register_nginx_service_with_consul () {
    
    echo 'Start to register nginx service with Consul Service Discovery'

    # configure web service definition
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
  curl \
      -v \
      --request PUT \
      --data @redis_service.json \
      http://127.0.0.1:8500/v1/agent/service/register

  # List the locally registered services via local Consul api
  curl \
    -v \
    http://127.0.0.1:8500/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  curl \
  -v \
  http://${LEADER_IP}:8500/v1/catalog/services | jq -r .
   
    echo 'Register nginx service with Consul Service Discovery Complete'
}

which jq &>/dev/null || {
  # potentially add jq to base image
  sudo apt-get update
  sudo apt-get install -y jq
}
# remove nginx default website
[ -f /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default

# copy a consul service definition directory
sudo mkdir -p /etc/consul.d
sudo cp -p /usr/local/bootstrap/conf/consul.d/webtier.json /etc/consul.d/webtier.json

# make consul reload conf
sudo killall -1 consul
sudo killall -9 consul-template &>/dev/null

sleep 2

sudo /usr/local/bin/consul-template \
     -consul-addr=${LEADER_IP}:8500 \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:/usr/local/bootstrap/scripts/updateBackendCount.sh" &
   
sleep 1


#!/usr/bin/env bash

create_service () {
  # create a new systemd service
  # param 1 ${1}: service/serviceuser name
  # param 2 ${2}: service description
  # param 3 ${3}: service start command
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} service
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target

[Service]
User=${1}
Group=${1}
PIDFile=/var/run/${1}/${1}.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/${1}
ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
ExecStart=${3}
ExecReload=/bin/kill -HUP ${MAINPID}
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload

  fi

}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    echo "Creating ${1} user to run the ${1} service"
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
  fi

}

start_app_proxy_service () {
  # start the new service mesh proxy for the application
  # param 1 ${1}: app-proxy name
  # param 2 ${2}: app-proxy service description
  # param 3 ${3}: consul host service name

  create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -sidecar-for ${3}"
  sudo systemctl start ${1}
  sudo systemctl status ${1}
  echo "${1} Proxy App Service Build Complete"
}

start_client_proxy_service () {
    # start the new service mesh proxy for the client
    # param 1 ${1}: client-proxy name
    # param 2 ${2}: client-proxy service description
    # param 3 ${3}: client-proxy upstream consul service name
    # param 4 ${4}: client-proxy local service port number
    

    create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -service ${3} -upstream ${4}:${5} -register"
    sudo systemctl start ${1}
    sudo systemctl status ${1}
    echo "${1} Proxy Client Service Build Complete"
}

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

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
  export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
  export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
  export CONSUL_ACCESS_TOKEN=`cat /usr/local/bootstrap/.agenttoken_acl`

}
register_redis_service_with_consul () {
    
    echo 'Start to register service with Consul Service Discovery'

    cat <<EOF | sudo tee /etc/consul.d/redis.json
    {
      "service": {
        "name": "redis",
        "port": 6379,
        "connect": { "sidecar_service": {} },
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
  
  # Register the service in consul via the local Consul agent api
  consul reload
  sleep 5

  # List the locally registered services via local Consul api
  curl \
    -v \
      --cacert "/usr/local/bootstrap/certificate-config/consul-ca.pem" \
      --key "/usr/local/bootstrap/certificate-config/client-key.pem" \
      --cert "/usr/local/bootstrap/certificate-config/client.pem" \
      --header "X-Consul-Token: ${CONSUL_ACCESS_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  curl \
  -v \
    --cacert "/usr/local/bootstrap/certificate-config/consul-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/client.pem" \
    --header "X-Consul-Token: ${CONSUL_ACCESS_TOKEN}" \
  ${CONSUL_HTTP_ADDR}/v1/catalog/services | jq -r .
   
    echo 'Register service with Consul Service Discovery Complete'
}

configure_redis () {
  
  sudo VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token` VAULT_ADDR="http://${LEADER_IP}:8200" consul-template -template "/usr/local/bootstrap/conf/master.redis.ctpl:/etc/redis/redis.conf" -once
  sudo chown redis:redis /etc/redis/redis.conf
  sudo chmod 640 /etc/redis/redis.conf
  register_redis_service_with_consul

  if [ "${TRAVIS}" != "true" ]; then
    sudo echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    # start connect application proxy
    start_app_proxy_service redis-proxy "Redis Proxy Service" redis
  else
    sudo service redis-server restart

  fi

  sleep 5
  echo "Redis Server Build Complete"

}

setup_environment
configure_redis








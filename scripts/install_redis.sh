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
RestartSec=2s

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

  create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -http-addr=https://127.0.0.1:8321 -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem -token=${CONSUL_HTTP_TOKEN} -sidecar-for ${3}"
  sudo usermod -a -G webpagecountercerts ${1}
  sudo systemctl start ${1}
  #sudo systemctl status ${1}
  echo "${1} Proxy App Service Build Complete"
}

start_client_proxy_service () {
    # start the new service mesh proxy for the client
    # param 1 ${1}: client-proxy name
    # param 2 ${2}: client-proxy service description
    # param 3 ${3}: client-proxy upstream consul service name
    # param 4 ${4}: client-proxy local service port number
    

    create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -http-addr=https://127.0.0.1:8321 -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem -token=${CONSUL_HTTP_TOKEN} -service ${3} -upstream ${4}:${5} -register"
    sudo usermod -a -G webpagecountercerts ${1}
    sudo systemctl start ${1}
    #sudo systemctl status ${1}
    echo "${1} Proxy Client Service Build Complete"
}

setup_environment () {
  set -x
  source /usr/local/bootstrap/var.env
  echo 'Start Setup of Redis Deployment Environment'

  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}

  if [ -d /vagrant ]; then
    LOG="/vagrant/logs/redis_proxy_${HOSTNAME}.log"
  else
    LOG="redis_proxy_${HOSTNAME}.log"
  fi

  if [ "${TRAVIS}" == "true" ]; then
    ROOTCERTPATH=tmp
    IP=${IP:-127.0.0.1}
    LEADER_IP=${IP}
  else
    ROOTCERTPATH=etc
  fi

  export ROOTCERTPATH

  # debug certs issue
  sudo ls -al /${ROOTCERTPATH}/vault.d /${ROOTCERTPATH}/consul.d /${ROOTCERTPATH}/nomad.d /${ROOTCERTPATH}/ssl/private /${ROOTCERTPATH}/certs

  echo 'Set environmental bootstrapping data in VAULT'

  export VAULT_ADDR=https://${LEADER_IP}:8322
  export VAULT_TOKEN=reallystrongpassword
  export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem
  export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem
  export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem
  export VAULT_SKIP_VERIFY=true

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem
  export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem
  export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem

  REDIS_MASTER_PASSWORD=`vault kv get -field "value" kv/development/redispassword`
  AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
  DB_VAULT_TOKEN=`vault kv get -field "value" kv/development/vaultdbtoken`
  APPROLEID=`vault kv get -field "value" kv/development/approleid`
  WRAPPED_VAULT_TOKEN=`vault kv get -field "value" kv/development/wrappedprovisionertoken`

  export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

}

register_redis_service_with_consul () {
    
    echo 'Start to register Redis service with Consul Service Discovery'

    # configure web service definition
    tee redis_service.json <<EOF
    {
      "Name": "redis",
      "Tags": [
        "redis-non-ha"
      ],
      "Port": 6379,
      "Meta": {
        "RedisService": "0.0.1"
      },
      "EnableTagOverride": false,
      "checks": [
          {
            "args": ["/usr/local/bootstrap/scripts/consul_redis_ping.sh"],
            "interval": "10s"
          },
          {
              "args": ["/usr/local/bootstrap/scripts/consul_redis_verify.sh"],
              "interval": "10s"
          }
        ],
        "connect": { "sidecar_service": {} }
    }
EOF

  # Register the service in consul via the local Consul agent api
  sudo curl \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data @redis_service.json \
      ${CONSUL_HTTP_ADDR}/v1/agent/service/register

  # List the locally registered services via local Consul api
  sudo curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  sudo curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/catalog/services | jq -r .
   
    echo 'Register Redis Service with Consul Service Discovery Complete'

}

configure_redis () {
  
  sudo consul-template \
    -vault-addr=${VAULT_ADDR} \
    -vault-token=${DB_VAULT_TOKEN} \
    -vault-ssl-cert="/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem" \
    -vault-ssl-key="/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem" \
    -vault-ssl-ca-cert="/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem" \
    -template "/usr/local/bootstrap/conf/master.redis.ctpl:/${ROOTCERTPATH}/redis/redis.conf" -once
  
  sudo chown redis:redis /${ROOTCERTPATH}/redis/redis.conf
  sudo chmod 640 /${ROOTCERTPATH}/redis/redis.conf

  register_redis_service_with_consul

  if [ "${TRAVIS}" != "true" ]; then
    sudo echo "${REDIS_MASTER_IP}     ${REDIS_MASTER_NAME}" >> /etc/hosts
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    # start connect application proxy
    start_app_proxy_service redis-proxy "Redis Proxy Service" redis
  else
    sudo redis-server /${ROOTCERTPATH}/redis/redis.conf &

  fi

  sleep 15
  echo "Redis Server Build Complete"

}

setup_environment
configure_redis

exit 0








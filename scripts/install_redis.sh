#!/usr/bin/env bash

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
  export CONSUL_HTTP_SSL=true
  export CONSUL_GRPC_ADDR=https://127.0.0.1:8502

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
    
    # start envoy proxy
    sudo /usr/local/bootstrap/scripts/install_envoy_proxy.sh redis-proxy "\"Redis Proxy Service\"" redis 19001 ${CONSUL_HTTP_TOKEN}
  else
    sudo redis-server /${ROOTCERTPATH}/redis/redis.conf &

  fi

  sleep 15
  echo "Redis Server Build Complete"

}

setup_environment
configure_redis
sudo systemctl status redis-server

exit 0








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

register_secret_id_client_proxy_service_with_consul () {
    
    echo 'Start to register secret-id client service with Consul Service Discovery'

    # configure web service definition
    tee secret_id_client_service.json <<EOF
    {
      "Name": "secret-id-client",
      "Tags": [
        "secret-id-client-proxy"
      ],
      "Port": 9877,
      "Meta": {
        "SecretIDClientService": "0.0.1"
      },
      "connect": { 
        "sidecar_service": {
          "proxy": {
            "upstreams": {
              "destination_name": "approle"
              "local_bind_port": 9867
            }
          }
        } 
      }
    }
EOF

  # Register the service in consul via the local Consul agent api
  sudo curl \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data @secret_id_client_service.json \
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
   
    echo 'Register Redis Client Service with Consul Service Discovery Complete'

}

register_redis_client_proxy_service_with_consul () {
    
    echo 'Start to register Redis client service with Consul Service Discovery'

    # configure web service definition
    tee redis_client_service.json <<EOF
    {
      "Name": "redis-client",
      "Tags": [
        "redis-client-proxy"
      ],
      "Port": 9898,
      "Meta": {
        "RedisClientService": "0.0.1"
      },
      "connect": { 
        "sidecar_service": {
          "proxy": {
            "upstreams": {
              "destination_name": "redis"
              "local_bind_port": 9897
            }
          }
        } 
      }
    }
EOF

  # Register the service in consul via the local Consul agent api
  sudo curl \
      --request PUT \
      --cacert "/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem" \
      --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem" \
      --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem" \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --data @redis_client_service.json \
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
   
    echo 'Register Redis Client Service with Consul Service Discovery Complete'

}


start_envoy_proxy_service () {
  # start the new service mesh proxy for the application
  # param 1 ${1}: app-proxy name
  # param 2 ${2}: app-proxy service description
  # param 3 ${3}: consul host service name
  # param 4 ${4}: envoy proxy admin port needs to be different if running multiple instances on same host network

  create_service "${1}" "${2}" "/usr/local/bin/consul connect envoy \
                                                        -http-addr=https://127.0.0.1:8321 \
                                                        -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem \
                                                        -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem \
                                                        -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem \
                                                        -token=${CONSUL_HTTP_TOKEN} \
                                                        -sidecar-for ${3} \
                                                        -admin-bind localhost:${4}"
  sudo usermod -a -G webpagecountercerts ${1}
  sudo systemctl start ${1}
  #sudo systemctl status ${1}
  echo "${1} Proxy App Service Build Complete"
}

create_intention_between_services () {
    sudo /usr/local/bin/consul intention create -http-addr=https://127.0.0.1:8321 -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem -token=${CONSUL_HTTP_TOKEN} ${1} ${2}
}


set -x

source /usr/local/bootstrap/var.env

if [ "${TRAVIS}" == "true" ]; then
  IP="127.0.0.1"
  ROOTCERTPATH=tmp
  LEADER_IP=${IP}
else
  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}
  ROOTCERTPATH=etc
fi

export ROOTCERTPATH

# sudo /usr/local/bootstrap/scripts/create_certificate.sh consul hashistack1 30 ${IP} client
# sudo chown -R consul:consul /${ROOTCERTPATH}/consul.d
# sudo chmod -R 755 /${ROOTCERTPATH}/consul.d  

# sudo /usr/local/bootstrap/scripts/create_certificate.sh vault hashistack1 30 ${IP} client
# sudo chown -R vault:vault /${ROOTCERTPATH}/vault.d
# sudo chmod -R 755 /${ROOTCERTPATH}/vault.d
# sudo chmod -R 755 /${ROOTCERTPATH}/ssl/certs
# sudo chmod -R 755 /${ROOTCERTPATH}/ssl/private

# read redis database password from vault
export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem
export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem
export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${LEADER_IP}:8322"
export VAULT_TOKEN=reallystrongpassword

# Configure consul environment variables for use with certificates 
export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem
export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem
export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem
AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}
export CONSUL_HTTP_SSL=true
export CONSUL_GRPC_ADDR=https://127.0.0.1:8502

export NOMAD_CACERT=/${ROOTCERTPATH}/ssl/certs/nomad-agent-ca.pem
export NOMAD_CLIENT_CERT=/${ROOTCERTPATH}/nomad.d/pki/tls/certs/nomad-client.pem
export NOMAD_CLIENT_KEY=/${ROOTCERTPATH}/nomad.d/pki/tls/private/nomad-client-key.pem
export NOMAD_ADDR=https://${LEADER_IP}:4646

# Configure CA Certificates for APP on host OS
sudo mkdir -p /usr/local/share/ca-certificates
sudo apt-get install ca-certificates -y
#sudo openssl x509 -outform der -in /etc/ssl/certs/consul-agent-ca.pem -out /usr/local/bootstrap/certificate-config/hashistack-ca.crt
sudo cp /etc/ssl/certs/consul-agent-ca.pem /usr/local/share/ca-certificates/hashistack-ca.crt
sudo update-ca-certificates


# Create new envoy proxy services
register_redis_client_proxy_service_with_consul
register_secret_id_client_proxy_service_with_consul

# start client proxy
start_envoy_proxy_service redisclientproxy "Redis Connect Client Proxy" "redis-client" 19009

# create intention to connect from goapp to redis service
create_intention_between_services "redis-client" "redis"

# start client proxy
start_client_proxy_service goclientproxy "SecretID Service Client Proxy" "secret-id-client" 19010

# create intention to connect from goapp to secret-id service
create_intention_between_services "secret-id-client" "approle"

# FORCE DOWNLOAD OF NEW WEBCOUNTER Binary
sudo rm -rf /usr/local/bin/webcounter

# Added loop below to overcome Travis-CI/Github download issue
RETRYDOWNLOAD="1"
pushd /usr/local/bin
while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /usr/local/bin/webcounter ]
do
    echo 'Vault SecretID Service Download - Take ${RETRYDOWNLOAD}' 
    # download binary and template file from latest release
    sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/web_page_counter/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | wget -q -i - '
    RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
    sleep 5
done

[  -f /usr/local/bin/webcounter  ] &>/dev/null || {
    echo 'Failed to download Vault Secret ID Factory Service'
    exit 1
}

sudo chmod +x /usr/local/bin/webcounter
popd

# copy application verification test for nomad/consul
cp /usr/local/bootstrap/scripts/consul_goapp_verify.sh /usr/local/bin/.

nomad job stop webpagecounter &>/dev/null
killall webcounter &>/dev/null

sed -i 's/consulACL=.*",/consulACL='${CONSUL_HTTP_TOKEN}'",/g' /usr/local/bootstrap/scripts/nomad_job.hcl
sed -i 's/consulIP=.*"/consulIP='${LEADER_IP}':8321"/g' /usr/local/bootstrap/scripts/nomad_job.hcl

echo 'Review Nomad Job File'
cat /usr/local/bootstrap/scripts/nomad_job.hcl

/usr/local/bin/nomad job run /usr/local/bootstrap/scripts/nomad_job.hcl || true

exit 0



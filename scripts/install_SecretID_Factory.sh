#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

register_secret_id_service_with_consul () {
    
    echo 'Start to register secret_id service with Consul Service Discovery'

    # configure web service definition
    tee secretid_service.json <<EOF
    {
      "Name": "approle",
      "Tags": [
        "approle",
        "secret-id"
      ],
      "Address": "${IP}",
      "Port": 8314,
      "Meta": {
        "SecretID-Factory-Service": "0.0.1"
      },
      "EnableTagOverride": false,
      "check": 
        {
          "id": "api",
          "name": "Factory Service SecretID",
          "http": "http://${IP}:8314/health",
          "tls_skip_verify": true,
          "method": "GET",
          "interval": "10s",
          "timeout": "1s"
        }
    }
EOF

  # Register the service in consul via the local Consul agent api
  curl \
      -v \
      --request PUT \
      --data @secretid_service.json \
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

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}
VAULT_IP=${LEADER_IP}

if [ "${TRAVIS}" == "true" ]; then
    IP="127.0.0.1"
    VAULT_IP=${IP}
    LEADER_IP=${IP}
fi

export VAULT_ADDR=http://${VAULT_IP}:8200
export VAULT_SKIP_VERIFY=true

if [ -d /vagrant ]; then
    LOG="/vagrant/logs/VaultServiceIDFactory_${HOSTNAME}.log"
else
    LOG="${TRAVIS_HOME}/VaultServiceIDFactory.log"
fi

sudo killall VaultServiceIDFactory &>/dev/null

# Added loop below to overcome Travis-CI download issue
RETRYDOWNLOAD="1"

while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /usr/local/bin/VaultServiceIDFactory ]
do
    pushd /usr/local/bin
    echo 'Vault SecretID Service Download - Take ${RETRYDOWNLOAD}' 
    # download binary and template file from latest release
    sudo bash -c 'curl -s https://api.github.com/repos/allthingsclowd/VaultServiceIDFactory/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | wget -q -i - '
    
    popd
    RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
    sleep 5
done

[  -f /usr/local/bin/VaultServiceIDFactory  ] &>/dev/null || {
     echo 'Failed to download Vault Secret ID Factory Service'
     exit 1
}

sudo chmod +x /usr/local/bin/VaultServiceIDFactory
sudo /usr/local/bin/VaultServiceIDFactory -vault="${VAULT_ADDR}" &> ${LOG} &

sleep 5

cat ${LOG}

# initialise the factory service with the provisioner token
WRAPPED_TOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
curl --header 'Content-Type: application/json' \
    --request POST \
    --data "{\"token\":\""${WRAPPED_TOKEN}"\"}" \
    http://${IP}:8314/initialiseme

register_secret_id_service_with_consul

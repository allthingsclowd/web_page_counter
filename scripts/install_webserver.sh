#!/usr/bin/env bash

set -x

source /usr/local/bootstrap/var.env

echo 'Start Setup of Webtier Deployment Environment'
IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
IP=${CIDR%%/24}

if [ "${TRAVIS}" == "true" ]; then
  ROOTCERTPATH=tmp
  IP=${IP:-127.0.0.1}
  LEADER_IP=${IP}
else
  ROOTCERTPATH=etc
fi

export ROOTCERTPATH

echo 'Set environmental bootstrapping data in VAULT'

export VAULT_ADDR=https://${LEADER_IP}:8322
export VAULT_TOKEN=reallystrongpassword
export VAULT_CLIENT_KEY=/${ROOTCERTPATH}/vault.d/pki/tls/private/vault-client-key.pem
export VAULT_CLIENT_CERT=/${ROOTCERTPATH}/vault.d/pki/tls/certs/vault-client.pem
export VAULT_CACERT=/${ROOTCERTPATH}/ssl/certs/vault-agent-ca.pem
export VAULT_SKIP_VERIFY=true

# Configure consul environment variables for use with certificates 
export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
export CONSUL_CACERT=/${ROOTCERTPATH}/ssl/certs/consul-root-signed-intermediate-ca.pem
export CONSUL_CLIENT_CERT=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem
export CONSUL_CLIENT_KEY=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem
AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

enable_nginx_service () {
  # start and enable nginx service
  sudo systemctl start nginx
  sudo systemctl enable nginx
}

register_nginx_service_with_consul () {
    
    echo 'Start to register nginx service with Consul Service Discovery'

    # configure web service definition
    tee nginx_service.json <<EOF
    {
      "Name": "nginx",
      "Tags": [
        "proxy",
        "lbaas"
      ],
      "Address": "${IP}",
      "Port": 9090,
      "Meta": {
        "nginx": "0.0.1"
      },
      "EnableTagOverride": false,
      "check": 
        {
          "name": "HTTP API on port 9090",
          "http": "http://${IP}:9090/health",
          "tls_skip_verify": true,
          "method": "GET",
          "interval": "10s",
          "timeout": "1s"
        }
    }
EOF


  # Register the service in consul via the local Consul agent api
  curl \
    --request PUT \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-root-signed-intermediate-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --data @nginx_service.json \
    ${CONSUL_HTTP_ADDR}/v1/agent/service/register

  # List the locally registered services via local Consul api
  curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-root-signed-intermediate-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  curl \
    --cacert "/${ROOTCERTPATH}/ssl/certs/consul-root-signed-intermediate-ca.pem" \
    --key "/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem" \
    --cert "/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/catalog/services | jq -r .
   
    echo 'Register nginx service with Consul Service Discovery Complete'
}

# Added loop below to overcome Travis-CI download issue
RETRYDOWNLOAD="1"
sudo mkdir -p /tmp/wpc-fe
pushd /tmp/wpc-fe
while [ ${RETRYDOWNLOAD} -lt 10 ] && [ ! -f /var/www/wpc-fe/index.html ]
do 
    echo "Web Front End Download - Take ${RETRYDOWNLOAD}"
    # download binary and template file from latest release
    sudo bash -c 'curl -s -L https://api.github.com/repos/allthingsclowd/wep_page_counter_front-end/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | wget -q -i - '
    [ -f webcounterpagefrontend.tar.gz ] && sudo tar -xvf webcounterpagefrontend.tar.gz -C /var/www
    RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
    sleep 5
done

popd

[  -f /var/www/wpc-fe/index.html  ] &>/dev/null || {
    echo 'Web Front End Download Failed'
    exit 1
} 

# Configure LBaaS Public IP for WebFrontend
sudo sed -i 's/window.__env.apiUrl =.*;/window.__env.apiUrl = "'${DNSNAME}'";/g' /var/www/wpc-fe/env.js

# debug 
echo "Check web frontend changes"
sudo cat /var/www/wpc-fe/env.js


 # This line causes the entire inline not to run
 #     "sudo sh -c \"sed 's/api_key:.*/api_key: ${dd_api_key}' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf\""
sudo cp /usr/local/bootstrap/conf/wpc-fe.conf /etc/nginx/conf.d/wpc-fe.conf

# remove nginx default website
[ -f /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default

enable_nginx_service

register_nginx_service_with_consul

# make consul reload conf
sudo killall -1 consul
sudo killall -9 consul-template &>/dev/null

sleep 2

export CONSUL_TOKEN=${CONSUL_HTTP_TOKEN}

sudo /usr/local/bin/consul-template \
     -consul-addr=${CONSUL_HTTP_ADDR} \
     -consul-ssl \
     -consul-token=${CONSUL_HTTP_TOKEN} \
     -consul-ssl-cert="/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-cli.pem" \
     -consul-ssl-key="/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-cli-key.pem" \
     -consul-ssl-ca-cert="/${ROOTCERTPATH}/ssl/certs/consul-root-signed-intermediate-ca.pem" \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:/usr/local/bootstrap/scripts/updateBackendCount.sh" &
   
sleep 1

echo "Verifiy the backend is accessible through nginx service"
sudo cat /etc/nginx/conf.d/goapp.conf

echo "Verifiy the backend is accessible through nginx service"
curl http://${IP}:9090

echo "Verifiy the frontend is accessible through nginx service"
curl http://${IP}:9091

exit 0

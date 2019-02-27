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

# Configure consul environment variables for use with certificates 
export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
export CONSUL_HTTP_TOKEN=`cat /usr/local/bootstrap/.agenttoken_acl`


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
          "id": "api",
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
    --cacert "/usr/local/bootstrap/certificate-config/consul-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --data @nginx_service.json \
    ${CONSUL_HTTP_ADDR}/v1/agent/service/register

  # List the locally registered services via local Consul api
  curl \
    --cacert "/usr/local/bootstrap/certificate-config/consul-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/agent/services | jq -r .

  # List the services regestered on the Consul server
  curl \
    --cacert "/usr/local/bootstrap/certificate-config/consul-ca.pem" \
    --key "/usr/local/bootstrap/certificate-config/client-key.pem" \
    --cert "/usr/local/bootstrap/certificate-config/client.pem" \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/catalog/services | jq -r .
   
    echo 'Register nginx service with Consul Service Discovery Complete'
}

# Added loop below to overcome Travis-CI download issue
RETRYDOWNLOAD="1"

while [ ${RETRYDOWNLOAD} -lt 5 ] && [ ! -d /var/www/wpc-fe ]
do
    sudo mkdir -p /tmp/wpc-fe
    pushd /tmp/wpc-fe
    echo 'Web Front end Download' 
    # download binary and template file from latest release
    sudo bash -c 'curl -s https://api.github.com/repos/allthingsclowd/wep_page_counter_front-end/releases/latest \
    | grep "browser_download_url" \
    | cut -d : -f 2,3 \
    | tr -d \" | wget -q -i - '
    sudo tar -xvf webcounterpagefrontend.tar.gz -C /var/www
    popd
    RETRYDOWNLOAD=$[${RETRYDOWNLOAD}+1]
    sleep 5
done


[  -f /var/www/wpc-fe/index.html  ] &>/dev/null || {
     echo 'Web Front End Download Failed'
     exit 1
}

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
     -consul-ssl-cert="/usr/local/bootstrap/certificate-config/client.pem" \
     -consul-ssl-key="/usr/local/bootstrap/certificate-config/client-key.pem" \
     -consul-ssl-ca-cert="/usr/local/bootstrap/certificate-config/consul-ca.pem" \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:/usr/local/bootstrap/scripts/updateBackendCount.sh" &
   
sleep 1
exit 0

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

  create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -http-addr=https://127.0.0.1:8321 -ca-file=/usr/local/bootstrap/certificate-config/consul-ca.pem -client-cert=/usr/local/bootstrap/certificate-config/cli.pem -client-key=/usr/local/bootstrap/certificate-config/cli-key.pem -token=${CONSUL_HTTP_TOKEN} -sidecar-for ${1}"
  sudo usermod -a -G consulcerts ${1}
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
    

    create_service "${1}" "${2}" "/usr/local/bin/consul connect proxy -http-addr=https://127.0.0.1:8321 -ca-file=/usr/local/bootstrap/certificate-config/consul-ca.pem -client-cert=/usr/local/bootstrap/certificate-config/cli.pem -client-key=/usr/local/bootstrap/certificate-config/cli-key.pem -token=${CONSUL_HTTP_TOKEN} -service ${1} -upstream ${3}:${4}"
    sudo usermod -a -G consulcerts ${1}
    sudo systemctl start ${1}
    #sudo systemctl status ${1}
    echo "${1} Proxy Client Service Build Complete"
}

create_intention_between_services () {
    sudo /usr/local/bin/consul intention create -http-addr=https://127.0.0.1:8321 -ca-file=/usr/local/bootstrap/certificate-config/consul-ca.pem -client-cert=/usr/local/bootstrap/certificate-config/cli.pem -client-key=/usr/local/bootstrap/certificate-config/cli-key.pem -token=${CONSUL_HTTP_TOKEN} ${1} ${2}
}


set -x

source /usr/local/bootstrap/var.env

# read redis database password from vault
export VAULT_CLIENT_KEY=/usr/local/bootstrap/certificate-config/hashistack-client-key.pem
export VAULT_CLIENT_CERT=/usr/local/bootstrap/certificate-config/hashistack-client.pem
export VAULT_CACERT=/usr/local/bootstrap/certificate-config/hashistack-ca.pem
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://${LEADER_IP}:8322"
export VAULT_TOKEN=reallystrongpassword

# Configure consul environment variables for use with certificates 
export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
AGENTTOKEN=`vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}


if [ "${TRAVIS}" == "true" ]; then
  IP="127.0.0.1"
  LEADER_IP=${IP}
else
  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}
fi

# start client client proxy
start_client_proxy_service redisclientproxy "Redis Connect Client Proxy" "redis" "6379"

# create intention to connect from goapp to redis service
create_intention_between_services "redisclientproxy" "redis" "6379"

# start client client proxy
start_client_proxy_service goclientproxy "SecretID Service Client Proxy" "approle" "8314"

# create intention to connect from goapp to secret-id service
create_intention_between_services "goclientproxy" "approle"

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
sed -i 's/consulIp=.*"/consulIp='${LEADER_IP}':8321"/g' /usr/local/bootstrap/scripts/nomad_job.hcl

echo 'Review Nomad Job File'
cat /usr/local/bootstrap/scripts/nomad_job.hcl

NOMAD_ADDR=http://${LEADER_IP}:4646 /usr/local/bin/nomad job run /usr/local/bootstrap/scripts/nomad_job.hcl || true

exit 0



#!/usr/bin/env bash

setup_environment () {
  set -x
  sleep 5
  source /usr/local/bootstrap/var.env
  
  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
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
}

start_envoy_proxy_service () {
  # start the new service mesh proxy for the application
  # param 1 ${1}: app-proxy name
  # param 2 ${2}: app-proxy service description
  # param 3 ${3}: consul host service name
  # param 4 ${4}: envoy proxy admin port needs to be different if running multiple instances on same host network

  create_service "${1}" "${2}" "/usr/local/bin/consul connect envoy \
                                                        -grpc-addr=https://127.0.0.1:8502 \
                                                        -http-addr=https://127.0.0.1:8321 \
                                                        -ca-file=/${ROOTCERTPATH}/ssl/certs/consul-agent-ca.pem \
                                                        -client-cert=/${ROOTCERTPATH}/consul.d/pki/tls/certs/consul-client.pem \
                                                        -client-key=/${ROOTCERTPATH}/consul.d/pki/tls/private/consul-client-key.pem \
                                                        -token=${5} \
                                                        -sidecar-for ${3} \
                                                        -admin-bind localhost:${4}"

  sudo systemctl start ${1}
  #sudo systemctl status ${1}
  echo "${1} Proxy App Service Build Complete"
}

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
Type=simple
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


setup_environment
start_envoy_proxy_service "${1}" "${2}" "${3}" "${4}" "${5}"

exit 0
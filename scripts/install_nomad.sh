#!/usr/bin/env bash

create_service () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
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
    echo "Creating ${1} user to run the consul service"
    sudo cp -arp /usr/local/bootstrap/conf/nomad.d /etc
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
  fi

}


set -x

source /usr/local/bootstrap/var.env

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8;exit}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/logs/nomad_${HOSTNAME}.log"
else
  LOG="nomad.log"
fi

# Configure consul environment variables for use with certificates 
export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
AGENTTOKEN=`sudo VAULT_TOKEN=reallystrongpassword VAULT_ADDR="http://${LEADER_IP}:8200" vault kv get -field "value" kv/development/consulagentacl`
export CONSUL_HTTP_TOKEN=${AGENTTOKEN}

which wget unzip &>/dev/null || {
  apt-get update
  apt-get install -y wget unzip 
}

which nomad &>/dev/null || {
  pushd /usr/local/bin
  wget -q https://releases.hashicorp.com/nomad/0.8.7/nomad_0.8.7_linux_amd64.zip
  unzip nomad_0.8.7_linux_amd64.zip
  chmod +x nomad
  popd
}

which http-echo &>/dev/null || {
  pushd /usr/local/bin
  wget -q https://github.com/hashicorp/http-echo/releases/download/v0.2.3/http-echo_0.2.3_linux_amd64.zip
  unzip http-echo_0.2.3_linux_amd64.zip
  chmod +x http-echo
  popd
}

grep NOMAD_ADDR ~/.bash_profile &>/dev/null || {
  echo export NOMAD_ADDR=http://${IP}:4646 | tee -a ~/.bash_profile
}

# check for nomad hostname => server
if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
  if [ "${TRAVIS}" == "true" ]; then
    create_service_user nomad
    sudo usermod -a -G consulcerts nomad
    sudo -u nomad /usr/local/bin/nomad agent -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d >${LOG} &
  else
    NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
      create_service nomad "HashiCorp's Nomad Server - A Modern Platform and Cloud Agnostic Scheduler" "/usr/local/bin/nomad agent -log-level=DEBUG -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d"
      sudo usermod -a -G consulcerts nomad
      cp -apr /usr/local/bootstrap/conf/nomad.d /etc
      sudo systemctl start nomad
      sudo systemctl status nomad
      
    }
  fi
  sleep 1

else

  NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
    create_service nomad "HashiCorp's Nomad Agent - A Modern Platform and Cloud Agnostic Scheduler" "/usr/local/bin/nomad agent -log-level=DEBUG -client -bind=${IP} -data-dir=/usr/local/nomad -join=192.168.2.11 -config=/etc/nomad.d"
    sudo usermod -a -G consulcerts nomad
    cp -apr /usr/local/bootstrap/conf/nomad.d /etc
    sudo systemctl start nomad
    sudo systemctl status nomad
    sleep 1
  }

fi

exit 0

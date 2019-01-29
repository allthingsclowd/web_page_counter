#!/usr/bin/env bash

generate_certificate_config () {

  sudo mkdir -p /etc/pki/tls/private
  sudo mkdir -p /etc/pki/tls/certs
  sudo mkdir -p /etc/consul.d
  sudo cp -r /usr/local/bootstrap/certificate-config/${5}-key.pem /etc/pki/tls/private/${5}-key.pem
  sudo cp -r /usr/local/bootstrap/certificate-config/${5}.pem /etc/pki/tls/certs/${5}.pem
  sudo cp -r /usr/local/bootstrap/certificate-config/consul-ca.pem /etc/pki/tls/certs/consul-ca.pem
  sudo tee /etc/consul.d/consul_cert_setup.json <<EOF
  {
  "datacenter": "allthingscloud1",
  "data_dir": "/usr/local/consul",
  "log_level": "INFO",
  "server": ${1},
  "node_name": "${HOSTNAME}",
  "addresses": {
      "https": "0.0.0.0"
  },
  "ports": {
      "https": 8321,
      "http": -1
  },
  "verify_incoming": true,
  "verify_outgoing": true,
  "key_file": "$2",
  "cert_file": "$3",
  "ca_file": "$4"
  }
EOF

}

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
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
  fi

}

setup_environment () {
  set -x
  sleep 5
  source /usr/local/bootstrap/var.env
  
  IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
  IP=${CIDR%%/24}

  if [ -d /vagrant ]; then
    LOG="/vagrant/logs/consul_${HOSTNAME}.log"
  else
    LOG="consul.log"
  fi

  if [ "${TRAVIS}" == "true" ]; then
    IP=${IP:-127.0.0.1}
  fi

}

install_prerequisite_binaries () {
  # check consul binary
  [ -f /usr/local/bin/consul ] &>/dev/null || {
      pushd /usr/local/bin
      [ -f consul_1.4.2_linux_amd64.zip ] || {
          sudo wget -q https://releases.hashicorp.com/consul/1.4.2/consul_1.4.2_linux_amd64.zip
      }
      sudo unzip consul_1.4.2_linux_amd64.zip
      sudo chmod +x consul
      popd
  }

  # check consul-template binary
  [ -f /usr/local/bin/consul-template ] &>/dev/null || {
      pushd /usr/local/bin
      [ -f consul-template_0.19.5_linux_amd64.zip ] || {
          sudo wget -q https://releases.hashicorp.com/consul-template/0.19.5/consul-template_0.19.5_linux_amd64.zip
      }
      sudo unzip consul-template_0.19.5_linux_amd64.zip
      sudo chmod +x consul-template
      popd
  }

  # check envconsul binary
  [ -f /usr/local/bin/envconsul ] &>/dev/null || {
      pushd /usr/local/bin
      [ -f envconsul_0.7.3_linux_amd64.zip ] || {
          sudo wget -q https://releases.hashicorp.com/envconsul/0.7.3/envconsul_0.7.3_linux_amd64.zip
      }
      sudo unzip envconsul_0.7.3_linux_amd64.zip
      sudo chmod +x envconsul
      popd
  }
}

install_consul () {
  AGENT_CONFIG="-config-dir=/etc/consul.d -enable-script-checks=true"

  # Configure consul environment variables for use with certificates 
  export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
  export CONSUL_CACERT=/usr/local/bootstrap/certificate-config/consul-ca.pem
  export CONSUL_CLIENT_CERT=/usr/local/bootstrap/certificate-config/cli.pem
  export CONSUL_CLIENT_KEY=/usr/local/bootstrap/certificate-config/cli-key.pem
  
  # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT
  generate_certificate_config true "/etc/pki/tls/private/server-key.pem" "/etc/pki/tls/certs/server.pem" "/etc/pki/tls/certs/consul-ca.pem" server
  sudo groupadd consulcerts
  sudo chgrp -R consulcerts /etc/pki/tls
  sudo chmod -R 770 /etc/pki/tls

  # check for consul hostname or travis => server
  if [[ "${HOSTNAME}" =~ "leader" ]] || [ "${TRAVIS}" == "true" ]; then
    echo "Starting a Consul Server"

    /usr/local/bin/consul members 2>/dev/null || {
      if [ "${TRAVIS}" == "true" ]; then
        create_service_user consul
        # ensure consul service has permissions to access certificates
        sudo usermod -a -G consulcerts consul
        sudo -u consul cp -r /usr/local/bootstrap/conf/consul.d/* /etc/consul.d/.
        sudo -u consul /usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
      else
        create_service consul "HashiCorp Consul Server SD & KV Service" "/usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1"
        # ensure consul service has permissions to access certificates
        sudo usermod -a -G consulcerts consul
        sudo -u consul cp -r /usr/local/bootstrap/conf/consul.d/* /etc/consul.d/.
        # sudo -u consul /usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
        sudo systemctl start consul
        sudo systemctl status consul
      fi
      sleep 5
      # upload vars to consul kv
      echo "Quick test of the Consul KV store - upload the var.env parameters"
      while read a b; do
        k=${b%%=*}
        v=${b##*=}

        consul kv put "development/$k" $v

      done < /usr/local/bootstrap/var.env
    }
  else
    echo "Starting a Consul Agent"
    /usr/local/bin/consul members 2>/dev/null || {

        create_service consul "HashiCorp Consul Agent Service"  "/usr/local/bin/consul agent -log-level=debug -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -join=${LEADER_IP}"
        # ensure consul service has permissions to access certificates
        sudo usermod -a -G consulcerts consul
        sudo systemctl start consul
        sudo systemctl status consul
        sleep 10
    }
  fi

  echo "Consul Service Started"
}

setup_environment
install_prerequisite_binaries
install_consul
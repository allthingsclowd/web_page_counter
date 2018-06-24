#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/consul_${HOSTNAME}.log"
else
  LOG="consul.log"
fi

if [ "${TRAVIS}" == "true" ]; then
IP=${IP:-127.0.0.1}
fi

PKG="wget unzip"
which ${PKG} &>/dev/null || {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ${PKG}
}

[ -f /usr/local/bin/consul ] &>/dev/null || {
    pushd /usr/local/bin
    [ -f consul_1.1.0_linux_amd64.zip ] || {
        sudo wget https://releases.hashicorp.com/consul/1.1.0/consul_1.1.0_linux_amd64.zip
    }
    sudo unzip consul_1.1.0_linux_amd64.zip
    sudo chmod +x consul
    popd
}

AGENT_CONFIG="-config-dir=/etc/consul.d -enable-script-checks=true"
mkdir -p /etc/consul.d
# check for consul hostname or travis => server
if [[ "${HOSTNAME}" =~ "consul" ]] || [ "${TRAVIS}" == "true" ]; then
  echo server

  if [ "${TRAVIS}" == "true" ]; then
    SERVICE_DEFS_DIR="conf/consul.d"
    CONSUL_SCRIPTS="scripts"
    # copy a consul service definition directory
    sudo cp -r ${SERVICE_DEFS_DIR} /etc
    # ensure all scripts are executable for consul health checks
    pushd ${CONSUL_SCRIPTS}
    for file in `ls`;
      do
        sudo chmod +x $file
      done
    popd
  fi

  /usr/local/bin/consul members 2>/dev/null || {

      sudo /usr/local/bin/consul agent -server -ui -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
    
    sleep 5
    # upload vars to consul kv

    while read a b; do
      k=${b%%=*}
      v=${b##*=}

      consul kv put "development/$k" $v

    done < /usr/local/bootstrap/var.env
  }
else
  echo agent
  /usr/local/bin/consul members 2>/dev/null || {
    /usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} ${AGENT_CONFIG} -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &
    sleep 10
  }
fi
    
# NOTES to SELF
# verifiy via api
# root@godev01:~# curl http://localhost:8500/v1/kv/development/GO_DEV_IP | jq '.[]["Value"]' | base64 -di
#
# verify via cli
# root@godev01:~# consul kv get development/GO_DEV_IP
# 192.168.2.100

echo consul started

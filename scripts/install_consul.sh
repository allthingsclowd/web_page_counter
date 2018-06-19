#!/usr/bin/env bash

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}
IP=${IP:-127.0.0.1}

if [ -d /vagrant ]; then
  LOG="/vagrant/consul_${HOSTNAME}.log"
else
  LOG="consul.log"
fi

[ -f /usr/local/bin/consul ] &>/dev/null || {
    pushd /usr/local/bin
    [ -f consul_1.1.0_linux_amd64.zip ] || {
        sudo wget https://releases.hashicorp.com/consul/1.1.0/consul_1.1.0_linux_amd64.zip
    }
    sudo unzip consul_1.1.0_linux_amd64.zip
    sudo chmod +x consul
    popd
}

# check for consul hostname or travis => server
if [[ "${HOSTNAME}" =~ "consul" ]] || [ "${TRAVIS}" == "true" ]; then
  echo server
  /usr/local/bin/consul members 2>/dev/null || {
    sudo /usr/local/bin/consul agent -server -ui -client=0.0.0.0 -bind=${IP} -data-dir=/usr/local/consul -bootstrap-expect=1 >${LOG} &
    sleep 5
    # upload vars to consul kv

    wget -O /var/tmp/var.env https://raw.githubusercontent.com/allthingsclowd/golang_web_page_counter/master/var.env

    while read a b; do
      k=${b%%=*}
      v=${b##*=}

      consul kv put "development/$k" $v

    done < /var/tmp/var.env

  }
else
  echo agent
  /usr/local/bin/consul members 2>/dev/null || {
    /usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &
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

#display consul logs on travis
[ "${TRAVIS}" == "true" ] && cat ${LOG}

echo consul started

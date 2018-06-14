#!/usr/bin/env bash

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

# check for consul hostname => server
if [[ "${HOSTNAME}" =~ "consul" ]]; then
  echo server
  /usr/local/bin/consul members 2>/dev/null || {
    /usr/local/bin/consul agent -server -ui -client=0.0.0.0 -bind=${IP} -data-dir=/usr/local/consul -bootstrap-expect=1 >/vagrant/consul_${HOSTNAME}.log &
    sleep 1
    # upload vars to consul kv
  }
else
  echo agent
  /usr/local/bin/consul members 2>/dev/null || {
    /usr/local/bin/consul agent -bind=${IP} -data-dir=/usr/local/consul -join=192.168.2.11 >/vagrant/consul_${HOSTNAME}.log &
    sleep 1
  }
fi
    
echo consul started

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

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "${HOME}/vagrant_go_user" ]; then
    exit 0
fi

touch ${HOME}/vagrant_go_user
SOURCE=${HOME}/code/go/src/github.com/allthingsclowd/golang_web_page_counter
mkdir -p ${SOURCE}
echo "export GOPATH=${HOME}/code/go" >> ${HOME}/.bashrc
source $HOME/.bashrc
cp -r /vagrant/. ${SOURCE}
cd ${SOURCE}
go get ./...
go build main.go
echo "about to run go app"
sleep 20
./main >/vagrant/go_app_start_up_${HOSTNAME}.log &
echo " app should be started"

# copy a consul service definition directory
 mkdir -p /etc/consul.d
 cp -p /usr/local/bootstrap/conf/consul.d/goapp.json /etc/consul.d/goapp.json
 # lets kill past instance
 killall consul &>/dev/null
 sleep 5
 # start restart with config dir
 /usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &
 
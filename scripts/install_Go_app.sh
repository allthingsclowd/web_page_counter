#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

IFACES=`route -n | awk '$1 == "192.168.2.0" {print $8}'`
IFACE=`echo $IFACES | awk '{ print $1 }'`
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

# copy a consul service definition directory
mkdir -p /etc/consul.d
chmod +x /usr/local/bootstrap/scripts/consul_build_go_app_service.sh
apt-get install -y jq

export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
mkdir -p $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter
cp -r /usr/local/bootstrap/. $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter/
cd $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter
go get -t -v ./...
go build main.go
echo $1
DEFAULTPORT=0
if [ `echo $IFACES | wc -w` -gt 1 ]; then
  DEFAULTPORT=1
  for interface in $IFACES;
  do
    CIDR=`ip addr show $interface | awk '$2 ~ "192.168.2" {print $2}'`
    IFACEIP=${CIDR%%/24}
    ./main -port=808$DEFAULTPORT -ip=$IFACEIP >>/vagrant/goapp_${HOSTNAME}.log &
    HOSTURL="http://${IFACEIP}:808${DEFAULTPORT}/health"
    /usr/local/bootstrap/scripts/consul_build_go_app_service.sh /usr/local/bootstrap/conf/consul.d/goapp.json /etc/consul.d/goapp808${DEFAULTPORT}.json $HOSTURL 808${DEFAULTPORT}
    let DEFAULTPORT++
  done
else
  ./main -port=808$DEFAULTPORT -ip=$IP >>/vagrant/goapp_${HOSTNAME}.log &
  /usr/local/bootstrap/scripts/consul_build_go_app_service.sh /usr/local/bootstrap/conf/consul.d/goapp.json /etc/consul.d/goapp808${DEFAULTPORT}.json $HOSTURL 808${DEFAULTPORT}
fi

sleep 5

# lets kill past instance
killall consul &>/dev/null
sleep 5
# start restart with config dir
/usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &


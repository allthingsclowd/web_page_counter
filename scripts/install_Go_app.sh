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

export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
mkdir -p $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter
cp -r /usr/local/bootstrap/. $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter/
cd $HOME/gopath/src/github.com/allthingsclowd/golang_web_page_counter
go get -t -v ./...
go build main.go
echo $1
./main -port=$1 >>/vagrant/goapp_${HOSTNAME}.log &

echo "debug delay - sleep 5"
sleep 5

# copy a consul service definition directory
mkdir -p /etc/consul.d
chmod +x /usr/local/bootstrap/scripts/consul_build_go_app_service.sh
apt install -y jq

if [ $LISTENER_COUNT -gt 1 ]; then
  COUNTER=1
  let LISTENER_COUNT++

  while [ $COUNTER -lt $LISTENER_COUNT ]; do
    HOSTURL="http://${IP}:808${COUNTER}/health"
    /usr/local/bootstrap/scripts/consul_build_go_app_service.sh /usr/local/bootstrap/conf/consul.d/goapp.json /etc/consul.d/goapp${COUNTER}.json $HOSTURL 808${COUNTER}
    let COUNTER=COUNTER+1 
  done
else
  COUNTER=0
  HOSTURL="http://${IP}:808${COUNTER}/health"
  /usr/local/bootstrap/scripts/consul_build_go_app_service.sh /usr/local/bootstrap/conf/consul.d/goapp.json /etc/consul.d/goapp${COUNTER}.json $HOSTURL 808${COUNTER}
fi

# lets kill past instance
killall consul &>/dev/null
sleep 5
# start restart with config dir
/usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &


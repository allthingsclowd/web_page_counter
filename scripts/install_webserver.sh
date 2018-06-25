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
#if [ -f "/var/vagrant_web_server" ]; then
#    exit 0
#fi

#touch /var/vagrant_web_server

# remove nginx default website
sudo rm -f /etc/nginx/sites-enabled/default

# copy a consul service definition directory
sudo mkdir -p /etc/consul.d
sudo cp -p /usr/local/bootstrap/conf/consul.d/webtier.json /etc/consul.d/webtier.json

# make consul reload conf
sudo killall -1 consul

sudo /usr/local/bin/consul-template \
     -consul-addr=$CONSUL_IP:8500 \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:service nginx reload" &
     

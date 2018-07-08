#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_web_server" ]; then
   exit 0
fi

touch /var/vagrant_web_server

# potentially add jq to base image
sudo apt-get install -y jq

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
     
sudo /usr/local/bin/consul-template \
     -consul-addr=$CONSUL_IP:8500 \
     -template "/usr/local/bootstrap/conf/metric.ctpl:/usr/local/datadog/metric.json:/usr/local/bin/updateDDGuage" &
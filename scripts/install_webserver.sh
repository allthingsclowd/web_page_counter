#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

which jq &>/dev/null || {
  # potentially add jq to base image
  sudo apt-get update
  sudo apt-get install -y jq
}
# remove nginx default website
[ -f /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default

# copy a consul service definition directory
sudo mkdir -p /etc/consul.d
sudo cp -p /usr/local/bootstrap/conf/consul.d/webtier.json /etc/consul.d/webtier.json

# make consul reload conf
sudo killall -1 consul
sudo killall -9 consul-template &>/dev/null

sleep 2

sudo /usr/local/bin/consul-template \
     -consul-addr=${LEADER_IP}:8500 \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:/usr/local/bootstrap/scripts/updateBackendCount.sh" &
   
sleep 1


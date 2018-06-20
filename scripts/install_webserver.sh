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
if [ -f "/var/vagrant_web_server" ]; then
    exit 0
fi

touch /var/vagrant_web_server

# remove nginx default website
sudo rm -f /etc/nginx/sites-enabled/default

[ -f /usr/local/bin/consul-template ] &>/dev/null || {
    pushd /usr/local/bin
    [ -f consul-template_0.19.5_linux_amd64.zip ] || {
        sudo wget https://releases.hashicorp.com/consul-template/0.19.5/consul-template_0.19.5_linux_amd64.zip
    }
    sudo unzip consul-template_0.19.5_linux_amd64.zip
    sudo chmod +x consul-template
    popd
}

sudo /usr/local/bin/consul-template \
     -consul-addr=$CONSUL_IP:8500 \
     -template "/usr/local/bootstrap/conf/nginx.ctpl:/etc/nginx/conf.d/goapp.conf:service nginx reload" &

# copy a consul service definition directory
 sudo mkdir -p /etc/consul.d
 sudo cp -p /usr/local/bootstrap/conf/consul.d/webtier.json /etc/consul.d/webtier.json
 # lets kill past instance
 sudo killall consul &>/dev/null
 sleep 5
 # start restart with config dir
 sudo /usr/local/bin/consul agent -client=0.0.0.0 -bind=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -join=${CONSUL_IP} >${LOG} &

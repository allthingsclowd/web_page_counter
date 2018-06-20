#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

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

#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "/var/vagrant_web_server" ]; then
    exit 0
fi

touch /var/vagrant_web_server
sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install -y nginx=1.10.3-0ubuntu0.16.04.2
sudo rm /etc/nginx/sites-enabled/default
sed -i 's/GO_DEV_IP/'"$GO_DEV_IP"'/' nginx.conf
sed -i 's/GO_DEV_GUEST_PORT/'"$GO_GUEST_PORT"'/' nginx.conf
sed -i 's/NGINX_GUEST_PORT/'"$NGINX_GUEST_PORT"'/' nginx.conf
sudo cp /usr/local/bootstrap/conf/nginx.conf /etc/nginx/sites-available/default
sudo chmod 777 /etc/nginx/sites-available/default
sudo chown root:root /etc/nginx/sites-available/default
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
sudo service nginx reload

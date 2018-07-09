#!/usr/bin/env bash
sudo service nginx reload

metric=`grep '192.168.2' /etc/nginx/conf.d/goapp.conf | wc -l`
name="backendtotal"

echo "${name}:${metric}|g|#web"
echo -n "${name}:${metric}|g|#web" >/dev/udp/localhost/8125

echo -n "bananatest:42|g|#web" >/dev/udp/localhost/8125


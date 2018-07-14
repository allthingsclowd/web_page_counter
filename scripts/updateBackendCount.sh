#!/usr/bin/env bash
sudo service nginx reload 2&>1 /dev/null

metric=`grep '192.168.2' /etc/nginx/conf.d/goapp.conf | wc -l`
name="WebCounterServiceTotal"

echo -n "${name}:${metric}|g|#web" >/dev/udp/127.0.0.1/8125

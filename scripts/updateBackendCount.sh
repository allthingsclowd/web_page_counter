#!/usr/bin/env bash
sudo service nginx reload 2&>1 /dev/null

#event due change of backends
title="Change of number of backend"
text="A number of backend servers have happened"
echo -n "_e{${#title},${#text}}:${title}|${text}|#web"  >/dev/udp/127.0.0.1/8125

#update number of backend service
metric=`grep '192.168.2' /etc/nginx/conf.d/goapp.conf | wc -l`
name="WebCounterServiceTotal"
echo -n "${name}:${metric}|g|#web" >/dev/udp/127.0.0.1/8125

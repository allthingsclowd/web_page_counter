#!/usr/bin/env bash

which wget unzip &>/dev/null || {
  apt-get update
  apt-get install -y wget unzip 
}

which /usr/local/bin/consul &>/dev/null || {
  pushd /usr/local/bin
  wget https://releases.hashicorp.com/consul/1.1.0/consul_1.1.0_linux_amd64.zip
  unzip consul_1.1.0_linux_amd64.zip
  chmod +x consul
  popd
}


/usr/local/bin/consul members 2>/dev/null || {
  /usr/local/bin/consul agent -dev -ui -client=0.0.0.0 >/vagrant/consul.log & 
}

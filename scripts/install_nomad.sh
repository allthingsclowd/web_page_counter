#!/usr/bin/env bash

source /usr/local/bootstrap/var.env

IFACE=`route -n | awk '$1 == "192.168.2.0" {print $8;exit}'`
CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.2" {print $2}'`
IP=${CIDR%%/24}

if [ -d /vagrant ]; then
  LOG="/vagrant/nomad_${HOSTNAME}.log"
else
  LOG="nomad.log"
fi

which wget unzip &>/dev/null || {
  apt-get update
  apt-get install -y wget unzip 
}

which nomad &>/dev/null || {
  pushd /usr/local/bin
  wget https://releases.hashicorp.com/nomad/0.8.4/nomad_0.8.4_linux_amd64.zip
  unzip nomad_0.8.4_linux_amd64.zip
  chmod +x nomad
  popd
}

grep NOMAD_ADDR ~/.bash_profile &>/dev/null || {
  echo export NOMAD_ADDR=http://${IP}:4646 | tee -a ~/.bash_profile
}

# check for nomad hostname => server
if [[ "${HOSTNAME}" =~ "leader" ]]; then

  NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
    /usr/local/bin/nomad agent -server -bind=${IP} -data-dir=/usr/local/nomad -bootstrap-expect=1 > ${LOG} &
    sleep 1
  }

else

  NOMAD_ADDR=http://${IP}:4646 /usr/local/bin/nomad agent-info 2>/dev/null || {
    /usr/local/bin/nomad agent -client -bind=${IP} -data-dir=/usr/local/nomad -join=192.168.2.11 > ${LOG} &
    sleep 1
  }

fi

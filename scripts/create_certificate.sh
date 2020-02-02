#!/usr/bin/env bash

setup_environment () {
  set -x
  sleep 5
  source /usr/local/bootstrap/var.env
  
  IFACE=`route -n | awk '$1 == "192.168.9.0" {print $8;exit}'`
  CIDR=`ip addr show ${IFACE} | awk '$2 ~ "192.168.9" {print $2}'`
  IP=${CIDR%%/24}
 
}

create_certificate () {
  # ${1} domain e.g. consul
  # ${2} data centre e..g. DC1
  # ${3} certificate duration in days
  # ${4} additional ip addresses
  # ${5} cert type either server, client or cli

  [ -f /${ROOTCERTPATH}/${1}.d/pki/tls/private/${1}-${5}-key.pem ] &>/dev/null || {
    echo "Start generating ${5} certificates for data centre ${2} with domain ${1}"
    sudo mkdir --parent /${ROOTCERTPATH}/${1}.d/pki/tls/private /${ROOTCERTPATH}/${1}.d/pki/tls/certs
    pushd /${ROOTCERTPATH}/${1}.d/pki/tls/private
    sudo /usr/local/bin/consul tls cert create \
                                -domain=${1} \
                                -dc=${2} \
                                -key=/${ROOTCERTPATH}/ssl/private/${1}-agent-ca-key.pem \
                                -ca=/${ROOTCERTPATH}/ssl/certs/${1}-agent-ca.pem \
                                -days=${3} \
                                -additional-ipaddress=${4} \
                                -${5} 
                                
    sudo mv ${2}-${5}-${1}-0.pem /${ROOTCERTPATH}/${1}.d/pki/tls/certs/${1}-${5}.pem
    sudo mv ${2}-${5}-${1}-0-key.pem /${ROOTCERTPATH}/${1}.d/pki/tls/private/${1}-${5}-key.pem

    sudo -u ${1} chmod 644 /${ROOTCERTPATH}/${1}.d/pki/tls/certs/${1}-${5}.pem
    sudo -u ${1} chmod 644 /${ROOTCERTPATH}/${1}.d/pki/tls/private/${1}-${5}-key.pem  

    # debug
    sudo ls -al /${ROOTCERTPATH}/${1}.d/pki/tls/private/
    sudo ls -al /${ROOTCERTPATH}/${1}.d/pki/tls/certs/
    popd
    echo "Finished generating ${5} certificates for data centre ${2} with domain ${1}" 
  }
}

setup_environment
create_certificate $1 $2 $3 $4 $5

exit 0

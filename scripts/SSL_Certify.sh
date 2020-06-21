#!/usr/bin/env bash

set -x

IPS=`hostname -I | sed 's/ /,/g' | sed 's/,*$//g'`

{ [ -f /usr/local/bootstrap/.bootstrap/Outputs/IntermediateCAs/BootstrapCAs.sh ] && source /usr/local/bootstrap/.bootstrap/Outputs/IntermediateCAs/BootstrapCAs.sh; } || \
    { echo -e "!!!!!!STOP!!!!!!\n Missing /usr/local/bootstrap/.bootstrap/CA/BootstrapCAs.sh file \n" && exit 1; }
{ [ -f /usr/local/bootstrap/var.env ] && source /usr/local/bootstrap/var.env; } || \
    { echo -e "!!!!!!STOP!!!!!!\n Missing /usr/local/bootstrap/var.env file \n" && exit 1; }

export BootStrapCertTool="https://raw.githubusercontent.com/allthingsclowd/BootstrapCertificateTool/${certversion}/scripts/Generate_PKI_Certificates_For_Lab.sh"

# Generate OpenSSL Certs
wget -O - ${BootStrapCertTool} | bash -s consul "server.node.global.consul" "client.node.global.consul" "${IPS}" 
wget -O - ${BootStrapCertTool} | bash -s nomad "server.global.nomad" "client.global.nomad" "${IPS}" 
wget -O - ${BootStrapCertTool} | bash -s vault "server.global.vault" "client.global.vault" "${IPS}" 
wget -O - ${BootStrapCertTool} | bash -s wpc "server.global.wpc" "client.global.wpc" "${IPS}"
wget -O - ${BootStrapCertTool} | bash -s nginx "server.global.nginx" "client.global.nginx" "${IPS}"
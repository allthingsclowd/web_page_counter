#!/usr/bin/env bash

set -x

# https://raw.githubusercontent.com/allthingsclowd/BootstrapCertificateTool/master/scripts/BootStrapMe.sh
#{ [ -f /usr/local/bootstrap/.bootstrap/CA/BootstrapCAs.sh ] && source /usr/local/bootstrap/.bootstrap/CA/BootstrapCAs.sh; } || \
#    { echo -e "!!!!!!STOP!!!!!!\n Missing /usr/local/bootstrap/.bootstrap/CA/BootstrapCAs.sh file \n" && exit 1; }
{ [ -f /usr/local/bootstrap/var.env ] && source /usr/local/bootstrap/var.env; } || \
    { echo -e "!!!!!!STOP!!!!!!\n Missing /usr/local/bootstrap/var.env file \n" && exit 1; }
certversion=master
export BootstrapSSHTool="https://raw.githubusercontent.com/allthingsclowd/BootstrapCertificateTool/${certversion}/scripts/BootStrapMe.sh"
# Generate OpenSSH Certs
wget -O - ${BootstrapSSHTool} | PACKERHOST_ssh_rsa_ca_pub=${PACKERHOST_ssh_rsa_ca_pub};PACKERHOST_ssh_rsa_ca=${PACKERHOST_ssh_rsa_ca};PACKERUSER_ssh_rsa_ca_pub=${PACKERUSER_ssh_rsa_ca_pub};PACKERUSER_ssh_rsa_ca=${PACKERUSER_ssh_rsa_ca} sudo bash -s - -H -n PACKERHOST -h ${HOSTNAME} -s
wget -O - ${BootstrapSSHTool} | PACKERHOST_ssh_rsa_ca_pub=${PACKERHOST_ssh_rsa_ca_pub};PACKERHOST_ssh_rsa_ca=${PACKERHOST_ssh_rsa_ca};PACKERUSER_ssh_rsa_ca_pub=${PACKERUSER_ssh_rsa_ca_pub};PACKERUSER_ssh_rsa_ca=${PACKERUSER_ssh_rsa_ca} sudo bash -s - -U -n PACKERUSER -u packman -b "graham,grazzer,pi,root" -s

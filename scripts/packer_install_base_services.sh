#!/usr/bin/env bash

create_service () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/${1}.d/
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=${4}
User=${1}
Group=${1}
PIDFile=/var/run/${1}/${1}.pid
PermissionsStartOnly=true
ExecStartPre=/bin/mkdir -p /var/run/${1}
ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
ExecStart=${3}
ExecReload=/bin/kill -HUP ${MAINPID}
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=2s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  fi

}

create_vault_serviced () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
### BEGIN INIT INFO
# Provides:          ${1}
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${1} agent
# Description:       ${2}
### END INIT INFO

[Unit]
Description=${2}
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/${1}.d/
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=${1}
Group=${1}
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=${3}
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

  fi

}

create_root_CA_certificate () {

  # ${1} - domain name - e.g. consul
  # ${2} - duration in days that CA is valid for

  # create file layout for the certs
  [ -d /etc/ssl/CA ] &>/dev/null || {
    sudo mkdir /etc/ssl/CA
  }
  sudo pushd /etc/ssl/CA
  sudo /usr/local/bin/consul tls ca create -domain=${1} -days=${2}
  sudo mv /etc/ssl/CA/${1}-agent-ca.pem /etc/ssl/certs/.
  sudo mv /etc/ssl/CA/${1}-agent-ca-key.pem /etc/ssl/private/.
  sudo chmod -R 644 /etc/ssl/certs
  sudo chmod -R 600 /etc/ssl/private
  sudo ls -al /etc/ssl/certs /etc/ssl/private
  sudo popd

}

configure_certificates () {

    # create nomad directories
    sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private /etc/nomad.d/pki/tls/certs
    sudo -u nomad chmod -R 644 /etc/nomad.d/pki/tls/certs
    sudo -u nomad chmod -R 600 /etc/nomad.d/pki/tls/private

    sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private /etc/consul.d/pki/tls/certs
    sudo -u consul chmod -R 644 /etc/consul.d/pki/tls/certs
    sudo -u consul chmod -R 600 /etc/consul.d/pki/tls/private

    sudo -u vault mkdir --parents /etc/vault.d/pki/tls/private /etc/vault.d/pki/tls/certs
    sudo -u vault chmod -R 644 /etc/vault.d/pki/tls/certs
    sudo -u vault chmod -R 600 /etc/vault.d/pki/tls/private


    # # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT

    # # Temp - dump all certs into directory for testing mTLS later
    # sudo mkdir --parents /tmp/HashiStack_Certs
    # sudo cp -R /usr/local/bootstrap/certificate-config /tmp/HashiStack_Certs

    # # move vault certificates into place
    # sudo -u vault mkdir --parents /etc/vault.d/pki/tls/private/vault /etc/vault.d/pki/tls/certs/vault /etc/vault.d/pki/tls/certs/hashistack
    # sudo -u vault mkdir --parents /etc/vault.d/pki/tls/private/consul /etc/vault.d/pki/tls/certs/consul

    # sudo -u vault cp -r /usr/local/bootstrap/certificate-config/vault/vault-server-key.pem /etc/vault.d/pki/tls/private/vault/vault-server-key.pem
    # sudo -u vault cp -r /usr/local/bootstrap/certificate-config/vault/vault-server.pem /etc/vault.d/pki/tls/certs/vault/vault-server.pem
    # # Consul certs for Vault
    # sudo -u vault cp -r /etc/consul.d/pki/tls/private/consul-client-key.pem /etc/vault.d/pki/tls/private/consul/consul-client-key.pem
    # sudo -u vault cp -r /etc/consul.d/pki/tls/certs/consul-client.pem /etc/vault.d/pki/tls/certs/consul/consul-client.pem
    # sudo -u vault cp -r /etc/ssl/certs/consul-agent-ca.pem /etc/vault.d/pki/tls/certs/hashistack/hashistack-ca.pem

    # # move consul certificates into place
    # sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/vault /etc/consul.d/pki/tls/certs/vault /etc/consul.d/pki/tls/certs/hashistack
    # sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/consul /etc/consul.d/pki/tls/certs/consul
    
    # # consul servers
    # sudo -u consul cp -r /usr/local/bootstrap/certificate-config/consul/consul-server-key.pem /etc/consul.d/pki/tls/private/consul/consul-server-key.pem
    # sudo -u consul cp -r /usr/local/bootstrap/certificate-config/consul/consul-server.pem /etc/consul.d/pki/tls/certs/consul/consul-server.pem
    # # consul agents (clients)
    # sudo -u consul cp -r /etc/consul.d/pki/tls/private/consul-client-key.pem /etc/consul.d/pki/tls/private/consul-client-key.pem
    # sudo -u consul cp -r /etc/consul.d/pki/tls/certs/consul-client.pem /etc/consul.d/pki/tls/certs/consul-client.pem
    # sudo -u consul cp -r /etc/ssl/certs/consul-agent-ca.pem /etc/consul.d/pki/tls/certs/hashistack/hashistack-ca.pem
    
    # # move consul certificates for nomad in place
    # sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private/nomad /etc/nomad.d/pki/tls/certs/nomad /etc/nomad.d/pki/tls/certs/hashistack
    # sudo -u nomad mkdir --parents /etc/nomad.d/pki/tls/private/consul /etc/nomad.d/pki/tls/certs/consul

    # sudo -u nomad cp -r /usr/local/bootstrap/certificate-config/nomad/nomad-server-key.pem /etc/nomad.d/pki/tls/private/nomad/nomad-server-key.pem
    # sudo -u nomad cp -r /usr/local/bootstrap/certificate-config/nomad/nomad-server.pem /etc/nomad.d/pki/tls/certs/nomad/nomad-server.pem
    # sudo -u nomad cp -r /etc/ssl/certs/consul-agent-ca.pem /etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem

    # sudo -u nomad cp -r /etc/consul.d/pki/tls/private/consul-client-key.pem /etc/nomad.d/pki/tls/private/consul/consul-client-key.pem
    # sudo -u nomad cp -r /etc/consul.d/pki/tls/certs/consul-client.pem /etc/nomad.d/pki/tls/certs/consul/consul-client.pem   
   
    # copy ssh CA certificate onto host
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
    sudo chmod 644 /etc/ssh/ssh_host_rsa_key.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key-cert.pub /etc/ssh/ssh_host_rsa_key-cert.pub
    sudo chmod 644 /etc/ssh/ssh_host_rsa_key-cert.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/client-ca.pub /etc/ssh/client-ca.pub
    sudo chmod 644 /etc/ssh/client-ca.pub
    sudo cp -r /usr/local/bootstrap/certificate-config/ssh_host/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
    sudo chmod 600 /etc/ssh/ssh_host_rsa_key
    # enable ssh CA certificate
    grep -qxF 'TrustedUserCAKeys /etc/ssh/client-ca.pub' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/client-ca.pub' | sudo tee -a /etc/ssh/sshd_config
    grep -qxF 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' /etc/ssh/sshd_config || echo 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' | sudo tee -a /etc/ssh/sshd_config
}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    
    echo "Creating ${1} user to run the ${1} service"
    sudo groupadd -f -r ${1}
    sudo useradd -g ${1} --system --home-dir /etc/${1}.d --create-home --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown -R ${1}:${1} /opt/${1} /usr/local/${1} /etc/${1}.d

  fi

}

create_consul_service () {
    
    create_service consul "HashiCorp Consul Server SD & KV Service" "/usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} -join=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -bootstrap-expect=1" notify
    sudo systemctl disable consul
}

create_vault_service () {
    
    sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
    create_vault_serviced vault "HashiCorp Secret Management Service" "/usr/local/bin/vault server -dev -dev-root-token-id=\"reallystrongpassword\" -config=/etc/vault.d/vault.hcl"
    sudo systemctl disable vault
}

create_nomad_service () {
    
    create_service nomad "HashiCorp's Nomad Server - A Modern Platform and Cloud Agnostic Scheduler" "/usr/local/bin/nomad agent -log-level=DEBUG -server -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d" simple
    sudo systemctl disable nomad
}

create_envoy_service () {
    
    create_service envoy "Envoy Proxy Server" "/usr/bin/envoy" simple
    sudo systemctl disable envoy
}

create_consul_service
create_vault_service
create_nomad_service
create_envoy_service

create_root_CA_certificate consul 30
create_root_CA_certificate vault 30
create_root_CA_certificate nomad 30
configure_certificates

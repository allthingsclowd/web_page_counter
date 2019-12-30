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
Type=notify
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
ProtectSystem=full
ProtectHome=read-only
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

configure_certificates () {
    # copy the example certificates into the correct location - PLEASE CHANGE THESE FOR A PRODUCTION DEPLOYMENT

    # move vault certificates into place
    sudo -u vault mkdir --parents /etc/vault.d/pki/tls/private/vault /etc/vault.d/pki/tls/certs/vault
    sudo -u vault mkdir --parents /etc/vault.d/pki/tls/private/consul /etc/vault.d/pki/tls/certs/consul
    sudo -u vault cp -r /usr/local/bootstrap/certificate-config/hashistack-server-key.pem /etc/vault.d/pki/tls/private/vault/hashistack-server-key.pem
    sudo -u vault cp -r /usr/local/bootstrap/certificate-config/hashistack-server.pem /etc/pki/tls/certs/vault/hashistack-server.pem

    sudo -u vault cp -r /usr/local/bootstrap/certificate-config/server-key.pem /etc/vault.d/pki/tls/private/consul/server-key.pem
    sudo -u vault cp -r /usr/local/bootstrap/certificate-config/server.pem /etc/vault.d/pki/tls/certs/consul/server.pem
    sudo -u vault cp -r /usr/local/bootstrap/certificate-config/consul-ca.pem /etc/vault.d/pki/tls/certs/consul/consul-ca.pem

    # move consul certificates into place
    sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/vault /etc/consul.d/pki/tls/certs/vault
    sudo -u consul mkdir --parents /etc/consul.d/pki/tls/private/consul /etc/consul.d/pki/tls/certs/consul
    
    sudo -u consul cp -r /usr/local/bootstrap/certificate-config/server-key.pem /etc/consul.d/pki/tls/private/consul/server-key.pem
    sudo -u consul cp -r /usr/local/bootstrap/certificate-config/server.pem /etc/consul.d/pki/tls/certs/consul/server.pem
    sudo -u consul cp -r /usr/local/bootstrap/certificate-config/consul-ca.pem /etc/consul.d/pki/tls/certs/consul/consul-ca.pem
    
}

create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    
    echo "Creating ${1} user to run the ${1} service"
    sudo groupadd -f -r ${1}
    sudo useradd -g ${1} --system --home-dir /etc/${1}.d --create-home --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chgrp ${1} /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown :${1} /usr/local/bin/${1}
  fi

}

create_consul_service () {
    
    create_service consul "HashiCorp Consul Server SD & KV Service" "/usr/local/bin/consul agent -server -log-level=debug -ui -client=0.0.0.0 -bind=${IP} -join=${IP} -config-dir=/etc/consul.d -enable-script-checks=true -data-dir=/usr/local/consul -bootstrap-expect=1"
    sudo systemctl disable consul
}

create_vault_service () {
    
    sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
    create_vault_serviced vault "HashiCorp Secret Management Service" "/usr/local/bin/vault server -dev -dev-root-token-id=\"reallystrongpassword\" -config=/etc/vault.d/vault.hcl"
    sudo systemctl disable vault
}

create_nomad_service () {
    
    create_service nomad "HashiCorp's Nomad Server - A Modern Platform and Cloud Agnostic Scheduler" "/usr/local/bin/nomad agent -log-level=DEBUG -server -data-dir=/usr/local/nomad -bootstrap-expect=1 -config=/etc/nomad.d"
    sudo systemctl disable nomad
}

create_envoy_service () {
    
    create_service envoy "Envoy Proxy Server" "/usr/bin/envoy"
    sudo systemctl disable envoy
}

create_consul_service
create_vault_service
create_nomad_service
create_envoy_service

configure_certificates

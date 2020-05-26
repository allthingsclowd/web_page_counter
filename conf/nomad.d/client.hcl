consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/ssl/certs/consul-ca-chain.pem"
  cert_file = "/etc/consul.d/pki/tls/certs/consul-peer.pem"
  key_file  = "/etc/consul.d/pki/tls/private/consul-peer-key.pem"
  token = "820ce2dc-db49-8598-ac52-e6e6ae138510"
  }

datacenter = "hashistack1"

client {
  options = {
    "driver.raw_exec" = "1"
    "driver.raw_exec.enable" = "1"
  }
  network_interface = "enp0s8"

  enabled = true

  servers = ["192.168.9.11:4647"]
}

# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/usr/local/nomad"

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/ssl/certs/nomad-ca-chain.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/nomad-cli.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/nomad-cli-key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}

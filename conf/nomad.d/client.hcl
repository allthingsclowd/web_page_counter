client {
  options = {
    "driver.raw_exec" = "1"
    "driver.raw_exec.enable" = "1"
  }
  network_interface = "enp0s8"
}

# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/usr/local/nomad"

# Enable the client
client {
  enabled = true

  # For demo assume we are talking to server1. For production,
  # this should be like "nomad.service.consul:4647" and a system
  # like Consul used for service discovery.
  servers = ["127.0.0.1:4647"]
}

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/ssl/certs/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/nomad-client.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/nomad-client-key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}
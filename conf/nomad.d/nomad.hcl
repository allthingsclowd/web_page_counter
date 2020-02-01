consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/consul/consul-client.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/consul/consul-client-key.pem"
  token = "3657575e-beb0-db74-51ed-7c3ff0f41e04"
  }

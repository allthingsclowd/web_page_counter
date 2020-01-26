consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/consul/consul-server.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/consul/consul-server-key.pem"
  token = "40a79cbf-b2bc-89f1-2df2-2325c99965c6"
  }

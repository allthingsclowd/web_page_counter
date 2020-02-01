consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/consul/consul-client.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/consul/consul-client-key.pem"
  token = "3a01d389-a3e9-312f-324c-df87cc3a82a2"
  }

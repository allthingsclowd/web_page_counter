consul {
  address = "127.0.0.1:8321"
  ssl       = true
  ca_file   = "/etc/nomad.d/pki/tls/certs/hashistack/hashistack-ca.pem"
  cert_file = "/etc/nomad.d/pki/tls/certs/consul/consul-client.pem"
  key_file  = "/etc/nomad.d/pki/tls/private/consul/consul-client-key.pem"
  token = "85b7214f-23c5-ebd4-3f61-82db21b9a947"
  }

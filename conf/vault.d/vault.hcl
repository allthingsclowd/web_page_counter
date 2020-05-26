  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/ssl/certs/consul-ca-chain.pem"
    tls_cert_file = "/etc/consul.d/pki/tls/certs/consul-peer.pem"
    tls_key_file = "/etc/consul.d/pki/tls/private/consul-peer-key.pem"
    token = "8bbbc0b1-782f-e2aa-ffe0-335dc5207d9d"
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/etc/vault.d/pki/tls/certs/vault-server.pem"
    tls_key_file = "/etc/vault.d/pki/tls/private/vault-server-key.pem"
  }

  # Advertise the non-loopback interface
  api_addr = "https://192.168.9.11:8322"
  cluster_addr = "https://192.168.9.11:8322"

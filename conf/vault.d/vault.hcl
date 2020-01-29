  storage "consul" {
    address = "127.0.0.1:8321"
    scheme = "https"
    path    = "vault/"
    tls_ca_file = "/etc/vault.d/pki/tls/certs/hashistack/hashistack-ca.pem"
    tls_cert_file = "/etc/vault.d/pki/tls/certs/consul/consul-client.pem"
    tls_key_file = "/etc/vault.d/pki/tls/private/consul/consul-client-key.pem"
    token = ""
  }

  ui = true

  listener "tcp" {
    address = "0.0.0.0:8322"
    tls_disable = 0
    tls_cert_file = "/etc/vault.d/pki/tls/certs/vault/vault-server.pem"
    tls_key_file = "/etc/vault.d/pki/tls/private/vault/vault-server-key.pem"
  }

  # Advertise the non-loopback interface
  api_addr = "https://192.168.9.11:8322"
  cluster_addr = "https://192.168.9.11:8322"

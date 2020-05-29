variable "vsphere_user" {
  description = "vCentre User"
}

variable "vsphere_password" {
  description = "vCentre User Password"
}

variable "vsphere_server" {
  description = "vCentre IP Address"
}

variable "bastion_host" {
  description = "Bastion Host IP Address or DNS Name"
}

variable "bastion_port" {
  description = "Bastion Port Number"
}

variable "bastion_user" {
  description = "Bastion Host Username for IAC code delivery"
}

variable "bastion_private_key" {
  description = "Bastion Host Private Key"
}

variable "bastion_certificate" {
  description = "Bastion Host Public Certificate"
}

variable "bastion_host_key" {
  description = "Bastion Host Public CA Signing Certificate"
}

// variable "bastion_password" {
//  description = "Bastion Host User Password"
// }

variable "ssh_certificate" {
  description = "SSH Signed Certificate"
}

variable "ssh_private_key" {
  description = "SSH Private Key"
}

variable "ssh_host_key" {
  description = "SSH Host CA Signing Public Key"
}

variable "consul_intermediate_ca_key" {
  description = "Consul Intermediate CA Private Key"
}

variable "vault_intermediate_ca_key" {
  description = "Vault Intermediate CA Private Key"
}

variable "nomad_intermediate_ca_key" {
  description = "Vault Intermediate CA Private Key"
}

variable "ssh_intermediate_ca_key" {
  description = "SSH Intermediate CA Private Key"
}

variable "bastion_intermediate_ca_key" {
  description = "Bastion Intermediate CA Private Key"
}



variable "wpc_intermediate_ca_key" {
  description = "Web-Page-Counter Application Intermediate CA Private Key"
}

variable "ca_keys" {
  default = [
    {
      app_name   = "consul"
      key_name = "consul-intermediate-ca-key.pem"
      key_value = var.consul_intermediate_ca_key
    },
    {
      app_name   = "vault"
      key_name = "vault-intermediate-ca-key.pem"
      key_value = var.vault_intermediate_ca_key
    },
    {
      app_name   = "nomad"
      key_name = "nomad-intermediate-ca-key.pem"
      key_value = var.nomad_intermediate_ca_key
    },
    {
      app_name   = "ssh"
      key_name = "ssh-intermediate-ca-key.pem"
      key_value = var.ssh_intermediate_ca_key
    },
    {
      app_name   = "bastion"
      key_name = "bastion-intermediate-ca-key.pem"
      key_value = var.bastion_intermediate_ca_key
    },
    {
      app_name   = "wpc"
      key_name = "wpc-intermediate-ca-key.pem"
      key_value = var.wpc_intermediate_ca_key
    },        
  ]
}



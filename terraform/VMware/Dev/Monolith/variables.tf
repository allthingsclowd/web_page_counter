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

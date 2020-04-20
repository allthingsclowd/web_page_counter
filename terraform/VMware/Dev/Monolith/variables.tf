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

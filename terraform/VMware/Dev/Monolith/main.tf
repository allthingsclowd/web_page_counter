provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "GrazzerHomeLab"
}

data "vsphere_datastore" "datastore" {
  name          = "IntelDS2"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "webpagecounter"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "DC1 Port Group"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "web-page-counter"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "vm01" {
  name             = "leader01"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 1
  memory   = 1024
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

  }

  provisioner "remote-exec" {
    inline = [
        "sudo chmod -R +x /usr/local/bootstrap/scripts",
        "touch /tmp/startingcloudinit.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/finishedcloudinit.txt",
    ]
  }

} 

resource "vsphere_virtual_machine" "vm02" {
  name             = "redis01"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 1
  memory   = 1024
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

  }
  
  provisioner "remote-exec" {
    inline = [
        "sudo chmod -R +x /usr/local/bootstrap/scripts",
        "touch /tmp/startingcloudinit.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/finishedcloudinit.txt",
    ]
  }

} 

resource "vsphere_virtual_machine" "vm03" {
  name             = "godev01"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 1
  memory   = 1024
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

  }

  provisioner "remote-exec" {
    inline = [
        "sudo chmod -R +x /usr/local/bootstrap/scripts",
        "touch /tmp/startingcloudinit.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/finishedcloudinit.txt",
    ]
  }


} 

resource "vsphere_virtual_machine" "vm04" {
  name             = "godev02"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 1
  memory   = 1024
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

  }

  provisioner "remote-exec" {
    inline = [
        "sudo chmod -R +x /usr/local/bootstrap/scripts",
        "touch /tmp/startingcloudinit.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/finishedcloudinit.txt",
    ]
  }


} 

resource "vsphere_virtual_machine" "vm05" {
  name             = "web01"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 1
  memory   = 1024
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

  }

  provisioner "remote-exec" {
    inline = [
        "sudo chmod -R +x /usr/local/bootstrap/scripts",
        "touch /tmp/startingcloudinit.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/finishedcloudinit.txt",
    ]
  }  

} 
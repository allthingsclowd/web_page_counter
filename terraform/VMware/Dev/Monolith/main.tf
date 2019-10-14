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
  name          = "DC1 VM Network"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "web-page-counter"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "leader01vm" {
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
    customize {
      network_interface {
        ipv4_address = "192.168.9.11"
        ipv4_netmask = 24        
      }

      ipv4_gateway = "192.168.9.1"

      dns_server_list = ["8.8.8.8","8.8.4.4"]
    
      linux_options {
        host_name = "leader01"
        domain    = "allthingscloud.eu"
      }
    }    

  }

  provisioner "remote-exec" {
    
    connection {
        type     = "ssh"
        user     = "vagrant"
        password = "vagrant"
        host = "${self.default_ip_address}"
    }

    inline = [
        "touch /tmp/cloudinit-start.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_SecretID_Factory.sh",
        "touch /tmp/cloudinit-finish.txt",
    ]
  }
}

resource "vsphere_virtual_machine" "redis01vm" {
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
    customize {
      network_interface {
        ipv4_address = "192.168.9.200"
        ipv4_netmask = 24        
      }

      ipv4_gateway = "192.168.9.1"

      dns_server_list = ["8.8.8.8","8.8.4.4"]
    
      linux_options {
        host_name = "redis01"
        domain    = "allthingscloud.eu"
      }
    }     

  }

  provisioner "remote-exec" {
    
    connection {
        type     = "ssh"
        user     = "vagrant"
        password = "vagrant"
        host = "${self.default_ip_address}"
    }

    inline = [
        "touch /tmp/cloudinit-start.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_redis.sh",
        "touch /tmp/cloudinit-finish.txt",
    ]    
  }  



  depends_on = ["vsphere_virtual_machine.leader01vm"]

} 

resource "vsphere_virtual_machine" "godevvms" {
  count = 5
  name             = "godev-${count.index + 1}"
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
    customize {
      network_interface {
        ipv4_address = "192.168.9.${count.index + 21}"
        ipv4_netmask = 24        
      }

      ipv4_gateway = "192.168.9.1"

      dns_server_list = ["8.8.8.8","8.8.4.4"]
    
      linux_options {
        host_name = "godev-${count.index + 1}"
        domain    = "allthingscloud.eu"
      }
    }    

  }

  provisioner "remote-exec" {
    
    connection {
        type     = "ssh"
        user     = "vagrant"
        password = "vagrant"
        host = "${self.default_ip_address}"
    }

    inline = [
        "touch /tmp/cloudinit-start.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_nomad.sh",
        "sudo /usr/local/bootstrap/scripts/install_go_app.sh",
        "touch /tmp/cloudinit-finish.txt",
    ]
  }   

  depends_on = ["vsphere_virtual_machine.leader01vm", "vsphere_virtual_machine.redis01vm"]

}

resource "vsphere_virtual_machine" "web01vm" {
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
    customize {
      network_interface {
        ipv4_address = "192.168.9.250"
        ipv4_netmask = 24        
      }

      ipv4_gateway = "192.168.9.1"

      dns_server_list = ["8.8.8.8","8.8.4.4"]
    
      linux_options {
        host_name = "web01"
        domain    = "allthingscloud.eu"
      }
    }    

  }

  provisioner "file" {
    source      = "/Users/grazzer/vagrant_workspace/pipeline/var.env"
    destination = "/usr/local/bootstrap/var.env"

    connection {
        type     = "ssh"
        user     = "vagrant"
        password = "vagrant"
        host = "${self.default_ip_address}"
    }
  }

  provisioner "remote-exec" {
    
    connection {
        type     = "ssh"
        user     = "vagrant"
        password = "vagrant"
        host = "${self.default_ip_address}"
    }

    inline = [
        "touch /tmp/cloudinit-start.txt",
        "sudo /usr/local/bootstrap/scripts/install_consul.sh",
        "sudo /usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh",
        "sudo /usr/local/bootstrap/scripts/install_vault.sh",
        "sudo /usr/local/bootstrap/scripts/install_webserver.sh",
        "touch /tmp/cloudinit-finish.txt",
    ]
  }   

  depends_on = ["vsphere_virtual_machine.godevvms"]  

} 
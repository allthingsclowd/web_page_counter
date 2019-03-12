# Application Workflow with Packer  - Overview

![image](https://user-images.githubusercontent.com/9472095/54201114-2c13f280-44cd-11e9-8dd2-32ca2a26fc80.png)

## Challenge

![image](https://user-images.githubusercontent.com/9472095/54204034-b65f5500-44d3-11e9-8500-06c74e1ccfbe.png)

## Solution

![image](https://user-images.githubusercontent.com/9472095/54204067-c840f800-44d3-11e9-9752-7943935214c8.png)

## Immutable Images with Packer

Okay, so technically it's possible to add even more binaries and configuration to the base image than what I've achieved here but this is a training exercise after all :)

[Packer](https://www.packer.io/intro/index.html) is an automation tool that was used to build a [Vagrant](https://www.vagrantup.com/) base image and uploaded to VagrantCloud. Packer can also be used to generate images for most other popular platforms - Amazon, Google Cloud, Azure, VMware, OpenStack etc..

The following configuration was used to build the base image

``` json
{
  "variables": {
    "name": "allthingscloud/go-counter-demo",
    "build_name": "go-counter-demo",
    "build_cpu_cores": "2",
    "build_memory": "1024",
    "cpu_cores": "1",
    "memory": "512",
    "disk_size": "49600",
    "headless": "true",
    "iso_checksum": "737ae7041212c628de5751d15c3016058b0e833fdc32e7420209b76ca3d0a535",
    "iso_checksum_type": "sha256",
    "iso_url": "http://releases.ubuntu.com/16.04.2/ubuntu-16.04.2-server-amd64.iso",
    "ssh_username": "vagrant",
    "ssh_password": "vagrant",
    "version": "0.1.{{timestamp}}",
    "cloud_token": "{{ env `VAGRANT_CLOUD_TOKEN` }}"
  },
  "builders": [
    {
      "name": "{{ user `build_name` }}-vbox",
      "vm_name": "{{ user `build_name` }}-vbox",
      "boot_command": [
        "<enter><f6><esc><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
        "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
        "debian-installer=en_US auto locale=en_US kbd-chooser/method=us ",
        "hostname={{ user `build_name` }}-vmware ",
        "fb=false debconf/fronten=d=noninteractive ",
        "keyboard-configuration/modelcode=SKIP keyboard-configuration/layout=USA keyboard-configuration/variant=USA console-setup/ask_detect=false ",
        "initrd=/install/initrd.gz -- <enter>"
      ],
      "boot_wait": "5s",
      "disk_size": "{{user `disk_size`}}",
      "guest_os_type": "Ubuntu_64",
      "headless": "{{user `headless`}}",
      "http_directory": "http",
      "iso_checksum": "{{user `iso_checksum`}}",
      "iso_checksum_type": "{{user `iso_checksum_type`}}",
      "iso_url": "{{user `iso_url`}}",
      "shutdown_command": "echo 'vagrant' | sudo -S poweroff",
      "ssh_password": "{{user `ssh_username`}}",
      "ssh_username": "{{user `ssh_password`}}",
      "ssh_wait_timeout": "20m",
      "type": "virtualbox-iso",
      "vboxmanage": [
        [
          "modifyvm",
          "{{.Name}}",
          "--memory",
          "{{user `build_memory`}}"
        ],
        [
          "modifyvm",
          "{{.Name}}",
          "--cpus",
          "{{user `build_cpu_cores`}}"
        ]
      ],
      "vboxmanage_post": [
        [
          "modifyvm",
          "{{.Name}}",
          "--memory",
          "{{user `memory`}}"
        ],
        [
          "modifyvm",
          "{{.Name}}",
          "--cpus",
          "{{user `cpu_cores`}}"
        ]
      ],
      "virtualbox_version_file": ".vbox_version"
    }
  ],
  "provisioners": [
    {
      "execute_command": "echo 'vagrant' | {{.Vars}} sudo -E -S bash '{{.Path}}'",
      "scripts": [
        "../scripts/packer_install_base_packages.sh",
        "../scripts/packer_configure_vagrant_user.sh",
        "../scripts/packer_remove_old_vbox.sh",
        "../scripts/packer_virtualbox_cleanup.sh"
      ],
      "type": "shell",
      "expect_disconnect": true
    }
  ],
  "post-processors": [
    [
      {
        "type": "vagrant",
        "keep_input_artifact": true,
        "output": "{{.BuildName}}.box"
      },
      {
        "type": "vagrant-cloud",
        "box_tag": "{{user `name`}}",
        "access_token": "{{user `cloud_token`}}",
        "version": "{{user `version`}}"
      }
    ]
  ]
}
```

A [Vagrant Cloud Account](https://app.vagrantup.com/account/new) is required if you wish to build new Vagrant images with Packer and upload them automatically. That's where the ```VAGRANT_CLOUD_TOKEN``` above comes into play.

[:back:](../../ReadMe.md)
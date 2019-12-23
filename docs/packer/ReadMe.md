# Application Workflow with Packer  - Overview

![image](https://user-images.githubusercontent.com/9472095/54201114-2c13f280-44cd-11e9-8dd2-32ca2a26fc80.png)

## Challenge

![image](https://user-images.githubusercontent.com/9472095/54204034-b65f5500-44d3-11e9-8500-06c74e1ccfbe.png)

## Solution

![image](https://user-images.githubusercontent.com/9472095/54204067-c840f800-44d3-11e9-9752-7943935214c8.png)

## Immutable Images with Packer

Okay, so technically it's possible to add even more binaries and configuration to the base image than what I've achieved here but this is a training exercise after all :)

[Packer](https://www.packer.io/intro/index.html) is an automation tool that was used to build a [Vagrant](https://www.vagrantup.com/) base image and uploaded to VagrantCloud. Packer can also be used to generate images for most other popular platforms - Amazon, Google Cloud, Azure, VMware, OpenStack etc..

``` bash
packer build -force -only=web-page-counter-vmware,web-page-counter-vbox template.json
```

The following configuration was used to build the base image

``` json
{
  "variables": {
    "name": "allthingscloud/web-page-counter",
    "build_name": "web-page-counter",
    "build_cpu_cores": "2",
    "build_memory": "1024",
    "cpu_cores": "1",
    "memory": "512",
    "disk_size": "49600",
    "headless": "true",
    "iso_checksum": "a2cb36dc010d98ad9253ea5ad5a07fd6b409e3412c48f1860536970b073c98f5",
    "iso_checksum_type": "sha256",
    "iso_url": "http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.2-server-amd64.iso",
    "guest_additions_url": "http://download.virtualbox.org/virtualbox/6.0.4/VBoxGuestAdditions_6.0.4.iso",
    "guest_additions_sha256": "749b0c76aa6b588e3310d718fc90ea472fdc0b7c8953f7419c20be7e7fa6584a",
    "ssh_username": "vagrant",
    "ssh_password": "vagrant",
    "version": "0.2.{{timestamp}}",
    "cloud_token": "{{ env `TF_VAR_vagrant_cloud_token` }}",
    "arm_subscription_id": "{{ env `TF_VAR_arm_subscription_id` }}",
    "arm_client_id": "{{ env `TF_VAR_arm_client_id` }}",
    "arm_client_secret": "{{ env `TF_VAR_arm_client_secret` }}",
    "arm_tenant_id": "{{ env `TF_VAR_arm_tenant_id` }}"
  },
  "builders": [
    {
      "type": "azure-arm",
      "client_id": "{{user `arm_client_id`}}",
      "client_secret": "{{user `arm_client_secret`}}",
      "tenant_id": "{{user `arm_tenant_id`}}",
      "subscription_id": "{{user `arm_subscription_id`}}",
  
      "managed_image_resource_group_name": "graham-dev",
      "managed_image_name": "webPageCounter",
  
      "os_type": "Linux",
      "image_publisher": "Canonical",
      "image_offer": "UbuntuServer",
      "image_sku": "18.04-LTS",
  
      "azure_tags": {
          "dept": "gjl",
          "task": "Image deployment"
      },
  
      "location": "West Europe",
      "vm_size": "Standard_DS1_v2"
    },
    {
      "type": "virtualbox-iso",
      "name": "{{ user `build_name` }}-vbox",
      "vm_name": "{{ user `build_name` }}-vbox",
      "boot_command": [
        "<esc><wait>",
        "<esc><wait>",
        "<enter><wait>",
        "/install/vmlinuz<wait>",
        " auto<wait>",
        " console-setup/ask_detect=false<wait>",
        " console-setup/layoutcode=us<wait>",
        " console-setup/modelcode=pc105<wait>",
        " debconf/frontend=noninteractive<wait>",
        " debian-installer=en_US<wait>",
        " fb=false<wait>",
        " initrd=/install/initrd.gz<wait>",
        " kbd-chooser/method=us<wait>",
        " keyboard-configuration/layout=USA<wait>",
        " keyboard-configuration/variant=USA<wait>",
        " locale=en_US<wait>",
        " netcfg/get_domain=vm<wait>",
        " netcfg/get_hostname=vagrant<wait>",
        " grub-installer/bootdev=/dev/sda<wait>",
        " noapic<wait>",
        " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<wait>",
        " -- <wait>",
        "<enter><wait>"
      ],
      "boot_wait": "10s",
      "disk_size": "{{user `disk_size`}}",
      "guest_os_type": "Ubuntu_64",
      "headless": "{{user `headless`}}",
      "http_directory": "http",
      "iso_checksum": "{{user `iso_checksum`}}",
      "iso_checksum_type": "{{user `iso_checksum_type`}}",
      "iso_url": "{{user `iso_url`}}",
      "guest_additions_url": "{{user `guest_additions_url`}}",
      "guest_additions_sha256": "{{user `guest_additions_sha256`}}",
      "shutdown_command": "echo 'vagrant' | sudo -S poweroff",
      "ssh_password": "{{user `ssh_username`}}",
      "ssh_username": "{{user `ssh_password`}}",
      "ssh_wait_timeout": "20m",
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
      "inline": [
        "sudo mkdir -p /usr/local/bootstrap && sudo chmod 777 /usr/local/bootstrap"
      ],
      "type": "shell",
      "only": ["azure-arm"]
    },
    {
      "destination": "/usr/local/bootstrap/",
      "source": "../var.env",
      "type": "file",
      "only": ["azure-arm"]
    },
    {
      "destination": "/usr/local/bootstrap/",
      "source": "../.appRoleID",
      "type": "file",
      "only": ["azure-arm"]
    },
    {
      "destination": "/usr/local/bootstrap",
      "source": "../certificate-config",
      "type": "file",
      "only": ["azure-arm"]
    },
    {
      "destination": "/usr/local/bootstrap",
      "source": "../conf",
      "type": "file",
      "only": ["azure-arm"]
    },
    {
      "destination": "/usr/local/bootstrap",
      "source": "../scripts",
      "type": "file",
      "only": ["azure-arm"]
    },
    {
      "execute_command": "chmod +x {{ .Path }}; {{ .Vars }} sudo -E -S bash '{{ .Path }}'",
      "script": "../scripts/packer_install_base_packages.sh",
      "type": "shell",
      "expect_disconnect": true,
      "only": ["azure-arm"]
    },
    {
      "execute_command": "chmod +x {{ .Path }}; {{ .Vars }} sudo -E -S bash '{{ .Path }}'",
      "script": "../scripts/packer_cleanup_azurevm.sh",
      "type": "shell",
      "expect_disconnect": true,
      "pause_before": "60s",
      "only": ["azure-arm"]
    },
    {
      "execute_command": "echo 'vagrant' | {{.Vars}} sudo -E -S bash '{{.Path}}'",
      "scripts": [
        "../scripts/packer_install_base_packages.sh",
        "../scripts/packer_configure_vagrant_user.sh",
        "../scripts/packer_install_guest_additions.sh",
        "../scripts/packer_virtualbox_cleanup.sh"
      ],
      "type": "shell",
      "expect_disconnect": true,
      "pause_before": "10s",
      "only": ["{{ user `build_name` }}-vbox"]
    },
    {
      "type": "inspec",
      "profile": "../test/ImageBuild"
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

The same is true for each of the cloud accounts should you wish to automatically build images for those platforms and upload then to the respective platforms.

## Chef's Inspec Test Framework

[Inspec tests](https://www.inspec.io/) have now also been added to the image build process. Some basic tests are included to ensure that the correct binaries are delivered to the immutable image before it is created and released for use.

``` ruby
# encoding: utf-8
# copyright: 2019, Graham Land

title 'Verify WebPageCounter Binaries'

# control => test
control 'audit_installation_prerequisites' do
  impact 1.0
  title 'os and packages'
  desc 'verify os type and base os packages'

  describe os.family do
    it {should eq 'debian'}
  end

  describe package('wget') do
    it {should be_installed}
  end

  describe package('unzip') do
    it {should be_installed}
  end

  describe package('git') do
    it {should be_installed}
  end

  describe package('redis-server') do
    it {should be_installed}
  end

  describe package('nginx') do
    it {should be_installed}
  end

  describe package('lynx') do
    it {should be_installed}
  end

  describe package('jq') do
    it {should be_installed}
  end

  describe package('curl') do
    it {should be_installed}
  end

  describe package('net-tools') do
    it {should be_installed}
  end

end

control 'consul-binary-exists-1.0' do         
  impact 1.0                      
  title 'consul binary exists'
  desc 'verify that the consul binary is installed'
  describe file('/usr/local/bin/consul') do 
    it { should exist }
  end
end

control 'consul-binary-version-1.0' do                      
  impact 1.0                                
  title 'consul binary version check'
  desc 'verify that the consul binary is the correct version'
  describe command('consul version') do
   its('stdout') { should match /Consul v1.4.4/ }
  end
end

control 'consul-template-binary-exists-1.0' do         
  impact 1.0                      
  title 'consul-template binary exists'
  desc 'verify that the consul-template binary is installed'
  describe file('/usr/local/bin/consul-template') do 
    it { should exist }
  end
end

control 'consul-template-binary-version-1.0' do                      
  impact 1.0                                
  title 'consul-template binary version check'
  desc 'verify that the consul-template binary is the correct version'
  describe command('consul-template -version') do
   its('stderr') { should match /v0.20.0/ }
  end
end

control 'envconsul-binary-exists-1.0' do         
  impact 1.0                      
  title 'envconsul binary exists'
  desc 'verify that the envconsul binary is installed'
  describe file('/usr/local/bin/envconsul') do 
    it { should exist }
  end
end

control 'envconsul-binary-version-1.0' do                      
  impact 1.0                                
  title 'envconsul binary version check'
  desc 'verify that the envconsul binary is the correct version'
  describe command('envconsul -version') do
   its('stderr') { should match /v0.7.3/ }
  end
end

control 'vault-binary-exists-1.0' do         
  impact 1.0                      
  title 'vault binary exists'
  desc 'verify that the vault binary is installed'
  describe file('/usr/local/bin/vault') do 
    it { should exist }
  end
end

control 'vault-binary-version-1.0' do                      
  impact 1.0                                
  title 'vault binary version check'
  desc 'verify that the vault binary is the correct version'
  describe command('vault version') do
   its('stdout') { should match /v1.1.0/ }
  end
end

control 'nomad-binary-exists-1.0' do         
  impact 1.0                      
  title 'nomad binary exists'
  desc 'verify that the nomad binary is installed'
  describe file('/usr/local/bin/nomad') do 
    it { should exist }
  end
end

control 'nomad-binary-version-1.0' do                      
  impact 1.0                                
  title 'nomad binary version check'
  desc 'verify that the nomad binary is the correct version'
  describe command('nomad version') do
   its('stdout') { should match /v0.9.0/ }
  end
end

control 'terraform-binary-exists-1.0' do         
  impact 1.0                      
  title 'terraform binary exists'
  desc 'verify that the terraform binary is installed'
  describe file('/usr/local/bin/terraform') do 
    it { should exist }
  end
end

control 'terraform-binary-version-1.0' do                      
  impact 1.0                                
  title 'terraform binary version check'
  desc 'verify that the terraform binary is the correct version'
  describe command('terraform version') do
   its('stdout') { should match /v0.12.0/ }
  end
end

```

See the `test/ImageBuild` for the complete Inspec test profile

[:back:](../../ReadMe.md)
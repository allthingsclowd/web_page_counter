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

## Securing Access to the Image using SSH Certificates

| Certificate Authority (CA) Server | Host Server(s) | Client(s) |
|---|---|---|
| This is the server typically managed by a security team. The root CA private keys are held on this server and should be protected. If these keys are compromised it will be necessary to Revoke & Rotate/Recreate ALL Certificates!!  | These are the servers that are being built or reprovisioned. The Host CA Signed Certificate is used to prove Host Authenticity to clients. It is sent to the ssh client during the initial handshake when a ssh client attempts to login. | The user laptop or server that's runing the ssh client. The Client CA Signed Certificate is used to prove Client Authenticity to the Host Server |
|**Step 1.** Creat HOST CA signing keys : Example `ssh-keygen -t rsa -N '' -C HOST-CA -b 4096 -f host-ca` | **Step 2.** Let's generate a fresh set of ssh RSA HOST keys with 4096 bits. Typically the keys are generated by default when openssh-server is installed but it uses 2048 bits. You need to do this when cloning VMs too if you need unique authenticity : Example `sudo ssh-keygen -N '' -C HOST-KEY -t rsa -b 4096 -h -f /etc/ssh/ssh_host_rsa_key` |  |
|**Step 3.** Copy the PUBLIC key, user@target-host:`/etc/ssh/ssh_host_rsa_key.pub`, created in `Step 2.` on the host server to the CA server: Example `scp root@192.168.9.200:/etc/ssh/ssh_host_rsa_key.pub .`|||
|**Step 4.** Create the CA signed Host Certificate for the target host using the CA-HOST private key, `host-ca`, created in `Step 1.`, and the host server's public key, `ssh_host_rsa_key.pub`, retrieved in `Step 3` : Example `ssh-keygen -s ../host-ca -I dev_host_server -h -V -5m:+52w ssh_host_rsa_key.pub` |||
|**Step 5.** Copy the HOST Certificate, `ssh_host_rsa_key-cert.pub`, created in `Step 4.`, back onto the host server : Example `scp ssh_host_rsa_key-cert.pub root@192.168.9.200:/etc/ssh/ssh_host_rsa_key-cert.pub` |||
|**Step 6.** Remove the now obsolete host public key and host cert from the CA server: Example `rm ssh_host_rsa_key-cert.pub ssh_host_rsa_key.pub`|||
||**Step 7.** Configure the Host Server to use the new certificate file,`/etc/ssh/ssh_host_rsa_key-cert.pub`, within ssh server conf, `/etc/ssh/sshd_config`, by adding the following line `HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub`. Then restart the ssh service. Example `grep -qxF 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' /etc/ssh/sshd_config || echo 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' | sudo tee -a /etc/ssh/sshd_config` followed by `sudo systemctl restart ssh`||
|**Step 8.** Capture the contents of the CA-HOST PUBLIC key, `host-ca.pub`, as this will be needed to configure the ssh clients. Example `cat host-ca.pub`||**Step 9.** Now we need to configure the ssh clients to be able to validate the Host Certificates using the CA-HOST PUBLIC key, `host-ca.pub` , created in `Step 1.` by adding it to the individual user's `~/.ssh/known_hosts` : Example `grep -qxF '@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA' ~/.ssh/known_hosts || echo '@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA' | tee -a ~/.ssh/known_hosts`|
||||
||||
||||
||||

## Step 1

``` bsh

graham@graz-baz:~/.WiP $ ssh-keygen -t rsa -N '' -C HOST-CA -b 4096 -f host-ca
Generating public/private rsa key pair.
Your identification has been saved in host-ca.
Your public key has been saved in host-ca.pub.
The key fingerprint is:
SHA256:uKJqQBCvoukiJ6n0GRX6Me8/VmHUB6bps81ekpUjdJ8 HOST-CA
The keys randomart image is:
+---[RSA 4096]----+
|..          .o.  |
|..         .+. . |
|. .  .    .o ... |
| o  . ..  .o. . +|
|+  . +. S .o.. E.|
|+.  o +.   .= + .|
|+o .....  .. = . |
|B.o.o..  o  . o  |
|B=.o   .o..  .   |
+----[SHA256]-----+
graham@graz-baz:~/.WiP $ ls -al
total 16
drwx------  2 graham graham 4096 Jan  3 12:35 .
drwxr-xr-x 19 graham graham 4096 Jan  3 12:14 ..
-rw-------  1 graham graham 3247 Jan  3 12:35 host-ca
-rw-r--r--  1 graham graham  733 Jan  3 12:35 host-ca.pub
graham@graz-baz:~/.WiP $
```

Notes:

- omit `-N` if you want to include a passphrase with the key generation
- `-t` type can be `dsa`, `rsa`, `ecdsa` or `ed25519`. I choose rsa as it's widely accepted everywhere though less secure.
- `-b` key size of 4096 bits to delay brute force attacks - all bets are off when we have qbit mobile phones ;)

## Step 2

``` bsh
root@redis01:# sudo ssh-keygen -N '' -C HOST-KEY -t rsa -b 4096 -h -f /etc/ssh/ssh_host_rsa_key
Generating public/private rsa key pair.
/etc/ssh/ssh_host_rsa_key already exists.
Overwrite (y/n)? y
Your identification has been saved in /etc/ssh/ssh_host_rsa_key.
Your public key has been saved in /etc/ssh/ssh_host_rsa_key.pub.
The key fingerprint is:
SHA256:3lpUNJcP8GDhkHmozrhP4XA99s16AaV0kLI1fysjpEc HOST-KEY
The keys randomart image is:
+---[RSA 4096]----+
|          .+O=.. |
|          ==*==  |
|         . *o*.o |
|        ...Eo . o|
|      .+S O  . ..|
|      .=o* = =.. |
|       .+ + o =. |
|      .. o   ..  |
|       .o   ..   |
+----[SHA256]-----+
root@redis01:~# ls -al /etc/ssh/
total 596
drwxr-xr-x  2 root root   4096 Jan  2 22:51 .
drwxr-xr-x 89 root root   4096 Jan  2 23:57 ..
-rw-r--r--  1 root root    384 Jan  2 22:51 hashistack-ca.pub
-rw-r--r--  1 root root 553122 Mar  4  2019 moduli
-rw-r--r--  1 root root   1580 Mar  4  2019 ssh_config
-rw-r--r--  1 root root   3362 Jan  2 22:51 sshd_config
-rw-------  1 root root    227 Jan  2 22:45 ssh_host_ecdsa_key
-rw-r--r--  1 root root   1083 Jan  2 22:51 ssh_host_ecdsa_key-cert.pub
-rw-r--r--  1 root root    174 Jan  2 22:45 ssh_host_ecdsa_key.pub
-rw-------  1 root root    399 Jan  2 22:45 ssh_host_ed25519_key
-rw-r--r--  1 root root     94 Jan  2 22:45 ssh_host_ed25519_key.pub
-rw-------  1 root root   3243 Jan  3 13:38 ssh_host_rsa_key
-rw-r--r--  1 root root    734 Jan  3 13:38 ssh_host_rsa_key.pub
-rw-r--r--  1 root root    338 Jan  2 22:45 ssh_import_id
root@redis01:~# date
Fri Jan  3 13:38:52 UTC 2020
root@redis01:~#
```

Notes:

- For my dev environment I use the same host keys and certificates on all host servers (cloned from the same template). Possibly not a good idea for production but better than what I've got today.
- HashiCorp's Vault provides a neat API based PKI CA signing solution when you need to scale and maintain certificate management and auditability. This will be implemented next...

## Step 3

``` bsh

graham@graz-baz:~/.WiP $ mkdir tmp-keys
graham@graz-baz:~/.WiP $ cd tmp-keys/
graham@graz-baz:~/.WiP/tmp-keys $ scp root@192.168.9.200:/etc/ssh/ssh_host_rsa_key.pub .
ssh_host_rsa_key.pub                          100%  734   416.9KB/s   00:00
graham@graz-baz:~/.WiP/tmp-keys $ ls -al
total 12
drwxr-xr-x 2 graham graham 4096 Jan  3 13:44 .
drwx------ 3 graham graham 4096 Jan  3 13:42 ..
-rw-r--r-- 1 graham graham  734 Jan  3 13:44 ssh_host_rsa_key.pub
graham@graz-baz:~/.WiP/tmp-keys $
```

## Step 4

``` bsh

graham@graz-baz:~/.WiP/tmp-keys $ ssh-keygen -s ../host-ca -I dev_host_server -h -V -5m:+52w ssh_host_rsa_key.pub
Signed host key ssh_host_rsa_key-cert.pub: id "dev_host_server" serial 0 valid from 2020-01-03T16:51:35 to 2021-01-01T16:56:35
...
graham@graz-baz:~/.WiP/tmp-keys $ date
Fri  3 Jan 14:15:47 GMT 2020
graham@graz-baz:~/.WiP/tmp-keys $ ls -al
total 16
drwxr-xr-x 2 graham graham 4096 Jan  3 14:15 .
drwx------ 3 graham graham 4096 Jan  3 13:42 ..
-rw-r--r-- 1 graham graham 2359 Jan  3 14:15 ssh_host_rsa_key-cert.pub
-rw-r--r-- 1 graham graham  734 Jan  3 13:44 ssh_host_rsa_key.pub
graham@graz-baz:~/.WiP/tmp-keys $
```

## Step 5

CA Server

``` bsh

graham@graz-baz:~/.WiP/tmp-keys $ scp ssh_host_rsa_key-cert.pub root@192.168.9.200:/etc/ssh/ssh_host_rsa_key-cert.pub
ssh_host_rsa_key-cert.pub                                                                                        100% 2359   973.0KB/s   00:00
graham@graz-baz:~/.WiP/tmp-keys $
```

Host Server

``` bsh
root@redis01:~# ls -al /etc/ssh/
total 600
drwxr-xr-x  2 root root   4096 Jan  3 14:38 .
drwxr-xr-x 89 root root   4096 Jan  2 23:57 ..
-rw-r--r--  1 root root    384 Jan  2 22:51 hashistack-ca.pub
-rw-r--r--  1 root root 553122 Mar  4  2019 moduli
-rw-r--r--  1 root root   1580 Mar  4  2019 ssh_config
-rw-r--r--  1 root root   3362 Jan  2 22:51 sshd_config
-rw-------  1 root root    227 Jan  2 22:45 ssh_host_ecdsa_key
-rw-r--r--  1 root root   1083 Jan  2 22:51 ssh_host_ecdsa_key-cert.pub
-rw-r--r--  1 root root    174 Jan  2 22:45 ssh_host_ecdsa_key.pub
-rw-------  1 root root    399 Jan  2 22:45 ssh_host_ed25519_key
-rw-r--r--  1 root root     94 Jan  2 22:45 ssh_host_ed25519_key.pub
-rw-------  1 root root   3243 Jan  3 13:38 ssh_host_rsa_key
-rw-r--r--  1 root root   2359 Jan  3 14:38 ssh_host_rsa_key-cert.pub
-rw-r--r--  1 root root    734 Jan  3 13:38 ssh_host_rsa_key.pub
-rw-r--r--  1 root root    338 Jan  2 22:45 ssh_import_id
root@redis01:~#
```

## Step 6

``` bsh

graham@graz-baz:~/.WiP/tmp-keys $ ls -al
total 16
drwxr-xr-x 2 graham graham 4096 Jan  3 14:15 .
drwx------ 3 graham graham 4096 Jan  3 13:42 ..
-rw-r--r-- 1 graham graham 2359 Jan  3 14:15 ssh_host_rsa_key-cert.pub
-rw-r--r-- 1 graham graham  734 Jan  3 13:44 ssh_host_rsa_key.pub
graham@graz-baz:~/.WiP/tmp-keys $ rm ssh_host_rsa_key.pub ssh_host_rsa_key-cert.pub
graham@graz-baz:~/.WiP/tmp-keys $ ls -al
total 8
drwxr-xr-x 2 graham graham 4096 Jan  3 15:41 .
drwx------ 3 graham graham 4096 Jan  3 13:42 ..
graham@graz-baz:~/.WiP/tmp-keys $
```

## Step 7

``` bsh

root@redis01:~# grep -qxF 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' /etc/ssh/sshd_config || echo 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub' | sudo tee -a /etc/ssh/sshd_config
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
root@redis01:~# grep HostCertificate /etc/ssh/sshd_config
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
root@redis01:~# sudo systemctl restart ssh
root@redis01:~# sudo systemctl status ssh
● ssh.service - OpenBSD Secure Shell server
   Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2020-01-03 15:33:29 UTC; 6s ago
  Process: 31111 ExecStartPre=/usr/sbin/sshd -t (code=exited, status=0/SUCCESS)
 Main PID: 31112 (sshd)
    Tasks: 1 (limit: 1112)
   CGroup: /system.slice/ssh.service
           └─31112 /usr/sbin/sshd -D

Jan 03 15:33:29 redis01 systemd[1]: Stopping OpenBSD Secure Shell server...
Jan 03 15:33:29 redis01 systemd[1]: Stopped OpenBSD Secure Shell server.
Jan 03 15:33:29 redis01 systemd[1]: Starting OpenBSD Secure Shell server...
Jan 03 15:33:29 redis01 sshd[31112]: Server listening on 0.0.0.0 port 22.
Jan 03 15:33:29 redis01 sshd[31112]: Server listening on :: port 22.
Jan 03 15:33:29 redis01 systemd[1]: Started OpenBSD Secure Shell server.
root@redis01:~#
```

## Step 8

``` bsh
graham@graz-baz:~/.WiP $ ls
host-ca  host-ca.pub  tmp-keys
graham@graz-baz:~/.WiP $ cat host-ca.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA
```

## Step 9

**Before the host-ca public key is added:**

```bsh
graham@graz-baz:~/web_page_counter/terraform/VMware/Dev/Monolith $ ssh -v root@192.168.9.200
OpenSSH_7.4p1 Raspbian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 19: Applying options for *
debug1: Connecting to 192.168.9.200 [192.168.9.200] port 22.
debug1: Connection established.
debug1: identity file /home/graham/.ssh/id_rsa type 1
debug1: identity file /home/graham/.ssh/id_rsa-cert type 5
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_dsa type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_dsa-cert type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ecdsa type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ecdsa-cert type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ed25519 type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ed25519-cert type -1
debug1: Enabling compatibility mode for protocol 2.0
debug1: Local version string SSH-2.0-OpenSSH_7.4p1 Raspbian-10+deb9u7
debug1: Remote protocol version 2.0, remote software version OpenSSH_7.6p1 Ubuntu-4ubuntu0.3
debug1: match: OpenSSH_7.6p1 Ubuntu-4ubuntu0.3 pat OpenSSH* compat 0x04000000
debug1: Authenticating to 192.168.9.200:22 as 'root'
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: curve25519-sha256
debug1: kex: host key algorithm: ssh-rsa-cert-v01@openssh.com
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug1: Server host certificate: ssh-rsa-cert-v01@openssh.com SHA256:3lpUNJcP8GDhkHmozrhP4XA99s16AaV0kLI1fysjpEc, serial 0 ID "dev_host_server" CA ssh-rsa SHA256:uKJqQBCvoukiJ6n0GRX6Me8/VmHUB6bps81ekpUjdJ8 valid from 2020-01-03T14:10:32 to 2021-01-01T14:15:32
debug1: No matching CA found. Retry with plain key
The authenticity of host '192.168.9.200 (192.168.9.200)' cant be established.
RSA key fingerprint is SHA256:3lpUNJcP8GDhkHmozrhP4XA99s16AaV0kLI1fysjpEc.
Are you sure you want to continue connecting (yes/no)? 
```

**Adding the host-ca public key :**

``` bsh

graham@graz-baz:~/web_page_counter/terraform/VMware/Dev/Monolith $ grep -qxF 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA' ~/.ssh/known_hosts || echo '@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA' | tee -a ~/.ssh/known_hosts
@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA
graham@graz-baz:~/web_page_counter/terraform/VMware/Dev/Monolith $ cat ~/.ssh/known_hosts
@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA
@cert-authority * ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFmZo/bkvhmUEjx3erXC+rZ1R3htLHtz0VzZNpgQD2sT2KZLW3yBiKYIKgxICM04MQsVHY1k5y4ek/tgnw05m5KOO5KTHxxKjcBKf2EyvwG0o8vnzo6UgweqXEePigAzSGQfcsGp75tVu3qmeLKXtJOo1WaWmTSNH4Qoq89xRiPslCVDi1i2VEPxJi3+eeFL5WO+nBK9Xt28DaXY4B43sgC1KC6DSRUR2JhlgPGMKP2eTE5+UaEldyPVzdIl2j3tLsaURfr+cZ6ryPEE9phT1bjcOSC3A88NrROZH1FvpZpG6NQPXusTWjre/NIz2TdG44AopbFRKAEpMVFw67AJ6oDWHPTrh2TGh3SQEIIZTdhudZIHnwiSBuKUOqyV65KH/mmy5gr8X2miHbM+qh6ISjqwPN6TjAhUPgkjxtwa7K+tDseBoFsrRIgP65hHAIlEFodHUI8Lu3P5HswH39z8ouEDR+qU54z9JO/E0Mw9YQPk19A6jr7o9/06wqSXfkVmS1VwvyZI90Zqrtg4+lZ3Zq/GLDqpxTlakfEAddOd9Ns01GgeSab4mKDwB6r2VTsunXQ4DDJkzxm9ioJmX7Ctv9J50Hqqcv+kiM8jJHrsB4IIrc0Cc/qb08YAo//i44JTuPxs2+FS2ifDmQA+TK5fJxwUIQJ6KDQ+0wB+T6yeYMJw== HOST-CA
graham@graz-baz:~/web_page_counter/terraform/VMware/Dev/Monolith $
```

**And the big test...**

``` bsh
graham@graz-baz:~/web_page_counter/terraform/VMware/Dev/Monolith $ ssh -v root@192.168.9.200
OpenSSH_7.4p1 Raspbian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 19: Applying options for *
debug1: Connecting to 192.168.9.200 [192.168.9.200] port 22.
debug1: Connection established.
debug1: identity file /home/graham/.ssh/id_rsa type 1
debug1: identity file /home/graham/.ssh/id_rsa-cert type 5
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_dsa type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_dsa-cert type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ecdsa type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ecdsa-cert type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ed25519 type -1
debug1: key_load_public: No such file or directory
debug1: identity file /home/graham/.ssh/id_ed25519-cert type -1
debug1: Enabling compatibility mode for protocol 2.0
debug1: Local version string SSH-2.0-OpenSSH_7.4p1 Raspbian-10+deb9u7
debug1: Remote protocol version 2.0, remote software version OpenSSH_7.6p1 Ubuntu-4ubuntu0.3
debug1: match: OpenSSH_7.6p1 Ubuntu-4ubuntu0.3 pat OpenSSH* compat 0x04000000
debug1: Authenticating to 192.168.9.200:22 as 'root'
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: curve25519-sha256
debug1: kex: host key algorithm: ssh-rsa-cert-v01@openssh.com
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug1: Server host certificate: ssh-rsa-cert-v01@openssh.com SHA256:3lpUNJcP8GDhkHmozrhP4XA99s16AaV0kLI1fysjpEc, serial 0 ID "dev_host_server" CA ssh-rsa SHA256:uKJqQBCvoukiJ6n0GRX6Me8/VmHUB6bps81ekpUjdJ8 valid from 2020-01-03T16:51:35 to 2021-01-01T16:56:35
debug1: Host '192.168.9.200' is known and matches the RSA-CERT host certificate.
debug1: Found CA key in /home/graham/.ssh/known_hosts:1
debug1: rekey after 134217728 blocks
```






Clearly, using a username/password (in this case vagrant/vagrant) is never a good idea post the initial build configuration.

I'd recommend leveraging SSH access following Facebook's [guidance](https://engineering.fb.com/security/scalable-and-secure-access-with-ssh/) 

- Create the new CA

``` bash
umask 77  # you really want to protect this :-)
mkdir ~/my-ca && cd ~/my-ca

ssh-keygen -C CA -f ca
```

- Configure SSH server to trust it by changing the line in `/etc/ssh/sshd_config`:

``` bash
grep -qxF 'TrustedUserCAKeys /etc/ssh/ca.pub' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/ca.pub' | sudo tee -a /etc/ssh/sshd_config

sudo systemctl restart ssh
```

e.g. `grep -qxF 'TrustedUserCAKeys /etc/ssh/hashistack-ca.pub' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/hashistack-ca.pub' | sudo tee -a /etc/ssh/sshd_config`

- And of course, copy the public ca key over to the target servers

- Generate a key to access the servers (not performed on CA server IRL)

 ``` bash
ssh-keygen -t ecdsa -f ~/.ssh/my-test-keys
 ```
e.g. `ssh-keygen -s ~/hashistack-ca/hashistack-ca -I user_graham -n root -V +52W ~/.ssh/id_rsa.pub`
- In your `.ssh/` directory, you'll see `my-test-keys` and `my-test-keys.pub`. Copy `my-test-keys.pub` to the CA server and get it signed.

- On the CA server

```bash
ssh-keygen -s ca -I grazzer -n root -V -5m:+30d -z 1 my-test-keys.pub
```

e.g. `ssh-keygen -s ~/hashistack-ca/hashistack-ca -I grazzer -n root -V -5m:+30d -z 1 ~/.ssh/my-test-keys.pub`

- You should have `my-test-keys-cert.pub` now. Copy this back to the user terminal and place it under `.ssh/`.

- Test the login as follows:

``` bash
ssh root@any-system-that-trusts-my-ca
```

e.g. `ssh -i ~/.ssh/my-test-keys -i ~/.ssh/my-test-keys-cert.pub root@192.168.2.105`

### Note: 
As I've deviated from ssh default key and certificate names I need to explicitly inform ssh of where to locate the keys and certificates used with the `-i` flag above

The certificate generated above is Valid `-V` from 5 minutes ago for the next 30 days `-5m:+30d`. Ideally keep this as short as possible - for my dev/play environment security is not a real concern - 30 days is fine. 

[:back:](../../ReadMe.md)
# Application Workflow with Vagrant - Overview

![image](https://user-images.githubusercontent.com/9472095/54201027-fec74480-44cc-11e9-8bc1-14bdbcffe15f.png)

## The Challenge

![image](https://user-images.githubusercontent.com/9472095/54201895-17d0f500-44cf-11e9-995e-a1479d30fc5d.png)

## The Solution

![image](https://user-images.githubusercontent.com/9472095/54201941-359e5a00-44cf-11e9-889c-a90eca246c33.png)

## Prerequisites - mandatory

Ensure that [Vagrant](https://www.vagrantup.com/intro/getting-started/install.html) and [Virtualbox](https://www.virtualbox.org/wiki/Downloads) are both installed on the host system.

## Installation

Simply clone this repository, update and source the environment variables file (var.env) and then build the vagrant environment as follows:

<!-- [Optional - export your datadog key]

``` bash
export DD_API_KEY=2504524abcd123eddda65431d5
``` -->

``` bash
git clone git@github.com:allthingsclowd/web_page_counter.git
cd web_page_counter
```

Locate your laptop/host primary ip address and configure the `NGINX_PUBLIC_IP` in the _var.env_ to contain this ip address. The example below is from a MacOS

``` bash
Grahams-MacBook-Pro:pipeline grazzer$ ifconfig
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	options=1203<RXCSUM,TXCSUM,TXSTATUS,SW_TIMESTAMP>
	inet 127.0.0.1 netmask 0xff000000
	inet6 ::1 prefixlen 128
	inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
	nd6 options=201<PERFORMNUD,DAD>
gif0: flags=8010<POINTOPOINT,MULTICAST> mtu 1280
stf0: flags=0<> mtu 1280
XHC1: flags=0<> mtu 0
XHC0: flags=0<> mtu 0
XHC20: flags=0<> mtu 0
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	ether 8c:85:90:a4:ab:cb
	inet6 fe80::18a8:b98b:a36a:a057%en0 prefixlen 64 secured scopeid 0x8
	inet 192.168.83.53 netmask 0xfffff000 broadcast 192.168.95.255
	nd6 options=201<PERFORMNUD,DAD>
	media: autoselect
	status: active
.
.
.
```
`en0` above contains `192.168.83.53` - this value needs to be updated in the _var.env_ file.

``` bash
Grahams-MacBook-Pro:pipeline grazzer$ cat var.env
export REDIS_MASTER_IP=192.168.2.200
export REDIS_MASTER_NAME=masterredis01.vagrant.local
export REDIS_HOST_PORT=6379
export GO_REPOSITORY=github.com/allthingsclowd/web_page_counter
export GO_GUEST_PORT=8080
export GO_HOST_PORT=8080
export NGINX_NAME=nginx01.vagrant.local
export NGINX_IP=192.168.2.250
export NGINX_GUEST_PORT=9090
export NGINX_HOST_PORT=9090
export VAULT_NAME=vault01.vagrant.local
export VAULT_IP=192.168.2.10
export LEADER_NAME=leader01.vagrant.local
export LEADER_IP=192.168.2.11
export NGINX_PUBLIC_IP=192.168.83.53
```

Now source this file and deploy the environment

``` bash
source var.env
vagrant up
```

This takes about 8 minutes to complete on a MacBook Pro.

## Infrastructure as Code (IaC) with Vagrant

[Vagrant](https://www.vagrantup.com/), infrastructure as code for your workstation, has been used to define and build the application infrastructure used for this demonstration. The use of infrastructure as code, a.k.a. the _Vagrantfile_ in this repo, is what enables me to be able to consistently share this application and it's entire development environment consistently with you. IaC is a fundamental building block that facilitates our journey to the cloud.

``` hcl
info = <<-'EOF'

      Welcome to The TAM HashiStack demo
        
                on Vagrant

      Open a browser on the following URLs to access each service

      WebPageCounter Application FrontEnd (public)  -   http://${NGINX_PUBLIC_IP}:9091
      WebPageCounter Application BackEnd (public)   -   http://${NGINX_PUBLIC_IP}:9090
      WebPageCounter Application FrontEnd -   http://${LEADER_IP}:9091
      WebPageCounter Application BackEnd  -   http://${LEADER_IP}:9090      
      Nomad Portal  (public)  -   http://${NGINX_PUBLIC_IP}:4646
      Vault Portal  (public)  -   http://${NGINX_PUBLIC_IP}:8200
      Consul Portal (public)  -   https://${NGINX_PUBLIC_IP}:8321
      Nomad Portal    -   http://${LEADER_IP}:4646
      Vault Portal    -   http://${LEADER_IP}:8200
      Consul Portal   -   https://${LEADER_IP}:8321      
      (self-signed certificates located in ../certificate-config directory)

      Vault Password  -   reallystrongpassword
      Consul ACL      -   Navigate to Vault to locate the consul ACL token then use it to login to the Consul portal


WARNING: PLEASE DON'T USE THESE CERTIFICATES IN ANYTHING OTHER THAN THIS TEST LAB!!!!
The keys are clearly publically available for demonstration purposes.

EOF

Vagrant.configure("2") do |config|

    #override global variables to fit Vagrant setup
    ENV['REDIS_MASTER_NAME']||="masterredis01"
    ENV['REDIS_MASTER_IP']||="192.168.2.200"
    ENV['GO_GUEST_PORT']||="808"
    ENV['GO_HOST_PORT']||="808"
    ENV['NGINX_NAME']||="web01"
    ENV['NGINX_IP']||="192.168.2.250"
    ENV['NGINX_PUBLIC_IP']||="UPDATE TO MATCH YOUR HOST IP"
    ENV['NGINX_GUEST_PORT']||="9090"
    ENV['NGINX_HOST_PORT']||="9090"
    ENV['VAULT_NAME']||="vault01"
    ENV['VAULT_IP']||="192.168.2.10"
    ENV['LEADER_NAME']||="leader01"
    ENV['LEADER_IP']||="192.168.2.11"
    ENV['SERVER_COUNT']||="2"
    ENV['DD_API_KEY']||="ONLY REQUIRED FOR DATADOG IMPLEMENTATION"
    
    #global config
    config.vm.synced_folder ".", "/vagrant"
    config.vm.synced_folder ".", "/usr/local/bootstrap"
    config.vm.box = "allthingscloud/web-page-counter"
    config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_consul.sh", run: "always"
    config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh", run: "always"
    config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_vault.sh", run: "always"
    # config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_dd_agent.sh", env: {"DD_API_KEY" => ENV['DD_API_KEY']}

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
    end

    config.vm.define "leader01" do |leader01|
        leader01.vm.hostname = ENV['LEADER_NAME']
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_nomad.sh", run: "always"
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_SecretID_Factory.sh", run: "always"
        leader01.vm.network "private_network", ip: ENV['LEADER_IP']
        leader01.vm.network "forwarded_port", guest: 4646, host: 4646
        leader01.vm.network "forwarded_port", guest: 8321, host: 8321
        leader01.vm.network "forwarded_port", guest: 8200, host: 8200
        leader01.vm.network "forwarded_port", guest: 8314, host: 8314
    end

    config.vm.define "redis01" do |redis01|
        redis01.vm.hostname = ENV['REDIS_MASTER_NAME']
        redis01.vm.network "private_network", ip: ENV['REDIS_MASTER_IP']
        redis01.vm.provision :shell, inline: "/usr/local/bootstrap/scripts/install_redis.sh"
    end
    
    (1..2).each do |i|
        config.vm.define "godev0#{i}" do |devsvr|
            devsvr.vm.hostname = "godev0#{i}"
            devsvr.vm.network "private_network", ip: "192.168.2.#{100+i*10}"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_nomad.sh", run: "always"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_go_app.sh"
        end
    end

    config.vm.define "web01" do |web01|
        web01.vm.hostname = ENV['NGINX_NAME']
        web01.vm.network "private_network", ip: ENV['NGINX_IP']
        web01.vm.network "forwarded_port", guest: ENV['NGINX_GUEST_PORT'], host: ENV['NGINX_HOST_PORT']
        web01.vm.provision :shell, inline: "/usr/local/bootstrap/scripts/install_webserver.sh"
        web01.vm.network "forwarded_port", guest: 9091, host: 9091
        web01.vm.network "forwarded_port", guest: 9090, host: 9090
   end

   puts info if ARGV[0] == "status"

end
```

[:back:](../../ReadMe.md)
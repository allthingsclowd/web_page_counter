![https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master](https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master)

# Web Page Counter

## When all is good it should look like this - 

![image](https://user-images.githubusercontent.com/9472095/46105006-cbb62080-c1cc-11e8-8f54-6eab4023a5bb.png)

## When we envoke a failure the self healing kicks in -
![image](https://user-images.githubusercontent.com/9472095/46105187-45e6a500-c1cd-11e8-93c2-24fe935f6e7b.png)


## An introduction to the new style of Cloud Infrastructure using HASHICORP's - PACKER, VAGRANT, CONSUL, NOMAD & VAULT

These tools free up developers to focus on application development whilst giving operations teams a secure, flexible, scalable and governed infrastructure. These tools satisfy the most demanding cloud native applications of today but can still easily integrate with, deploy and manage traditional applications too.

The application used is a simple GOLANG web page counter. (I'm not a dev so be gentle) It can easily be replaced with another app and is not the focus of this repository - please focus on the features and capabilities that the HASHICORP toolset provides.

The webpage counter application uses a redis backend server, nginx web-proxy frontend server and a server that runs consul server, nomad server, and vault server. Clearly not a production setup but everything than you need to have some fun and hopefully learn a thing or two at the same time.

![img_0029](https://user-images.githubusercontent.com/9472095/45648555-d08a1e80-bac0-11e8-837c-1358597aa531.PNG)

## Prerequisites - mandatory

Ensure that [Vagrant](https://www.vagrantup.com/intro/getting-started/install.html) and [Virtualbox](https://www.virtualbox.org/wiki/Downloads) are both installed on the host system.

## Prerequisites - optional

If you'd like to get some real-world monitoring metrics like this

![image](https://user-images.githubusercontent.com/9472095/43784033-11d58e1e-9a5b-11e8-8358-db0f354974c4.png)

then you'll need a [DataDog API Key](https://docs.datadoghq.com/api) which you can obtain by signing up for a trial account [here](https://www.datadoghq.com/#).

## Installation
Simply clone this repository, source the environment variables file (var.env) and then build the vagrant environment as follows:

[Optional - export your datadog key]
``` bash
export DD_API_KEY=2504524abcd123eddda65431d5
```

``` bash
git clone git@github.com:allthingsclowd/web_page_counter.git
cd web_page_counter
source var.env
vagrant up
```

This takes about 8 minutes to complete on a MacBook Pro.

## CI/CD Pipeline Overview

__Central Repository__

Start with a centralised code repository like github, gitlab or bitbucket. These are all based on [Linus Torvalds'](https://en.wikipedia.org/wiki/Linus_Torvalds) open source distributed version control system called git. A good tutorial can be found [here](https://www.atlassian.com/git/tutorials).

When working with groups on code or collaborating on open source github repositories it's a good idea to leverage [github templates](https://blog.github.com/2016-02-17-issue-and-pull-request-templates/) at the start of a project to help standardise the PULL REQUESTS and ISSUE LOGS.

![image](https://user-images.githubusercontent.com/9472095/43801332-b32cada4-9a8a-11e8-8e92-6508498102dc.png)

__Continuous Integration__

[Travis-CI](https://travis-ci.org/) has been used to test application changes and deploy releases to github.

![image](https://user-images.githubusercontent.com/9472095/43800289-d151b05c-9a87-11e8-957c-9584e2906951.png)

This is achieved by signing up for a Travis-CI account, linking this to your github account, and then configuring a _**.travis.yml**_ file in the root of the repository.

``` yml
language: go
sudo: required
addons:
  apt:
    packages:
    - redis-server
    - lynx
    - jq
go:
- '1.10'
before_script:
- sudo rsync -az ${TRAVIS_BUILD_DIR}/ /usr/local/bootstrap/
- pushd packer
- if [ $VAGRANT_CLOUD_TOKEN ] ; then packer validate template.json ; fi
- popd
- bash scripts/install_consul.sh
- bash scripts/install_vault.sh
- bash scripts/configure_app_role.sh
- sudo cp /home/travis/.vault-token /usr/local/bootstrap/.vault-token
script:
- source ./var.env
- export REDIS_MASTER_IP=127.0.0.1
- export REDIS_MASTER_PASSWORD=""
- export LEADER_IP=127.0.0.1
# - sudo VAULT_ADDR=http://127.0.0.1:8200 vault secrets enable -version=1 kv
- sudo VAULT_ADDR=http://127.0.0.1:8200 vault status
- sudo VAULT_ADDR=http://127.0.0.1:8200 vault kv put kv/development/redispassword value=${REDIS_MASTER_PASSWORD}
- sudo VAULT_ADDR=http://127.0.0.1:8200 vault kv get kv/development/redispassword
- consul kv put "development/REDIS_MASTER_IP" "127.0.0.1"
- consul kv put "development/LEADER_IP" "127.0.0.1"
- bash scripts/travis_run_go_app.sh
deploy:
  provider: releases
  api_key:
    secure: dAo/pXZ/jan3BcUA2bbhYl2v5QAW2JRAsaM0g077OJYxjUoepWarrb8puk0zdGfZ92ER+a7jwmXudbFVzk22Vp/aliIMkbrouQXVrXQaWZq0H45XD3grC5Pgbjdbn/s7gfCXk6IsZNkc1ztkpluFGox7iZXIYsrWJDvnjMNuhs6KWQpymKD8VQaQU1AqnWOOCWmkqLOy7pXtf9XQS44I5KkUibNFc5vxDqZriNCAkVSYZbvhmEphRb2iWGEtTxrJtU61Gj+fVpu6wpEO0JgWZNqmJTXgIXiPYb9i//uuRnA8qVym+PBl2azkMrmRV7TFbyzes1S5P5aWq0SgcYPKDtb7c5zJUzZkvpqkGDvriLUO2qyZq5PIC1Ega/bzLQMj/Nd8OMaJZjjoTNDc8frqQ9j84Q1WYTt1mhkMJF4LjXTar45nomR2GjBWfrETQBCGmO4fKYyNctx4cg8arz7MwftPIEt6orDegQzu8HR5oCX0hBvzDwK96JGtT8vfC4LfhtftTtTO2VqIMZ7lPbHzgyIswSBcVc9B7VIPS4Zka8JEzO1CRzeoL9u6HWNsUnre/U+twyxNmkZ1ZQW1kjeet8PT6S7eVRJuMofQJwhP42gz3yve8LaDaOxihlmD+UHnBVpDGSYl2ieLr+TAh2uwBNhs0bdEHJFNfwvNg9ySXKs=
  file_glob: true
  file: 
    - "./templates/*"
    - "./webcounter"
  skip_cleanup: true
  on:
    repo: allthingsclowd/web_page_counter
    tags: true
```
__Continuous Deployment__

All commits, pull requests and merges automatically envoke a Travis-CI run.
When [Tags](https://help.github.com/articles/working-with-tags/) are applied to the repository Travis-CI also creates a "deployment" by uploading binaries or files from the build server to the githib repository - located under the releases tab.

![image](https://user-images.githubusercontent.com/9472095/43802124-d59ec898-9a8c-11e8-82d3-bad46fb68891.png)


## HashiCorp's Infrastructure Toolset

__Immutable Images with Packer__

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


__Infrastructure as Code (IaC) with Vagrant__

[Vagrant](https://www.vagrantup.com/), infrastructure as code for your workstation, has been used to define and build the application infrastructure used for this demonstration. The use of infrastructure as code, a.k.a. the _Vagrantfile_ in this repo, is what enables me to be able to consistently share this application and it's entire development environment consistently with you. IaC is a fundamental building block that facilitates our journey to the cloud.

``` hcl
Vagrant.configure("2") do |config|

    #override global variables to fit Vagrant setup
    ENV['REDIS_MASTER_NAME']||="masterredis01"
    ENV['REDIS_MASTER_IP']||="192.168.2.200"
    ENV['REDIS_SLAVE_NAME']||="slaveredis02"
    ENV['REDIS_SLAVE_IP']||="192.168.2.201"
    ENV['GO_GUEST_PORT']||="808"
    ENV['GO_HOST_PORT']||="808"
    ENV['NGINX_NAME']||="web01"
    ENV['NGINX_IP']||="192.168.2.250"
    ENV['NGINX_GUEST_PORT']||="9090"
    ENV['NGINX_HOST_PORT']||="9090"
    ENV['VAULT_NAME']||="vault01"
    ENV['VAULT_IP']||="192.168.2.10"
    ENV['LEADER_NAME']||="leader01"
    ENV['LEADER_IP']||="192.168.2.11"
    ENV['LISTENER_COUNT']||="3"
    ENV['SERVER_COUNT']||="2"
    ENV['DD_API_KEY']||="DON'T FORGET TO SET ME FROM CLI PRIOR TO DEPLOYMENT"
    
    #global config
    config.vm.synced_folder ".", "/vagrant"
    config.vm.synced_folder ".", "/usr/local/bootstrap"
    config.vm.box = "allthingscloud/go-counter-demo"
    config.vm.provision "shell", path: "scripts/install_consul.sh", run: "always"
    config.vm.provision "shell", path: "scripts/install_vault.sh", run: "always"
    config.vm.provision "shell", path: "scripts/install_dd_agent.sh", env: {"DD_API_KEY" => ENV['DD_API_KEY']}

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
    end

    config.vm.define "leader01" do |leader01|
        leader01.vm.hostname = ENV['LEADER_NAME']
        leader01.vm.provision "shell", path: "scripts/install_nomad.sh", run: "always"
        leader01.vm.provision "shell", path: "scripts/configure_app_role.sh", run: "always"
        leader01.vm.network "private_network", ip: ENV['LEADER_IP']
        leader01.vm.network "forwarded_port", guest: 8500, host: 8500
        leader01.vm.network "forwarded_port", guest: 8200, host: 8200
    end

    config.vm.define "redis01" do |redis01|
        redis01.vm.hostname = ENV['REDIS_MASTER_NAME']
        redis01.vm.network "private_network", ip: ENV['REDIS_MASTER_IP']
        redis01.vm.provision :shell, path: "scripts/install_redis.sh"
    end
    

    (1..2).each do |i|
        config.vm.define "godev0#{i}" do |devsvr|
            devsvr.vm.hostname = "godev0#{i}"
            devsvr.vm.network "private_network", ip: "192.168.2.#{100+i*10}"
            devsvr.vm.provision "shell", path: "scripts/install_nomad.sh", run: "always"
            devsvr.vm.provision "shell", path: "scripts/install_go_app.sh"
        end
    end

    config.vm.define "web01" do |web01|
        web01.vm.hostname = ENV['NGINX_NAME']
        web01.vm.network "private_network", ip: ENV['NGINX_IP']
        web01.vm.network "forwarded_port", guest: ENV['NGINX_GUEST_PORT'], host: ENV['NGINX_HOST_PORT']
        web01.vm.provision :shell, path: "scripts/install_webserver.sh"
   end

end
```

__KeyValue(KV) Store, Service Discovery & HealthCheck with Consul__

![image](https://user-images.githubusercontent.com/9472095/43804387-bf56beea-9a93-11e8-8465-955bcea194f1.png)

We've loaded the infrastructure environment variables into Consul's Key Vaule Store for access by the application.
We also use [Consul](https://www.consul.io/) to register the new web counter application instances along with their individual healthchecks once they're started. The Redis database server also has two healthchecks registered on Consul once it's installed.

![image](https://user-images.githubusercontent.com/9472095/43804493-1c7db088-9a94-11e8-9798-75131ae8ae1c.png)


__Consul-Template for Dynamic Configuration__

[Consul-Template](https://www.hashicorp.com/blog/introducing-consul-template.html) has been used in two areas of this application:
 - Dynamically configure the NGINX web frontend when WebCounter instances start or stop
 nginx.ctpl
 ``` bash
 upstream goapp {
 {{range services}}{{if .Name | regexMatch "goapp*"}}{{range service .Name}}
    server {{.Address}}:{{.Port}} max_fails=3 fail_timeout=60 weight=1; {{end}}{{end}}
 {{else}}server 127.0.0.1:65535; # force a 502{{end}}
}

server {
 listen 9090 default_server;

 location / {
   proxy_pass http://goapp;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   proxy_set_header Host $host;
   proxy_set_header X-Real-IP $remote_addr;
 }
}
 ```
 - Dynamically read Redis password from Vault and update Redis.conf file during Redis database deployment
redis.master.ctpl
``` bash
.
.
.
# When a child rewrites the AOF file, if the following option is enabled
# the file will be fsync-ed every 32 MB of data generated. This is useful
# in order to commit the file to the disk more incrementally and avoid
# big latency spikes.
aof-rewrite-incremental-fsync yes
maxmemory-policy noeviction
{{- with secret "kv/development/redispassword" }}
requirepass "{{ .Data.value }}"
{{- end}}
```

__VAULT for Centralised Secret Management__

![image](https://user-images.githubusercontent.com/9472095/43806523-357a7b2c-9a9c-11e8-9809-27eb2fa531cc.png)

[Vault](https://www.vaultproject.io/) is an incredibly powerful centralised secret management tool. You MUST start using someting like this today, especially when working in hybrid infrastructures such as public and private clouds. Historically we were happy to place a firewall at the perimeter of our networks and assume we were safe inside this nework. Well [history](https://krebsonsecurity.com/2014/02/target-hackers-broke-in-via-hvac-company/) has shown us this is a bad operating model. Modern infrastructure deployment architectures use the concept "Trust No One" (TNO). Products like Vault enable these new TNO architectures by providing Centralised Secret Management, Centralised Encryption as a Service & Auditing.

Vault is used here to store the Redis data password that is consumed by both the Redis Service (see above) and the WebCounter application instances on startup.

``` go
func getVaultKV(vaultKey string) string {

	// Get a new Consul client
	consulClient, err := consul.NewClient(consul.DefaultConfig())
	if err != nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth = "NOTGOOD"
	}

	// Get the static approle id - this could be baked into a base image
	appRoleIDFile, err := ioutil.ReadFile("/usr/local/bootstrap/.approle-id")
	if err != nil {
		fmt.Print(err)
	}
	appRoleID := string(appRoleIDFile)
	fmt.Printf("App-Role ID Returned : >> %v \n", appRoleID)

	// Get a provisioner token to generate a new secret -id ... this would usually occur in the orchestrator rather than the app???
	vaultTokenFile, err := ioutil.ReadFile("/usr/local/bootstrap/.provisioner-token")
	if err != nil {
		fmt.Print(err)
	}
	vaultToken := string(vaultTokenFile)
	fmt.Printf("Secret Token Returned : >> %v \n", vaultToken)

	// Read in the Vault address from consul
	vaultIP := getConsulKV(*consulClient, "LEADER_IP")
	vaultAddress := "http://" + vaultIP + ":8200"
	fmt.Printf("Secret Store Address : >> %v \n", vaultAddress)

	// Get a handle to the Vault Secret KV API
	vaultClient, err := vault.NewClient(&vault.Config{
		Address: vaultAddress,
	})
	if err != nil {
		fmt.Printf("Failed to get VAULT client >> %v \n", err)
		return "FAIL"
	}
	
	vaultClient.SetToken(vaultToken)
	
	// Generate a new Vault Secret-ID
    resp, err := vaultClient.Logical().Write("/auth/approle/role/goapp/secret-id", nil)
    if err != nil {
		fmt.Printf("Failed to get Secret ID >> %v \n", err)
		return "Failed"
    }
    if resp == nil {
		fmt.Printf("Failed to get Secfret ID >> %v \n", err)
		return "Failed"
    }

	secretID := resp.Data["secret_id"].(string)
	fmt.Printf("Secret ID Request Response : >> %v \n", secretID)

	// Now using both the APP Role ID & the Secret ID generated above
	data := map[string]interface{}{
        "role_id":   appRoleID,
		"secret_id": secretID,
	}

	fmt.Printf("Secret ID in map : >> %v \n", data)
	
	// Use the AppRole Login api call to get the application's Vault Token which will grant it access to the REDIS database credentials
	appRoletokenResponse := queryVault(vaultAddress,"/v1/auth/approle/login","",data,"POST")

	appRoletoken := appRoletokenResponse["auth"].(map[string]interface{})["client_token"]

	fmt.Printf("New API Secret Token Request Response : >> %v \n", appRoletoken)

	vaultClient.SetToken(appRoletoken.(string))

	completeKeyPath := "kv/development/" + vaultKey
	fmt.Printf("Secret Key Path : >> %v \n", completeKeyPath)

	// Read the Redis Credientials from VAULT
	vaultSecret, err := vaultClient.Logical().Read(completeKeyPath)
	if err != nil {
		fmt.Printf("Failed to read VAULT key value %v - Please ensure the secret value exists in VAULT : e.g. vault kv get %v >> %v \n", vaultKey, completeKeyPath, err)
		return "FAIL"
	}
	fmt.Printf("Secret Returned : >> %v \n", vaultSecret.Data["value"])
	result := vaultSecret.Data["value"]
	fmt.Printf("Secret Result Returned : >> %v \n", result.(string))
	return result.(string)
}
```

__Nomad for application scheduling a.k.a. bin packing__

![image](https://user-images.githubusercontent.com/9472095/43806561-585eb1d0-9a9c-11e8-9f03-e0a4282e8d3d.png)

Finally, [Nomad](https://www.nomadproject.io/) has been used to schedule the application deployment. Nomad can deploy any application at any scale on any cloud :)
It's uses a declarative syntax and will ensure that the required number of applications requested are maintained. This is why I put the crash button on the application - you can have some simple fun killing the application and watching Nomad resurrect it.

``` hcl
job "peach" {
    datacenters = ["dc1"]
    type        = "service"
    group "example" {
      count = 4
      task "example" {
        driver = "raw_exec"
        config {
            command = "/usr/local/bin/webcounter"
            args = ["-port=${NOMAD_PORT_http}", "-ip=0.0.0.0", "-templates=/usr/local/bin/templates/*.html"]
        }
        resources {
          cpu    = 20
          memory = 60
          network {
            port "http" {}
          }
        }


        service {
          name = "goapp-${NOMAD_PORT_http}"
          port = "http"
          check {
            name     = "http-check-goapp-${NOMAD_PORT_http}"
            type     = "http"
            path     = "/health"
            interval = "10s"
            timeout  = "2s"
          }
          check {
            type     = "script"
            name     = "api-check-goapp-${NOMAD_PORT_http}"
            command  = "/usr/local/bin/consul_goapp_verify.sh"
            args     = ["http://127.0.0.1:${NOMAD_PORT_http}/health"]
            interval = "60s"
            timeout  = "5s"

            check_restart {
              limit = 3
              grace = "90s"
              ignore_warnings = false
            }
          }
        }
      }
    }
}
```

__WebCounter Application__

The front end code and backend code has been separated. Back end APIs are available on port 9090 and the front end SPA angular application is served from port 9091 

![image](https://user-images.githubusercontent.com/9472095/46106049-92cb7b00-c1cf-11e8-9dcb-75533dd52955.png)


## TODO

### New Features

* Write up overview of new factory service the leverage's Vaults APP-Role to bootstrap the services
* Write up note on new web front end (just as a reminder for myself - lots of CORS challenges)

### Refactor

*. Configure a Consul Connect intention to permit the applications to communicate with the new Secret-ID Factory

## Done
* Build own box using packer with above scripts
* Upload to vagrantcloud
* Update Vagrant file to consume the new box
* Add a Consul(1) server 
* Remove scripts from Packer and link back to repo master scripts, use SCRIPTS feature
* Add 'manual' test scripts to TravisCI
   * source env file
   * over write variables for local redis 
   * use `curl -s` to verify app returns http 200 & exit 0
   * use `lynx --dump` to capture counter updates between refreshes
   * Add TravisCI for Go APP
* scripted added to read in var.env and upload to consul
* main.go modified to use consul for variables when it's present
* Add a Vault (1) server
* if golang app can't reach redis or any other error return a zero
* if consul is not up - fallback to var.env values
* update goapp to have a /health to provide the status of it's services (text only)
   * GOOD
   * NOTGOOD
* Register Redis on Consul  
   What: Register the redis service on consul  
   Why: So the GOApp can connect dynamically (discover) the service  
  
   How: Check ping, write a dummy k/v, read the dummy k/v  
* Register Go App in Consul  
   What: Register the goapp service on consul  
   Why: So the webtier (NGINX) can connect dynamically (discover) the service  
  
   How: Check the website is up & the /health url returns GOOD  
      * update goapp consul healthcheck to expect GOOD/NOTGOOD  
* Make readme pretty (again)  
* Make goAPP use consul to find redis port and ip  
* Make nginx use consul to populate the conf file (consul-template)
* 3 IPs per godev machine main.go using ip1:8080, ip2:8080, ip3:8080
* WRONG: Modify existing goapp to listen and respond on 3 ports -8081, 8082, 8083 (3 x gorountines)
 3 separate main.go instances on the one server
* If running on travis only create a single listener on port 8080
* Update Consul service healthcheck to accomodate new changes
* Update NGINX Consul-template to receive updates
* Update Travis to new requirements
* Repeat all of the above with a 2nd instance of the goapp server
* Sign up for Datadog trial account using a gmail alias e.g. <bob@gmail.com> becomes <bob+datadogtrial@gmail.com>
* Install DDog Agent on the Macbook and test using Guages & Counters
* Update application to submit datadog pagecount counter once redis has been successfully updated
* Add datadog guage that reports on the number of available goapp services
* Remove redis02 and vault servers - not required yet!
* Create another Datadog Test Account for the 5 servers
* Install datadog agent on all servers
* Update consul-template nginx routine to include goapp service guage routine
* Rollback to a single network ip on the vagrantfile
* Don't execute the goapp upon installation - nomad will be used to do this later
* Write a nomad job using the raw_exec driver (NOT DOCKER) to launch the application ONCE on any node
* Add tag that includes port details to ddog metric
* Add service checks/tests to nomad job
* Move all logs to `/vagrant/logs/`
* Add UI ability to terminate current go-app service - facilitate quicker nomad demo - either add button to main page or create new endpoint feature
* Add github templates
* Add Travis Deployment on Tags
* Update App deployment to use releases
* Backout the unauthorised architectural switch from Vault v1 Secrets to v2 Secrets (versioned)
* UNDO :Move Redis Password into VAULT KV - demonstrates best practice of using centralised secret management vault - time 4 hrs
* - modify vault installation to make binary accessable on all nodes
* - install envconsul on all nodes
* - auto-generate redis password on leader node and store in vault using vault client (binary)
* - update redis installation to utilise consul-template to get redis password from vault
* - revert main.go application to consume vault v1 secrets (unversioned)
* - Add Vault App-Role to Application__ for Vault Access Method - demonstrates best practice of using centralised secret management vault - time est: 4hrs
* AddDataDog event when crash occurs e.g. “app 8081 crashed” - provides enhance reporting metrics - time est:2hrs
* [Moved to it's own repo as requirement does not belong here](https://github.com/allthingsclowd/vault_versus_consul) Metrics: Consul KV versus Vault KV. Test with 100-1000 entries. Simple bash script timed - see if there's a significant overhead when using vault as a KV over Consul KV. - time est: 4hrs
* Build a new service (Secret-ID Factory) that generates a wrapped secret-id upon receipt of an app-role - (api only)
* Build this in a separate repository using a similar CI/CD pipeline mentality
* Deploy the new Secret-ID Factory as a service within this repo once complete
* Create Bash Functions to Replace the curl -s -s statements in configure_app_role.sh to make it nicer to read
* Modify the application to request a wrapped secret-id token from the new *Secret-ID Factory* outlined above inorder to obtain its vault token.
* Change colour from Red to Blue in hand drawn architecture diagram for statement in Redis boc "Password Stored in Vault"
* Remove all comments from redis.conf.ctpl
* Moved Redis service registration from HCL file to API - fixed tests too
* Move all the application service checks creation process into the application deployment itself rather than relying on external bash scripts for both redis and webpage counter
* Refactor application to leverage consul service discovery for VAULT details . 
* Added new, prettier, frontend that facilitates smoother demonstrations by separating the frontend and backend code,
  written in Angular 6 and served from the NGINX proxy server on port 9091
* Added Consul Connect for Redis Service






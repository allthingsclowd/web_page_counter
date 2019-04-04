# HashiCorp Application Workflow over Technology ![https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master](https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master)

![image](https://user-images.githubusercontent.com/9472095/54200937-bd369980-44cc-11e9-8149-d6b628d629ef.png)

This repository is used to demonstrate each of HashiCorp's key technologies and where they are frequently used throughout a typical application workflow.

## About the app

A simple web-page-counter application with the backend developed in Golang and the frontend developed in Angular. No programmers were harmed in the writting of this application, I hacked it together myself (be gentle).

Backend APIs are available on port 9090 and the frontend Angular application is served from port 9091.

[Angular frontend code](https://github.com/allthingsclowd/wep_page_counter_front-end)

![image](https://user-images.githubusercontent.com/9472095/46106049-92cb7b00-c1cf-11e8-9dcb-75533dd52955.png)

![a418a2ee-2347-425d-933a-21b72a9c23e6](https://user-images.githubusercontent.com/9472095/52670669-0bc63780-2f11-11e9-9a9d-b9074ab92543.jpeg)

In brief, Vagrant is used for initial development and testing of the application. This is integrated with Travis-CI to ensure the scripts are valid, not all scripts are idempotent yet, sorry, will get there eventually.
There's an example Packer template file that's used to package everything needed for both Virtualbox images and Azure images.
An monolithic terraform template file is provided to demonstrate how the application and infrastructure can be provisioned into Azure's public cloud. This will be broken down into modules and follow best practices in future iterations of this repository.
The application is deployed using Nomad's exec driver and queries Consul to discover the details of it's Redis database and then Vault provides access to the secret material. Another simple bootstraping application is leveraged to show how applications, virtual machines or containers could securely receive secret material.
Consul's service mesh capability is also leveraged to secure access to the Redis database.

## Detailed Overview

* [__Vagrant__](docs/vagrant/ReadMe.md) Setup Development Environment Locally
* [__Packer__](docs/packer/ReadMe.md) Package the Artefacts for Virtualbox and Azure
* [__Terraform__](docs/terraform/ReadMe.md) Setup Development Environment on Azure
* [__Travis-CI__](docs/travis/ReadMe.md) Continuous Integration Testing and Releases
* [__Consul__](docs/consul/ReadMe.md)
  * [Service Discovery](docs/consul/ReadMe.md)
  * [Service Configuration](docs/consul/ReadMe.md)
  * [Service Mesh](docs/consul/ReadMe.md)
  * [Consul-Template](docs/consul/ReadMe.md)
* [__Vault__](docs/vault/ReadMe.md)
  * [Secret Management](docs/vault/ReadMe.md)
  * [Consul-Template](docs/vault/ReadMe.md)
* [__Nomad__](docs/nomad/ReadMe.md)

<!-- * [__Nginx__](docs/nginx/ReadMe.md) -->

* [__DataDog__](docs/datadog/ReadMe.md)

## When all is good it should look like this

![image](https://user-images.githubusercontent.com/9472095/46105006-cbb62080-c1cc-11e8-8f54-6eab4023a5bb.png)

## When we envoke a failure the self healing kicks in

![image](https://user-images.githubusercontent.com/9472095/46105187-45e6a500-c1cd-11e8-93c2-24fe935f6e7b.png)

## TODO

### New Features

* Write up note on new web front end (just as a reminder for myself - lots of CORS challenges)
* Write up details on terraform code and improve documentation in general

### Refactor

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
* modify vault installation to make binary accessable on all nodes
* install envconsul on all nodes
* auto-generate redis password on leader node and store in vault using vault client (binary)
* update redis installation to utilise consul-template to get redis password from vault
* revert main.go application to consume vault v1 secrets (unversioned)
* Add Vault App-Role to Application__ for Vault Access Method - demonstrates best practice of using centralised secret management vault - time est: 4hrs
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
* Refactored app to handle consul connect services
* Upgraded to latest binaries for Nomad, Vault, Consul, Golang
* Upgraded packer base image from Ubuntu 16.04 to Ubuntu 18.04
* Updated readme for [VaultFactoryID Service](https://github.com/allthingsclowd/VaultServiceIDFactory/blob/master/readme.md) - the application bootstrapping service used 
* Added Consul Connect Service Mesh for application bootstrapping service
* Configure a Consul Connect intention to permit the applications to communicate with the new Secret-ID factory
* Added TLS to Consul services
* Enabled Consul ACLs
* Reconfigured all services to work with TLS and ACLs now required on consul
* Configured consul connect service mesh for the webpagecounter go application
* Configured consul intentions for REDIS and APPROLE services
* Updated Documentation
* Added Chef's Inspec test framework to test packer builds before release to production
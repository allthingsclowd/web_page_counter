![https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master](https://travis-ci.org/allthingsclowd/web_page_counter.svg?branch=master)


# Web Page Counter
## An introduction to the new style of Cloud Infrastructure using HASHICORP's - PACKER, VAGRANT, CONSUL, NOMAD & VAULT

These tools free up developers to focus on application development whilst giving operations teams a secure, flexible, scalable and governed infrastructure. These tools satisfy the most demanding cloud native applications of today but can still easily integrate with, deploy and manage traditional applications too.

The application used is a simple GOLANG web page counter. (I'm not a dev so be gentle) It can easily be replaced with another app and is not the focus of this repository - please focus on the features and capabilities that the HASHICORP toolset provides.

The webpage counter application uses a redis backend server, nginx web-proxy frontend server and a server that runs consul server, nomad server, and vault server. Clearly not a production setup.


![0dc20014-3036-44e5-aa43-0bddc3e5df7a](https://user-images.githubusercontent.com/9472095/42727319-66902a26-879c-11e8-8241-b68414eaffab.jpeg)

## Installation
Simply clone this repository, source the environment variables file (var.env) and then build the vagrant environment as follows:

``` bash
git clone git@github.com:allthingsclowd/web_page_counter.git
cd web_page_counter
source var.env
vagrant up
```

This takes about 8 minutes to complete on a MacBook Pro.

## Verification
The nginx web frontend is mapped to port 9090 on the local machine. Simply open a browser and point to http://localhost:9090  

![image](https://user-images.githubusercontent.com/9472095/40511389-6ec338d2-5f97-11e8-8796-a68d6d2268fd.png)

or

``` bash
$ curl localhost:9090

<!DOCTYPE html>
<html>
<body>

<h2 title="Webpage Counter">Webpage Counter
   
    <div style=color:blue>6</div>
    </h2>


</body>
</html>
```

## Debug
 - Check that the vagrant environment built correctly
 ``` bash
$ vagrant status
Current machine states:

redis01                   running (virtualbox)
redis02                   running (virtualbox)
godev01                   running (virtualbox)
web01                     running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
 ```

 - Log on to the redis master server (redis01) and check the database is accessible.
 ``` bash
$ vagrant ssh redis01

vagrant@redis01:~$ redis-cli -a 's0m3th!ngr0tt3n?'
127.0.0.1:6379> set foo "hello"
OK
127.0.0.1:6379> get foo
"hello"
127.0.0.1:6379>
 ```
 Redis master server is good, now to check the slave server (redis02) just repeat the steps shown above. Instead of setting foo simply read it back to verify it has synced across from the master.

  - The application server is also port mapped to the host on 8080 so we can by-pass the nginx proxy server by calling this port directly
  ``` bash
$ curl localhost:8080
<!DOCTYPE html>
<html>
<body>

<h2 title="Webpage Counter">Webpage Counter
   
    <div style=color:blue>7</div>
    </h2>


</body>
</html>
```

## TODO

### Refactor
* Add tag that includes port details to ddog metric
* Add service checks/tests to nomad job
* Move all logs to `/vagrant/logs/`


### A
* Move Redis Password into VAULT KV



### D
* Use Consul KV as a temporary cache whilst Redis server is unavailable
* Metrics: Consul KV versus Vault KV - test with 100-1000 entries

## Done
* Build own box using packer with above scripts
* Upload to vagrantcloud
* Update Vagrant file to consume the new box
* Add a Consul(1) server 
* Remove scripts from Packer and link back to repo master scripts, use SCRIPTS feature
* Add 'manual' test scripts to TravisCI
   * source env file
   * over write variables for local redis 
   * use `curl` to verify app returns http 200 & exit 0
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




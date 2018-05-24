# golang_web_page_counter
Golang webpage counter application server using two redis clustered backend servers and a nginx web-proxy frontend server. Traditional 3 tier application model.

## Purpose
This repository was created to familiarise myself with Vagrant and infrastructure environment creation

## Installation
Simply clone this repository, source the environment variables file (var.env) and then build the vagrant environment as follows:

``` bash
git clone git@github.com:allthingsclowd/golang_web_page_counter.git
cd golang_web_page_counter
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

<h2 title="Golang Counter">Golang Webpage Counter
   
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

<h2 title="Golang Counter">Golang Webpage Counter
   
    <div style=color:blue>7</div>
    </h2>


</body>
</html>
```




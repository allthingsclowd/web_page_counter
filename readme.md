# Redis Master-Slave Vagrantfile
This vagrantfile builds a two node redis deployment in master-slave configuration.

Ensure to source the environment.sh file before running vagrant up

## Deployment

``` bash
source var.env
vagrant up
```

## Verification
Prerequisites - redis-cli needs to be installed on the host system. For a Mac this is achieved by installing the Redis binaries with brew
``` bash
brew install redis
```

Log into the master node and create an entry as follows:
``` bash
redis-cli -a 's0m3th!ngr0tt3n?' -h 192.168.2.200
set foo bar
get foo
exit
```

Now log in to the read-only slave server and verify that the redis cache has been synchronised:
``` bash
redis-cli -a 's0m3th!ngr0tt3n?' -h 192.168.2.201
get foo
exit
```

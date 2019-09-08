# Application Workflow with Vault - Overview

![image](https://user-images.githubusercontent.com/9472095/54201657-7d70b180-44ce-11e9-96e9-0f6790e47c6d.png)

## Challenge

![image](https://user-images.githubusercontent.com/9472095/54204395-751b7500-44d4-11e9-8656-2657ff9ccf87.png)

## Solution

![image](https://user-images.githubusercontent.com/9472095/54204569-c1ff4b80-44d4-11e9-8be3-deeb27a2b4be.png)

## VAULT for Centralised Secret Management

![image](https://user-images.githubusercontent.com/9472095/43806523-357a7b2c-9a9c-11e8-9809-27eb2fa531cc.png)

[Vault](https://www.vaultproject.io/) is an incredibly powerful centralised secret management tool. You MUST start using someting like this today, especially when working in hybrid infrastructures such as public and private clouds. Historically we were happy to place a firewall at the perimeter of our networks and assume we were safe inside this nework. Well [history](https://krebsonsecurity.com/2014/02/target-hackers-broke-in-via-hvac-company/) has shown us this is a bad operating model. Modern infrastructure deployment architectures use the concept "Trust No One" (TNO). Products like Vault enable these new TNO architectures by providing Centralised Secret Management, Centralised Encryption as a Service & Auditing.

Vault is used here to store the Redis data password that is consumed by both the Redis Service (see above) and the WebCounter application instances on startup.

**Accessing Vault UI**
Open a browser on your laptop/host and navigate to http://${LEADER_IP}:8200
The value for ${LEADER_IP} can be found in the _var.env_ file but typically will default to 192.168.9.11
_e.g. http://192.168.9.11:8200_
The password is set to `reallystrongpassword`

**Storing a Password**
The example below taken from _scripts/install_vault.sh_ illustrates how secrets can be stored in Vault using the vault cli.

``` bash
bootstrap_secret_data () {
    
    echo 'Set environmental bootstrapping data in VAULT'
    REDIS_MASTER_PASSWORD=`openssl rand -base64 32`
    APPROLEID=`cat /usr/local/bootstrap/.appRoleID`
    DB_VAULT_TOKEN=`cat /usr/local/bootstrap/.database-token`
    AGENTTOKEN=`cat /usr/local/bootstrap/.agenttoken_acl`
    WRAPPEDPROVISIONERTOKEN=`cat /usr/local/bootstrap/.wrapped-provisioner-token`
    BOOTSTRAPACL=`cat /usr/local/bootstrap/.bootstrap_acl`
    # Put Redis Password in Vault
    sudo VAULT_ADDR="http://${IP}:8200" vault login ${ADMIN_TOKEN}
    # FAILS???? sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault policy list
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/redispassword value=${REDIS_MASTER_PASSWORD}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/consulagentacl value=${AGENTTOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/vaultdbtoken value=${DB_VAULT_TOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/approleid value=${APPROLEID}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/wrappedprovisionertoken value=${WRAPPEDPROVISIONERTOKEN}
    sudo VAULT_TOKEN=${ADMIN_TOKEN} VAULT_ADDR="http://${IP}:8200" vault kv put kv/development/bootstraptoken value=${BOOTSTRAPACL}

}
```

**Retrieving a Password using Consul-Template**
The _install_redis.sh_ script uses _[consul-template](https://www.consul.io/docs/guides/consul-template.html)_ to demonstrate how a traditional application configuration file can be populated with secrets from Vault dynamically at deployment time.

A template configuration file needs to be created like _master.redis.ctpl_

``` bash
.
.
.
# Ensure Redis only listens on the local host when configuring Consul connect
bind 127.0.0.1

# Consul-Template is used in the redis file at deployment time
# It reads the password from Vault and inserts it into this file
{{- with secret "kv/development/redispassword" }}
requirepass "{{ .Data.value }}"
{{- end}}
```

which results in

``` bash
.
.
.
# Ensure Redis only listens on the local host when configuring Consul connect
bind 127.0.0.1

# Consul-Template is used in the redis file at deployment time
# It reads the password from Vault and inserts it into this file
requirepass "8G3BkAe8mXd2XsXlTQNIGCzBl3DXzmTURtWScJRcp8g="

```

when _consul-template_ is executed as follows

``` bash
sudo VAULT_TOKEN=${DB_VAULT_TOKEN} VAULT_ADDR="http://${LEADER_IP}:8200" consul-template -template "/usr/local/bootstrap/conf/master.redis.ctpl:/etc/redis/redis.conf" -once
```

**Retrieving a Password using Vault's Golang SDK**

First of all we need to import the library `vault "github.com/hashicorp/vault/api"`

``` go
func getVaultKV(consulClient consul.Client, vaultKey string) string {

	// Read in the Vault service details from consul
	vaultService := getConsulSVC(consulClient, "vault")
	vaultAddress = "http://" + vaultService
	fmt.Printf("Secret Store Address : >> %v \n", vaultAddress)

	// Get a handle to the Vault Secret KV API
	vaultClient, err := vault.NewClient(&vault.Config{
		Address: vaultAddress,
	})
	if err != nil {
		fmt.Printf("Failed to get VAULT client >> %v \n", err)
		return "FAIL"
	}

	approleService := getConsulSVC(consulClient, "approle")
	// Replace service ip address with loopback address when using connect proxy
	approleService = convert4connect(approleService)
	appRoletoken := getVaultToken(approleService, *appRoleID)
	fmt.Printf("New Application Token : >> %v \n", appRoletoken)

	vaultClient.SetToken(appRoletoken)

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

## BootStrapping an Application using APPROLE

[VaultFactoryID Service](https://github.com/allthingsclowd/VaultServiceIDFactory/blob/master/readme.md)

# Vault Service ID Factory

## Solving Secret Zero or Application Boot strapping

![913ee4e2-b01c-4749-8daa-f3ec5f8e5203](https://user-images.githubusercontent.com/9472095/43364036-20dbed52-930a-11e8-9e93-6de1290108b6.png)

## An example service that generates a wrapped secret-id upon receipt of an approle name

This service will be used as the broker between vault and applications to bootstrap the secret-id delivery process.

The service defaults to port 8314.

It has the following 3 API endpoints - 
 
 1. /initialiseme - this endpoint requires a POST with the following json package { "token" : "wrapped token" }
 This should be a wrapped vault authentication token that has permission to create SECRET_IDs
 ``` bash
 curl --header 'Content-Type: application/json' --request POST --data '{"token":"b76e6d87-1719-2fe5-42a1-b2a528bfd817"}' http://localhost:8314/initialiseme
 ```
 Once a valid token is received the health status of the application is changed from `UNINITIALISED` to `INITIALISED`

 2. /approlename - this endpoint requires a POST with the following json package { "RoleName" : "id-factory" }
 ``` bash
 curl --header 'Content-Type: application/json' --request POST --data '{"RoleName":"id-factory"}' http://localhost:8314/approlename
 ```
 This endpoint only becomes operational once the application has been initialised through the endpoint outlined in 1 above.
 When a valid AppRole name is provided a matching WRAPPED Vault SECRET_ID Token is returned.

 3. /health - displays the current application state
 ``` bash
 curl http://localhost:8314/health
 ```

 ## Status
 ``` bash
 UNINITIALISED - no valid ##WRAPPED## vault token received
 INITIALISED - valid ##WRAPPED## vault token recieved
 TOKENDELIVERED - a wrapped secret-id has been returned to an api request
 WRAPSECRETIDFAIL - failed to generate a wrapped secret-id
```
# Vault's AppRole

## How to Bootstrap the Bootstrapping Service

A special token with limited scope, a provisioner token, is generated by a vault administrator and shared with the owner of the provisioner bootstrapping service. This token is used to initialise the Secret-ID Factory Service.

![image](https://user-images.githubusercontent.com/9472095/47529556-14322e00-d8a0-11e8-8c22-4a4f5b2fdbc3.png)

## Application Bootstrapping Workflow

How does the application get it's Vault token?

![image](https://user-images.githubusercontent.com/9472095/47529600-27dd9480-d8a0-11e8-83ba-bf9b507632cf.png)

[:back:](../../ReadMe.md)
package main

import (
	"fmt"
	"net/http"
	"github.com/gorilla/mux"
	"html/template"
	"github.com/go-redis/redis"
	"os"
	"strings"
	consul "github.com/hashicorp/consul/api"
	vault "github.com/hashicorp/vault/api"
	"strconv"
	"flag"
	datadog "github.com/allthingsclowd/datadoghelper"
)

var templates *template.Template
var redisClient *redis.Client
var redisMaster string
var redisPassword string
var goapphealth = "GOOD"
var consulClient *consul.Client
var targetPort string
var targetIP string
var thisServer string

func main() {
	// set the port that the goapp will listen on - defaults to 8080
	
	portPtr := flag.Int("port", 8080, "Default's to port 8080. Use -port=nnnn to use listen on an alternate port.")
	ipPtr := flag.String("ip", "0.0.0.0", "Default's to all interfaces by using 0.0.0.0")
	templatePtr := flag.String("templates", "templates/*.html", "Default's to templates/*.html -templates=????")
	flag.Parse()
	targetPort = strconv.Itoa(*portPtr)
	targetIP = *ipPtr
	thisServer, _= os.Hostname()
	fmt.Printf("Incoming port number: %s \n", targetPort)
	redisMaster, redisPassword = redisInit()

	if (redisMaster == "0") || (redisPassword == "0") {

		fmt.Printf("Check the Consul service is running \n")
		goapphealth = "NOTGOOD"

	} else {

		redisClient = redis.NewClient(&redis.Options{
			Addr:     redisMaster,
			Password: redisPassword,
			DB:       0,  // use default DB
		})
		
		_, err := redisClient.Ping().Result()
		if err != nil {
			fmt.Printf("Failed to ping Redis: %v. Check the Redis service is running \n", err)
			goapphealth="NOTGOOD"
		}
	}

	var portDetail strings.Builder
	portDetail.WriteString(targetIP)
	portDetail.WriteString(":")
	portDetail.WriteString(targetPort)
	fmt.Printf("URL: %s \n", portDetail.String())

	templates = template.Must(template.ParseGlob(*templatePtr))
	r := mux.NewRouter()
	r.HandleFunc("/", indexHandler).Methods("GET")
	r.HandleFunc("/health", healthHandler).Methods("GET")
	http.Handle("/", r)
	http.ListenAndServe(portDetail.String(), r)
	
}



func indexHandler(w http.ResponseWriter, r *http.Request) {
	pagehits, err := redisClient.Incr("pagehits").Result()
	if err != nil {
		fmt.Printf("Failed to increment page counter: %v. Check the Redis service is running \n", err)
		goapphealth="NOTGOOD"
		pagehits = 0
	}
	fmt.Printf("Successfully updated page counter to: %v \n", pagehits)
	goapphealth="GOOD"
	dataDog := datadog.UpdateDataDogGuagefromValue("pageCounter", "totalPageHits", float64(pagehits))
	if !dataDog {
		fmt.Printf("Failed to set datadog guage.")
	}
	dataDog = datadog.IncrementDataDogCounter("pageCounter", "currentPageHits")
	if !dataDog {
		fmt.Printf("Failed to set datadog counter.")
	}
	w.Header().Set("PageCountIP", targetIP)
	w.Header().Set("PageCountServer", thisServer)
	w.Header().Set("PageCountPort", targetPort)
	 
	pageErr := templates.ExecuteTemplate(w, "index.html", pagehits)
	if pageErr != nil {
		fmt.Printf("Failed to Load Application Status Page: %v \n", pageErr)
	}
	
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	
	fmt.Printf("Application Status: %v \n", goapphealth)
	w.Header().Set("PageCountIP", targetIP)
	w.Header().Set("PageCountServer", thisServer)
	w.Header().Set("PageCountPort", targetPort)
	err := templates.ExecuteTemplate(w, "health.html", goapphealth)
	if err != nil {
		fmt.Printf("Failed to Load Application Status Page: %v \n", err)
	}
	
}

func getVaultKV(vaultKey string) string {
	
	// Get a new Consul client
	consulClient, err := consul.NewClient(consul.DefaultConfig())
	if err !=nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth="NOTGOOD"
	}

	vaultToken := getConsulKV(*consulClient, "VAULT_TOKEN")
	vaultAddress := getConsulKV(*consulClient, "VAULT_ADDR")

	// Get a handle to the Vault Secret KV API
	vaultClient, err := vault.NewClient(&vault.Config{
		Address: vaultAddress,
	})

	vaultClient.SetToken(vaultToken)

	completeKeyPath := "secret/data/development/"+vaultKey

	vaultSecret, err := vaultClient.Logical().Read(completeKeyPath)
	if err != nil {
		fmt.Printf("Failed to read VAULT key value %v - Please ensure the secret value exists in VAULT : e.g. vault kv get %v >> %v \n",vaultKey,vaultKey,err)
		return "FAIL"
	}

	result := vaultSecret.Data["data"].(map[string]interface{})["value"]
	//fmt.Printf("secret data.value %s -> %v \n", vaultKey, result)

	return result.(string)
}


func getConsulKV(consulClient consul.Client, key string) string {
	
	// Get a handle to the KV API
	kv := consulClient.KV()

	consulKey := "development/"+key

	appVar, _, err := kv.Get(consulKey, nil)
	if err != nil {
		fmt.Printf("Failed to read key value %v - Please ensure key value exists in consul : e.g. consul kv get %v >> %v \n",key,key, err)
		appVar, ok := os.LookupEnv(key)
		if ok {
			return appVar
		}
		fmt.Printf("Failed to read environment variable %v - Please ensure %v variable is set >> %v \n",key,key, err)
		return "FAIL"

	}

	return string(appVar.Value)
}

func getConsulSVC(consulClient consul.Client, key string) string {
	
	var serviceDetail strings.Builder
	// get handle to catalog service api
	sd := consulClient.Catalog()

	myService, _, err := sd.Service(key, "", nil)
	if err != nil {
		fmt.Printf("Failed to discover Redis Service : e.g. curl http://localhost:8500/v1/catalog/service/redis >> %v \n", err)
		return "0"
	}
	serviceDetail.WriteString(string(myService[0].Address))
	serviceDetail.WriteString(":")
	serviceDetail.WriteString(strconv.Itoa(myService[0].ServicePort))

	return serviceDetail.String()
}
	
func redisInit() (string, string) {
	
	var redisService string
	var redisPassword string
	
	// Get a new Consul client
	consulClient, err := consul.NewClient(consul.DefaultConfig())
	if err !=nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth="NOTGOOD"
	}

	redisPassword = getVaultKV("REDIS_MASTER_PASSWORD")
	redisService = getConsulSVC(*consulClient, "redis")
	if redisService == "0" {
		var serviceDetail strings.Builder
		redisHost := getConsulKV(*consulClient, "REDIS_MASTER_IP")
		redisPort := getConsulKV(*consulClient, "REDIS_HOST_PORT")
		serviceDetail.WriteString(redisHost)
		serviceDetail.WriteString(":")
		serviceDetail.WriteString(redisPort)
		redisService = serviceDetail.String()
	}
	
	return redisService, redisPassword

}
package main

import (
	"fmt"
	"net/http"
	"github.com/gorilla/mux"
	"html/template"
	"github.com/go-redis/redis"
	"os"
	"strings"
	"github.com/hashicorp/consul/api"
	"strconv"
)

var templates *template.Template
var redisClient *redis.Client
var redisMaster string
var redisPassword string
var goapphealth = "GOOD"
var consulClient *api.Client

func main() {



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


	
	templates = template.Must(template.ParseGlob("templates/*.html"))
	r := mux.NewRouter()
	r.HandleFunc("/", indexHandler).Methods("GET")
	r.HandleFunc("/health", healthHandler).Methods("GET")
	http.Handle("/", r)

	// Get a new Consul client
	consulClient, err := api.NewClient(api.DefaultConfig())
	if err !=nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth="NOTGOOD"
	}

	listenerCount, err:= strconv.Atoi(getConsulKV(*consulClient, "LISTENER_COUNT"))
	initialAppPort, err:= strconv.Atoi(getConsulKV(*consulClient, "GO_HOST_PORT"))
	
	var portDetail strings.Builder

	if listenerCount > 1 {
		for i:=initialAppPort+listenerCount;i+1>initialAppPort; i-- {
			go func(i int) {
				fmt.Printf("Launching initial webserver on port %d",i)
				portDetail.Reset()
				portDetail.WriteString(":")
				portDetail.WriteString(strconv.Itoa(i))
				http.ListenAndServe(portDetail.String(), r)
			}(i)

		}
		initialAppPort++
	} 
	portDetail.Reset()
	portDetail.WriteString(":")
	portDetail.WriteString(strconv.Itoa(initialAppPort))
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

	pageErr := templates.ExecuteTemplate(w, "index.html", pagehits)
	if pageErr != nil {
		fmt.Printf("Failed to Load Application Status Page: %v \n", pageErr)
	}
	
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	
	fmt.Printf("Application Status: %v \n", goapphealth)
	err := templates.ExecuteTemplate(w, "health.html", goapphealth)
	if err != nil {
		fmt.Printf("Failed to Load Application Status Page: %v \n", err)
	}
	
}

func getConsulKV(consulClient api.Client, key string) string {
	
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

func getConsulSVC(consulClient api.Client, key string) string {
	
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
	consulClient, err := api.NewClient(api.DefaultConfig())
	if err !=nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth="NOTGOOD"
	}

	redisPassword = getConsulKV(*consulClient, "REDIS_MASTER_PASSWORD")
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


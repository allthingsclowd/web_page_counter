package main

import (
	"log"
	"net/http"
	"github.com/gorilla/mux"
	"html/template"
	"github.com/go-redis/redis"
	"os"
	"fmt"
	"strings"
	"github.com/hashicorp/consul/api"
	"strconv"
)

var templates *template.Template
var client *redis.Client
var redisMaster string
var redisPassword string


func main() {
	redisMaster, redisPassword = redis_init()

	client = redis.NewClient(&redis.Options{
		Addr:     redisMaster,
		Password: redisPassword,
		DB:       0,  // use default DB
	})
	
	_, err := client.Ping().Result()
	if err != nil {
		log.Fatalf("Failed to ping Redis: %v. Check the Redis service is running", err)
	}

	templates = template.Must(template.ParseGlob("templates/*.html"))
	r := mux.NewRouter()
	r.HandleFunc("/", indexHandler).Methods("GET")
	http.Handle("/", r)
	http.ListenAndServe(":8080", nil)
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	pagehits, err := client.Incr("pagehits").Result()
	if err != nil {
		log.Fatalf("Failed to increment page counter: %v. Check the Redis service is running", err)
	}

	templates.ExecuteTemplate(w, "index.html", pagehits)
	
}

func redis_init() (string, string) {
	
	var Master strings.Builder
	var Password string
	
	// Get a new client
	client, err := api.NewClient(api.DefaultConfig())
	if err !=nil {
		log.Fatalf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v", err)
	}

	// Get a handle to the KV API
    kv := client.KV()

	redisPasswordkvp, _, err := kv.Get("development/REDIS_MASTER_PASSWORD", nil)
	if err != nil {
		log.Printf("Failed to read key value <development/REDIS_MASTER_PASSWORD> - Please ensure key value exists : e.g. consul kv get development/REDIS_MASTER_PASSWORD >> %v", err)
		Password = os.Getenv("REDIS_MASTER_PASSWORD")
	} else {
		Password = string(redisPasswordkvp.Value)
		fmt.Println(string(redisPasswordkvp.Value))
	}

	// get handle to catalog service api
	sd := client.Catalog()

	redisService, _, err := sd.Service("redis", "primary", nil)
	if err != nil {
		log.Printf("Failed to discover Redis Service : e.g. curl http://localhost:8500/v1/catalog/service/redis >> %v", err)
	} else {
		Master.WriteString(string(redisService[0].Address))
		Master.WriteString(":")
		Master.WriteString(strconv.Itoa(redisService[0].ServicePort))
		fmt.Println(Master.String())
	}

	return Master.String(), Password

}


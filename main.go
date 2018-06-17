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
	consulapi "github.com/hashicorp/consul/api"
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
	
	config := consulapi.DefaultConfig()
    config.Address = "127.0.0.1:8500"
	consul, err := consulapi.NewClient(config)

	kv := consul.KV()

	redisMasterkvp, _, err := kv.Get("development/REDIS_MASTER_IP", nil)
	if err != nil {
		fmt.Println(err)
		Master.WriteString(os.Getenv("REDIS_MASTER_IP"))
	} else {
		Master.WriteString(string(redisMasterkvp.Value))
		fmt.Println(string(redisMasterkvp.Value))
	}

	Master.WriteString(":")

	redisPortkvp, _, err := kv.Get("development/REDIS_HOST_PORT", nil)
	if err != nil {
		fmt.Println(err)
		Master.WriteString(os.Getenv("REDIS_HOST_PORT"))
	} else {
		Master.WriteString(string(redisPortkvp.Value))
		fmt.Println(string(redisPortkvp.Value))
	}

	redisPasswordkvp, _, err := kv.Get("development/REDIS_MASTER_PASSWORD", nil)
	if err != nil {
		fmt.Println(err)
		Password = os.Getenv("REDIS_MASTER_PASSWORD")
	} else {
		Password = string(redisPasswordkvp.Value)
		fmt.Println(string(redisPasswordkvp.Value))
	}

	return Master.String(), Password

}


package main

import (
	"log"
	"net/http"
	"github.com/gorilla/mux"
	"html/template"
	"github.com/go-redis/redis"
	"os"
)

var templates *template.Template
var client *redis.Client
const redisMaster = os.Getenv("REDIS_MASTER_IP") + ":" + os.Getenv("REDIS_HOST_PORT")
const redisPassword = os.Getenv("REDIS_MASTER_PASSWORD")

func main() {
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
	http.ListenAndServe(":8000", nil)
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	pagehits, err := client.Incr("pagehits").Result()
	if err != nil {
		log.Fatalf("Failed to increment page counter: %v. Check the Redis service is running", err)
	}

	//pagehits := client.Get("pagehits")

	templates.ExecuteTemplate(w, "index.html", pagehits)
	
}



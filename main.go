package main

import (
	"flag"
	"fmt"
	"html/template"
	"io/ioutil"
	"encoding/json"
	"net/http"
	"os"
	"strconv"
	"strings"
	"bytes"
	"time"

	"github.com/DataDog/datadog-go/statsd"
	"github.com/go-redis/redis"
	"github.com/gorilla/mux"
	consul "github.com/hashicorp/consul/api"
	vault "github.com/hashicorp/vault/api"
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
var appRoleID *string
var factoryIPPtr *string
var vaultAddress string

func main() {
	// set the port that the goapp will listen on - defaults to 8080

	portPtr := flag.Int("port", 8080, "Default's to port 8080. Use -port=nnnn to use listen on an alternate port.")
	ipPtr := flag.String("ip", "127.0.0.1", "Default's to all interfaces by using 127.0.0.1")
	appRoleID = flag.String("appRole", "id-factory", "Application Role Name to be used to bootstrap access to Vault's secrets")
	flag.Parse()
	targetPort = strconv.Itoa(*portPtr)
	targetIP = *ipPtr
	thisServer, _ = os.Hostname()
	fmt.Printf("Incoming port number: %s \n", targetPort)
	redisMaster, redisPassword = redisInit()

	if (redisMaster == "0") || (redisPassword == "0") {

		fmt.Printf("Check the Consul service is running \n")
		goapphealth = "NOTGOOD"

	} else {

		redisClient = redis.NewClient(&redis.Options{
			Addr:     redisMaster,
			Password: redisPassword,
			DB:       0, // use default DB
		})

		_, err := redisClient.Ping().Result()
		if err != nil {
			fmt.Printf("Failed to ping Redis: %v. Check the Redis service is running \n", err)
			goapphealth = "NOTGOOD"
		}
	}

	var portDetail strings.Builder
	portDetail.WriteString(targetIP)
	portDetail.WriteString(":")
	portDetail.WriteString(targetPort)
	fmt.Printf("URL: %s \n", portDetail.String())

	r := mux.NewRouter()
	r.HandleFunc("/", indexHandler).Methods("GET")
	r.HandleFunc("/", optionsHandler).Methods("OPTIONS")
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/health", optionsHandler).Methods("OPTIONS")
	r.HandleFunc("/crash", crashHandler).Methods("POST")
	r.HandleFunc("/crash", optionsHandler).Methods("OPTIONS")
	http.Handle("/", r)
	http.ListenAndServe(portDetail.String(), r)

}

func enableCors(w *http.ResponseWriter) {
	(*w).Header().Set("Access-Control-Allow-Origin", "*")
	(*w).Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, PATCH, DELETE")
	(*w).Header().Set("Access-Control-Allow-Headers", "Cache-Control, Content-Type")
	(*w).Header().Set("PageCountIP", targetIP)
	(*w).Header().Set("PageCountServer", thisServer)
	(*w).Header().Set("PageCountPort", targetPort)
}



func indexHandler(w http.ResponseWriter, r *http.Request) {
	pagehits, err := redisClient.Incr("pagehits").Result()

	enableCors(&w)
	if err != nil {
		fmt.Printf("Failed to increment page counter: %v. Check the Redis service is running \n", err)
		fmt.Fprintf(w, "Failed to increment page counter: %v. Check the Redis service is running \n", err)
		goapphealth = "NOTGOOD"
		pagehits = 0
	} else {
		fmt.Printf("Successfully updated page counter to: %v \n", pagehits)
		fmt.Fprintf(w, "%v", pagehits)
		goapphealth = "GOOD"
		dataDog := updateDataDogGuagefromValue("WebCounter", targetPort, "TotalPageHits", float64(pagehits))
		if !dataDog {
			fmt.Printf("Failed to set datadog guage.")
		}
		dataDog = incrementDataDogCounter("WebCounter", targetPort, "PageHits")
		if !dataDog {
			fmt.Printf("Failed to set datadog counter.")
		}

	}


}

func healthHandler(w http.ResponseWriter, r *http.Request) {

	enableCors(&w)
	fmt.Fprintf(w, "%v", goapphealth)
	fmt.Printf("Application Status: %v \n", goapphealth)

}

func optionsHandler(w http.ResponseWriter, r *http.Request) {

	enableCors(&w)
	return

}

func crashHandler(w http.ResponseWriter, r *http.Request) {
	
	enableCors(&w)
	goapphealth = "Killing service on port " + targetPort + "on server " + thisServer + "(" + targetIP + ")!"
	fmt.Printf("Application Status: %v \n", goapphealth)
	fmt.Fprintf(w, "%v", goapphealth)
	dataDog := sendDataDogEvent("WebCounter Crashed", targetPort)
	if !dataDog {
		fmt.Printf("Failed to send datadog event.")
	}
	// added delay to ensure event is sent before process terminates
	time.Sleep(3 * time.Second)
	os.Exit(1)

}

func getVaultKV(vaultKey string) string {

	// Get a new Consul client
	consulClient, err := consul.NewClient(consul.DefaultConfig())
	if err != nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth = "NOTGOOD"
	}

	// Read in the Vault service details from consul
	vaultService := getConsulSVC(*consulClient, "vault")
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

	approleService := getConsulSVC(*consulClient, "approle")
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

func getConsulKV(consulClient consul.Client, key string) string {

	// Get a handle to the KV API
	kv := consulClient.KV()

	consulKey := "development/" + key

	appVar, _, err := kv.Get(consulKey, nil)
	if err != nil {
		fmt.Printf("Failed to read key value %v - Please ensure key value exists in consul : e.g. consul kv get %v >> %v \n", key, key, err)
		appVar, ok := os.LookupEnv(key)
		if ok {
			return appVar
		}
		fmt.Printf("Failed to read environment variable %v - Please ensure %v variable is set >> %v \n", key, key, err)
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
	if err != nil {
		fmt.Printf("Failed to contact consul - Please ensure both local agent and remote server are running : e.g. consul members >> %v \n", err)
		goapphealth = "NOTGOOD"
	}

	redisPassword = getVaultKV("redispassword")
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

// UpdateDataDogGuagefromValue takes a namespace, guage name and guage value as input parameters
// It sends the supplied guage value as it's dd guage value
// to the local datadog agent
func updateDataDogGuagefromValue(myNameSpace string, myTag string, myGuage string, myValue float64) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
	defer ddClient.Close()
	if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}
	// prefix every metric with the app name
	ddClient.Namespace = myNameSpace
	// send a tag with every metric
	ddClient.Tags = append(ddClient.Tags, "port:"+myTag)

	// send value to DataDog agent
	err = ddClient.Gauge(myGuage, myValue, nil, 1)
	if err != nil {
		fmt.Printf("Failed to send new Guage value to DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}

	return true
}

// IncrementDataDogCounter takes a namespace and counter name as input parameters
// It sends an increment request to the supplied counter
// to the local datadog agent
func incrementDataDogCounter(myNameSpace string, myTag string, myCounter string) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
	defer ddClient.Close()
	if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}
	// prefix every metric with the app name
	ddClient.Namespace = myNameSpace
	// send a tag with every metric
	ddClient.Tags = append(ddClient.Tags, "port:"+myTag)

	err = ddClient.Incr(myCounter, nil, 1)
	if err != nil {
		fmt.Printf("Failed to send counter increment to DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}

	return true
}

// SendDataDogEvent 
func sendDataDogEvent(title string, eventMessage string) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
	defer ddClient.Close()
	if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}

	// send event message
	err = ddClient.SimpleEvent(title, eventMessage)
	// prefix every metric with the app name
	if err != nil {
		fmt.Printf("Failed to send new event to DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
	}
	
	return true
}

func queryVault(vaultAddress string, url string, token string, data map[string]interface{}, action string) map[string]interface{} {
	fmt.Println("\nDebug Vars Start")
	fmt.Println("\nVAULT_ADDR:>", vaultAddress)
	fmt.Println("\nURL:>", url)
	fmt.Println("\nTOKEN:>", token)
	fmt.Println("\nDATA:>", data)
	fmt.Println("\nVERB:>", action)
	fmt.Println("\nDebug Vars End")

	apiCall := vaultAddress + url
	bytesRepresentation, err := json.Marshal(data)

    req, err := http.NewRequest(action, apiCall, bytes.NewBuffer(bytesRepresentation))
    req.Header.Set("X-Vault-Token", token)
    req.Header.Set("Content-Type", "application/json")

    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        panic(err)
    }
    defer resp.Body.Close()

    fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	
	var result map[string]interface{}

	json.NewDecoder(resp.Body).Decode(&result)

	fmt.Println("\n\nresponse result: ",result)
	fmt.Println("\n\nresponse result .auth:",result["auth"].(map[string]interface{})["client_token"])

	return result
}

func getVaultToken(factoryAddress string, appRole string) string {
	
	// fmt.Println("\nDebug Factory Service Vars Start")
	// fmt.Println("\nFACTORY ADDRESS:>", factoryAddress)
	// fmt.Println("\nAPP ROLE:>", appRole)
	// fmt.Println("\nDebug Vars End")

	factoryBaseURL := "http://" + factoryAddress
	healthAPI := factoryBaseURL + "/health"
	secretAPI := factoryBaseURL + "/approlename"
	vaultUnwrapAPI := vaultAddress + "/v1/sys/wrapping/unwrap"

	factoryStatusResponse := http2Call(healthAPI,nil,"GET","none")
	fmt.Println("\nHealth API Response:>", factoryStatusResponse)

	var jsonStr = []byte(`{"RoleName":"id-factory"}`)
	factoryWrappedSecretResponse := http2Call(secretAPI, jsonStr, "POST", "none")
	fmt.Println("\nWrapped Secret API Response:>", factoryWrappedSecretResponse)

	unwrappedSecretIDResponse := http2Call(vaultUnwrapAPI, nil, "POST", factoryWrappedSecretResponse)
	
	var result map[string]interface{}

 	json.Unmarshal([]byte(unwrappedSecretIDResponse),&result)

	fmt.Println("\n\nresponse result: ",result["data"].(map[string]interface{})["secret_id"])
	secretID := (result["data"].(map[string]interface{})["secret_id"]).(string)

	// Get the static approle id - this could be baked into a base image
	appRoleIDFile, err := ioutil.ReadFile("/usr/local/bootstrap/.appRoleID")
	if err != nil {
		fmt.Print(err)
	}
	appRoleID := string(appRoleIDFile)
	fmt.Printf("App-Role ID Returned : >> %v \n", appRoleID)

	// Now using both the APP Role ID & the Secret ID retrieve application token
	data := map[string]interface{}{
		"role_id":   appRoleID,
		"secret_id": secretID,
	}

	fmt.Printf("Secret ID in map : >> %v \n", data)
	
	// Use the AppRole Login api call to get the application's Vault Token which will grant it access to the REDIS database credentials
	appRoletokenResponse := queryVault(vaultAddress,"/v1/auth/approle/login","",data,"POST")

	appRoletoken := (appRoletokenResponse["auth"].(map[string]interface{})["client_token"]).(string)


	return appRoletoken
}


func http2Call (url string, data []byte, action string, token string) string {

    //fmt.Println("URL:>", url)

    req, err := http.NewRequest(action, url, bytes.NewBuffer(data))

	if token != "none" {
		fmt.Printf("Setting HEADER to : %v\n", token)
		req.Header.Set("X-Vault-Token", token)
		fmt.Printf("HEADER set to : %v\n", req.Header)
	}
	req.Header.Set("Content-Type", "application/json")
	fmt.Printf("HEADER set to : %v\n", req.Header)
	

    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
		fmt.Printf("Problems Reaching: %v\n", err)
        //panic(err)
    }
    defer resp.Body.Close()

    fmt.Println("response Status:", resp.Status)
    fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)
	result := string(body)
	fmt.Println("response Body:", result)

	return result
}
package datadog

import (
	"github.com/DataDog/datadog-go/statsd"
    "encoding/json"
    "fmt"
    "io/ioutil"
    "os"
)

type DDMetric struct {
    BackendCount int `json:"backendCount"`
}

func (m DDMetric) toString() string {
    return toJSON(m)
}

func toJSON(m interface{}) string {
    bytes, err := json.Marshal(m)
    if err != nil {
        fmt.Println(err.Error())
        os.Exit(1)
    }

    return string(bytes)
}

func getMetrics(filename string) []DDMetric {
    raw, err := ioutil.ReadFile(filename)
    if err != nil {
        fmt.Println(err.Error())
        os.Exit(1)
    }

    var c []DDMetric
    json.Unmarshal(raw, &c)
    //fmt.Println(c)
    return c
}

// UpdateDataDogGuagefromFile takes a namespace, guage name and json file name as input parameters
// It reads the json file and sends back the first value as it's guage value
// to the local datadog agent
func UpdateDataDogGuagefromFile(myNameSpace string, myGuage string, myFile string) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
    if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
    }
    // prefix every metric with the app name
    ddClient.Namespace = myNameSpace
    // send a tag with every metric - optional
    ddClient.Tags = append(ddClient.Tags, myGuage)
    
    // read metrics in from json file
    metrics := getMetrics(myFile)

    // grab the first metric - only expecting one in the array returned
	// fmt.Println(metrics[0].BackendCount)
    
    // send value to DataDog agent
    err = ddClient.Gauge(myGuage, float64(metrics[0].BackendCount), nil, 1)
    if err != nil {
		fmt.Printf("Failed to send new Guage value to DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
    }
    
    return true
}

// UpdateDataDogGuagefromValue takes a namespace, guage name and guage value as input parameters
// It sends the supplied guage value as it's dd guage value
// to the local datadog agent
func UpdateDataDogGuagefromValue(myNameSpace string, myGuage string, myValue float64) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
    if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
    }
    // prefix every metric with the app name
    ddClient.Namespace = myNameSpace
    // send a tag with every metric
    ddClient.Tags = append(ddClient.Tags, myGuage)
    
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
func IncrementDataDogCounter(myNameSpace string, myCounter string) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
    if err != nil {
		fmt.Printf("Failed to contact DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
    }
    // prefix every metric with the app name
    ddClient.Namespace = myNameSpace
    // send a tag with every metric
    ddClient.Tags = append(ddClient.Tags, myCounter)
	
    err = ddClient.Incr(myCounter, nil, 1)
    if err != nil {
		fmt.Printf("Failed to send counter increment to DataDog Agent: %v. Check the DataDog agent is installed and running \n", err)
		return false
    }
    
    return true
}
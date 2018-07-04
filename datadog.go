package main

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

func updateDataDogGuage(myMetricValue int, myNameSpace string, myFile string) bool {
	// get a pointer to the datadog agent
	ddClient, err := statsd.New("127.0.0.1:8125")
    if err != nil {
		fmt.Printf("Failed to contact DataDog Client: %v. Check the DataDog client is installed and running \n", err)
		return false
    }
    // prefix every metric with the app name
    ddClient.Namespace = myNameSpace
    // send bananas as a tag with every metric
    ddClient.Tags = append(ddClient.Tags, "pagecounter")
    
    // read metrics in from json file
    metrics := getMetrics(myFile)

    // if there's multiple parameters or metrics
    // for _, m := range metrics {
    //    fmt.Println(m.BackendCount)
   // }

    // grab the first metric
	fmt.Println(metrics[0].BackendCount)
	
	err = ddClient.Gauge("backend_guage", 4, nil, 1)
	err = ddClient.("backend_guage", 4, nil, 1)

    fmt.Println(toJSON(metrics))
}
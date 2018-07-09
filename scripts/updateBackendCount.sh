#!/usr/bin/env bash

SERVICES=`consul catalog services | grep goapp`
HEALTHYNODELIST=`curl http://localhost:8500/v1/health/state/passing | jq -r '.[] | select(.CheckID=="serfHealth") | .Node'`

SERVICECOUNT=0

# loop through the list of targeted services
for backend in $SERVICES;
do 
    SERVICENODELIST=`consul catalog nodes -service=$backend  | awk 'NR > 1{count++; print $1}'`
    # loop through all the healthy nodes
    for healthynode in $HEALTHYNODELIST;
    do
        # loop through the service nodes to see if they're healthy - consul returns previous state of service before node died :()
        for servicenode in $SERVICENODELIST;
        do
            if [ $servicenode = $healthynode ]; then
                SERVICECOUNT=$(($SERVICECOUNT+1))
            fi
        done
    done
done
echo "Total Backends: " $SERVICECOUNT;

CURRENTSC=`cat /usr/local/datadog/metric.json | jq .[0].backendCount`

if [ $CURRENTSC -eq $SERVICECOUNT ]; then
    echo "No updates required"
    exit 0
else
    echo "Updates in progess"
    sudo jq ".[0].backendCount = $SERVICECOUNT" /usr/local/bootstrap/conf/metric.json > /usr/local/datadog/metricupdate.json
    sudo mv /usr/local/datadog/metricupdate.json /usr/local/datadog/metric.json
    sudo service nginx reload
    sudo /usr/local/bin/updateDDGuage -file=/usr/local/datadog/metric.json
fi
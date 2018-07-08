#!/usr/bin/env bash

SERVICES=`consul catalog services | grep goapp`

SERVICECOUNT=0
for backend in $SERVICES;
do 
    BCOUNT=`consul catalog nodes -service=$backend  | awk '{count++} ;END{print count-1}'`;
    SERVICECOUNT=$(($SERVICECOUNT+$BCOUNT))
done
echo "Total Backends: " $SERVICECOUNT;

CURRENTSC=`cat /usr/local/datadog/metric.json | jq .[0].backendCount`

if [ $CURRENTSC -eq $SERVICECOUNT ]; then
    echo "No updates required"
    exit 0
else
    echo "Updates in progess"
    jq ".[0].backendCount = $SERVICECOUNT" /usr/local/bootstrap/conf/metric.json > /usr/local/datadog/metricupdate.json
    mv /usr/local/datadog/metricupdate.json /usr/local/datadog/metric.json
    service nginx reload
    /usr/local/bin/updateDDGuage -file=/usr/local/datadog/metric.json
fi
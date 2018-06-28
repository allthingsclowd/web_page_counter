#!/usr/bin/env bash
echo $1 $2 $3 $4
jq ".service.name = \"goapp_$4\"" $1 > /etc/consul.d/updated-goapp.json

#cat /etc/consul.d/updated-goapp.json

mv /etc/consul.d/updated-goapp.json $2

#cat $2

jq ".service.tags[0] = \"$4\"" $2 > /etc/consul.d/updated-goapp.json

#cat /etc/consul.d/updated-goapp.json

mv /etc/consul.d/updated-goapp.json $2

#cat $2

jq ".service.port = ${4}" $2 > /etc/consul.d/updated-goapp.json

#cat /etc/consul.d/updated-goapp.json

mv /etc/consul.d/updated-goapp.json $2

#cat $2

JSONARG="{
            \"args\": [\"/usr/local/bootstrap/scripts/consul_goapp_verify.sh\", \"${3}\"],
            \"interval\": \"10s\"
        }"

#echo $JSONARG
jq --argjson args "$JSONARG" '.service.checks[.service.checks|length] += $args' $2 > /etc/consul.d/updated-goapp.json

mv /etc/consul.d/updated-goapp.json $2
#cat $2

JSONARG="{
        \"id\": \"api_$4\",
        \"name\": \"HTTP REQUEST $4\",
        \"http\": \"${3}\",
        \"tls_skip_verify\": true,
        \"method\": \"GET\",
        \"interval\": \"10s\",
        \"timeout\": \"1s\" 
        }"
#echo $JSONARG
jq --argjson args "$JSONARG" '.service.checks[.service.checks|length] += $args' $2 > /etc/consul.d/updated-goapp.json

mv /etc/consul.d/updated-goapp.json $2
#cat $2
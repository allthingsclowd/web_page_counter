#!/usr/bin/env bash

create_consul_healthcheck() {
  # set the new healthcheck name
  jq ".service.name = \"goapp_$5\"" $1 > /etc/consul.d/updated-goapp.json
  mv /etc/consul.d/updated-goapp.json $2

  # set the healthcheck ip address
  jq ".service.address = \"$6\"" $2 > /etc/consul.d/updated-goapp.json
  mv /etc/consul.d/updated-goapp.json $2

  # set the service port
  jq ".service.port = ${4}" $2 > /etc/consul.d/updated-goapp.json
  mv /etc/consul.d/updated-goapp.json $2

  # create a profile with a scripted test
  JSONARG="{
              \"args\": [\"/usr/local/bootstrap/scripts/consul_goapp_verify.sh\", \"${3}\"],
              \"interval\": \"10s\"
          }"
  jq --argjson args "$JSONARG" '.service.checks[.service.checks|length] += $args' $2 > /etc/consul.d/updated-goapp.json
  mv /etc/consul.d/updated-goapp.json $2
  
  # create a http test
  JSONARG="{
          \"id\": \"api_$5\",
          \"name\": \"HTTP REQUEST $5\",
          \"http\": \"${3}\",
          \"tls_skip_verify\": true,
          \"method\": \"GET\",
          \"interval\": \"10s\",
          \"timeout\": \"1s\" 
          }"
  jq --argjson args "$JSONARG" '.service.checks[.service.checks|length] += $args' $2 > /etc/consul.d/updated-goapp.json
  mv /etc/consul.d/updated-goapp.json $2

}

# # Idempotency hack - if this file exists don't run the rest of the script
# if [ -f "${HOME}/vagrant_go_user" ]; then
#     exit 0
# fi

source /usr/local/bootstrap/var.env

# move this to base image during next refactor
apt-get install -y jq

# create a consul service definition directory
mkdir -p /etc/consul.d

export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
mkdir -p $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
cp -r /usr/local/bootstrap/. $HOME/gopath/src/github.com/allthingsclowd/web_page_counter/
cd $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
go get -t -v ./...
go build main.go

mkdir -p /usr/local/page_counter
cp -ap main templates /usr/local/page_counter

nomad job run /usr/local/bootstrap/nomad_job.hcl

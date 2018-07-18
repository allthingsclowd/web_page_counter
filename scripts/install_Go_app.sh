#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

# check goapp binary
export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
mkdir -p $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
cp -r /usr/local/bootstrap/. $HOME/gopath/src/github.com/allthingsclowd/web_page_counter/
cd $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
go get -t -v ./...
go build -o webcounter main.go
chmod +x webcounter
killall webcounter &>/dev/null
cp webcounter /usr/local/bin/.
cp -r /usr/local/bootstrap/templates /usr/local/bin/.
cp /usr/local/bootstrap/scripts/consul_goapp_verify.sh /usr/local/bin/.

nomad job run /usr/local/bootstrap/nomad_job.hcl

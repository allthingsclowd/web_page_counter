#!/usr/bin/env bash

source /usr/local/bootstrap/var.env

export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
mkdir -p $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
cp -r /usr/local/bootstrap/. $HOME/gopath/src/github.com/allthingsclowd/web_page_counter/
cd $HOME/gopath/src/github.com/allthingsclowd/web_page_counter
go get -t -v ./...
go build main.go

mkdir -p /usr/local/page_counter
killall main 2>/dev/null
cp -ap main templates /usr/local/page_counter

nomad job run /usr/local/bootstrap/nomad_job.hcl

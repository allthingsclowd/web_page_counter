#!/usr/bin/env bash

source /usr/local/bootstrap/var.env

sudo mkdir /usr/local/datadog

export GOPATH=$HOME/gopath
export PATH=$HOME/gopath/bin:$PATH
go get github.com/allthingsclowd/updateDDGuage
cd $HOME/gopath/src/github.com/allthingsclowd/updateDDGuage
cp metric.json /usr/local/datadog/.
go build -o updateDDGuage main.go
sudo chmod +x updateDDGuage
sudo cp updateDDGuage /usr/local/bin/.




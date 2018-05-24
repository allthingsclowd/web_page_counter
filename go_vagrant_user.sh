#!/usr/bin/env bash

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "$HOME/.vagrant_go_user" ]; then
    exit 0
fi

export REDIS_MASTER_IP=$REDIS_MASTER_IP
export REDIS_MASTER_PASSWORD=$REDIS_MASTER_PASSWORD
export REDIS_HOST_PORT=$REDIS_HOST_PORT

touch $HOME/.vagrant_go_user
mkdir -p ~/code/go/src
echo "export GOPATH=$HOME/code/go" >> $HOME/.bash_profile
source $HOME/.bash_profile
go get $GO_REPOSITORY
echo $GOPATH/src/$GO_REPOSITORY
cd $GOPATH/src/$GO_REPOSITORY
go build main.go
./main &


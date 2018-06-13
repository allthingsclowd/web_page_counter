#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

# Idempotency hack - if this file exists don't run the rest of the script
if [ -f "$HOME/.vagrant_go_user" ]; then
    exit 0
fi

touch $HOME/.vagrant_go_user
mkdir -p ~/code/go/src
echo "export GOPATH=$HOME/code/go" >> $HOME/.bash_profile
source $HOME/.bash_profile
go get $GO_REPOSITORY
echo $GOPATH/src/$GO_REPOSITORY
cd $GOPATH/src/$GO_REPOSITORY
go get ./...
go build main.go
./main &

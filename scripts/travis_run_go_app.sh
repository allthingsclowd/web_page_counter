#!/usr/bin/env bash
set -x

go get -mod=vendor ./...
go build -o webcounter -i main.go

# The End

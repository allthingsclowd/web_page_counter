#!/usr/bin/env bash
set -x

go get ./...
go build -o webcounter -i main.go

# The End

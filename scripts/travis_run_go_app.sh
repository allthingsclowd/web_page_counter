#!/usr/bin/env bash
set -x

/usr/local/go/bin/go get ./...
/usr/local/go/bin/go build -o webcounter -i main.go

# The End

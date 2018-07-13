#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

# install this package in base image in the future
which curl &>/dev/null || {
  sudo apt-get update
  sudo apt-get install -y curl
}

# install datadog agent
bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)"

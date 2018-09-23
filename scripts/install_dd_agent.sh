#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

# install datadog agent
bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)"

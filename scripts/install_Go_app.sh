#!/usr/bin/env bash
set -x

source /usr/local/bootstrap/var.env

# download binary and template file from latest release
curl -s https://api.github.com/repos/allthingsclowd/web_page_counter/releases/latest \
| grep "browser_download_url" \
| cut -d : -f 2,3 \
| tr -d \" | wget -i -

nomad job stop peach &>/dev/null
killall webcounter &>/dev/null
cp webcounter /usr/local/bin/.
cp *.html /usr/local/bin/templates.

cp /usr/local/bootstrap/scripts/consul_goapp_verify.sh /usr/local/bin/.

nomad job run /usr/local/bootstrap/nomad_job.hcl

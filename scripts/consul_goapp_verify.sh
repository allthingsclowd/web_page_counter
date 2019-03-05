#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -x

echo "running consul goapp client health test"
app_health="NOTGOOD"
app_health=`lynx --dump $1`
echo $app_health

if [ ${app_health} == "GOOD" ]; then
 echo "Application Services GOOD"
 exit 0
else
 echo "Application Services NOTGOOD"
 exit 1
fi
# The End
exit 0
#!/usr/bin/env bash
set -x

# delayed added to ensure consul has started on host - intermittent failures
sleep 20


go get ./...
go build -o webcounter main.go
./webcounter &

# delay added to allow webcounter startup
sleep 20

page_hit_counter=`lynx --dump http://localhost:8080 | awk 'FNR==3{ print $1 }'`
echo $page_hit_counter
next_page_hit_counter=`lynx --dump http://localhost:8080 | awk 'FNR==3{ print $1 }'`
echo $next_page_hit_counter
if (( next_page_hit_counter > page_hit_counter )); then
 echo "Successful Page Hit Update"
 exit 0
else
 echo "Failed Page Hit Update"
 exit 1
fi
# The End

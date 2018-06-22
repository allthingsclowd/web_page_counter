#!/usr/bin/env bash

# delayed added to ensure consul has started on host - intermittent failures
sleep 5

go get ./...
go build main.go
./main &

page_hit_counter=`lynx --dump http://localhost:8080 | awk 'NR>2{ print $1 }'`
echo $page_hit_counter
next_page_hit_counter=`lynx --dump http://localhost:8080 | awk 'NR>2{ print $1 }'`
echo $next_page_hit_counter
if (( next_page_hit_counter > page_hit_counter )); then
 echo "Successful Page Hit Update"
 exit 0
else
 echo "Failed Page Hit Update"
 exit 1
fi
# The End

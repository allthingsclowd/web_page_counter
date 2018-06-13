#!/usr/bin/env bash
go build main.go
./main &

page_hit_counter=`lynx --dump http://localhost:9090 | awk 'NR>2{ print $1 }'`
next_page_hit_counter=`lynx --dump http://localhost:9090 | awk 'NR>2{ print $1 }'`
if (( next_page_hit_counter > page_hit_counter )); then
 exit 0
else
 exit 1
fi
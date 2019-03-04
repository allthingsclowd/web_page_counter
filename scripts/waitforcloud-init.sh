#!/usr/bin/env bash

while [ ! -f /tmp/finishedcloudinit.txt ]; 
do 
    echo 'Waiting for Cloud-init to complete'; 
    sleep 15;  
done
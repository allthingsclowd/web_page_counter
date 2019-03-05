#!/usr/bin/env bash

echo 'Check if Cloud-init Completed?'
while [ ! -f /tmp/finishedcloudinit.txt ]; 
do 
    echo 'Waiting for Cloud-init to complete'
    sleep 15
done
echo 'Confirmed Cloud-init Completed!'
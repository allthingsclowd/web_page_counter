#!/bin/bash

# Remove Vagrant Build User if it exists (used on vmware builds)
if id vagrant; then 
    echo 'vagrant build user exists'; 
    echo 'securing image by deleting vagant build user';
    sudo deluser --remove-home vagrant && echo 'vagrant user successfully deleted' || echo 'CAUTION: unable to delete vagrant user';
else 
    echo 'vagrant build user does not exist';
fi

exit 0

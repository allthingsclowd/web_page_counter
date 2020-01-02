#!/bin/bash

if ! crontab -l | grep deluser; then
    echo 'Setting up crontab to delete user'
    (crontab -l ; echo "@reboot deluser --remove-home vagrant")| crontab -
    crontab -l
else
    echo 'Resetting crontab back to what was originally there...possibly blank'
    (crontab -l | grep -v 'deluser --remove-home vagrant' )| crontab -
    crontab -l
fi

exit 0

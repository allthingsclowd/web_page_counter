#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -e

echo "running client ping test"

# check for redis hostname => master
if [[ "${HOSTNAME}" =~ "master" ]]; then
    TESTIP=${REDIS_MASTER_IP}
    TESTPASSWORD=${REDIS_MASTER_PASSWORD}
else
    TESTIP=${REDIS_SLAVE_IP}
    TESTPASSWORD=${REDIS_SLAVE_PASSWORD}
fi

RESULT=`redis-cli -h ${TESTIP} -p ${REDIS_HOST_PORT} -a ${TESTPASSWORD} ping`

if [ "$RESULT" == "PONG" ]; then
    echo 'Success Redis Ping resulted in '$RESULT
    exit 0
fi

echo 'Failed Redis Ping resulted in '$RESULT
exit 2
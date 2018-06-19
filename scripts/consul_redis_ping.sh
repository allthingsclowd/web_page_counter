#!/usr/bin/env bash
source /usr/local/bootstrap/var.env

set -e

echo "running client ping test"

RESULT=`redis-cli -h ${REDIS_MASTER_IP} -p ${REDIS_HOST_PORT} -a ${REDIS_MASTER_PASSWORD} ping`

if [ "$RESULT" == "PONG" ]; then
    echo 'Success Redis Ping resulted in '$RESULT
    exit 0
fi

echo 'Failed Redis Ping resulted in '$RESULT
exit 2
cat <<EOF | sudo tee /etc/consul.d/redis.json
{
  "service": {
    "name": "redis",
    "port": 6379,
    "connect": { "sidecar_service": {} }
  }
}
EOF


cat <<EOF | sudo tee /etc/consul.d/redis.json
{
  "service": {
    "name": "redis",
    "port": 6379,
    "address": "127.0.0.1",
    "connect": { "sidecar_service": {} }
  },
  "checks": [
          {
            "name": "redis-basic-connectivity",
            "args": ["/usr/local/bootstrap/scripts/consul_redis_ping.sh"],
            "interval": "10s"
          },
          {
              "name": "redis-functionality",
              "args": ["/usr/local/bootstrap/scripts/consul_redis_verify.sh"],
              "interval": "10s"
          }
        ]
}
EOF

sudo consul connect proxy -sidecar-for redis >${LOG} &

sudo consul connect proxy -service myapp -upstream redis:8888 &
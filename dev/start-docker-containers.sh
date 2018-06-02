#!/usr/bin/env bash

# In this project we are using `Postgres` database for Kong. Another option is `Cassandra`.
# If you'd like to use Cassandra, please refer to https://getkong.org/install/docker

echo "Starting graphite-statsd"
docker run -d \
  --name graphite \
  --restart=unless-stopped \
  -p 8081:80\
  -p 2003-2004:2003-2004 \
  -p 2023-2024:2023-2024 \
  -p 8125:8125/udp \
  -p 8126:8126 \
  graphiteapp/graphite-statsd:1.1.3

echo "Starting kong-database container"
docker run -d \
  --name kong-database \
  --restart=unless-stopped \
  -p 5432:5432 \
  -e "POSTGRES_USER=kong" \
  -e "POSTGRES_DB=kong" \
  postgres:10.3-alpine

sleep 5

echo "Running kong-database migration"
docker run --rm \
  --link kong-database:kong-database \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  kong:0.13.0 kong migrations up

sleep 3

echo "Starting kong"
docker run -d \
  --name kong \
  --restart=unless-stopped \
  --link kong-database:kong-database \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -e "KONG_ADMIN_LISTEN_SSL=0.0.0.0:8444" \
  -p 8000:8000 \
  -p 8443:8443 \
  -p 8001:8001 \
  -p 8444:8444 \
  kong:0.13.0

echo "-------------------------------------------"
echo "Containers started!"
echo "Press 'q' to stop and remove all containers"
echo "-------------------------------------------"
while true; do
    # In the following line -t for timeout, -N for just 1 character
    read -t 0.25 -N 1 input
    if [[ $input = "q" ]] || [[ $input = "Q" ]]; then
        echo
        break
    fi
done

echo "Removing containers"
docker rm -fv graphite kong-database kong

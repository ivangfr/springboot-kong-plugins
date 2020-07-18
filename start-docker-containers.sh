#!/usr/bin/env bash

# In this project we are using `Postgres` database for `Kong`. Another option is `Cassandra`.
# If you'd like to use Cassandra, please refer to https://getkong.org/install/docker

echo "Creating network"
docker network create springboot-kong-net

echo "Starting simple-service container"
docker run -d \
  --name simple-service \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  docker.mycompany.com/simple-service:1.0.0

echo "Starting ldap-host"
docker run -d \
  --name ldap-host \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  -p 389:389 \
  -e "LDAP_ORGANISATION=MyCompany Inc." \
  -e "LDAP_DOMAIN=mycompany.com" \
  osixia/openldap:1.3.0

echo "Starting graphite-statsd"
docker run -d \
  --name graphite-statsd \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  -p 8081:80 \
  -p 2003-2004:2003-2004 \
  -p 2023-2024:2023-2024 \
  -p 8125:8125/udp \
  -p 8126:8126 \
  graphiteapp/graphite-statsd:1.1.7-2

echo "Starting kong-database container"
docker run -d \
  --name kong-database \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  -p 5432:5432 \
  -e "POSTGRES_USER=kong" \
  -e "POSTGRES_PASSWORD=kong" \
  -e "POSTGRES_DB=kong" \
  postgres:12.3

sleep 5

echo "Starting phpldapadmin-service"
docker run -d \
  --name phpldapadmin-service \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  -p 6443:443 \
  -e "PHPLDAPADMIN_LDAP_HOSTS=ldap-host" \
  osixia/phpldapadmin:0.9.0

echo "Running kong-database migration"
docker run --rm \
  --network=springboot-kong-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_PASSWORD=kong" \
  kong:2.1.0-rc.1 kong migrations bootstrap

sleep 3

echo "Starting kong"
docker run -d \
  --name kong \
  --network=springboot-kong-net \
  --restart=unless-stopped \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_PASSWORD=kong" \
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
  kong:2.1.0-rc.1

echo "-------------------------------------------"
echo "Containers started!"
echo "Press 'q' to stop and remove all containers"
echo "-------------------------------------------"
while true; do
    # In the following line -t for timeout, -N for just 1 character
    read -t 0.25 -N 1 input
    if [[ ${input} = "q" ]] || [[ ${input} = "Q" ]]; then
        echo
        break
    fi
done

echo "Removing containers"
docker rm -fv simple-service graphite-statsd kong-database kong phpldapadmin-service ldap-host

echo "Removing network"
docker network rm springboot-kong-net

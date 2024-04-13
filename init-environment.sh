#!/usr/bin/env bash

SIMPLE_SERVICE_VERSION="1.0.0"
OPENLDAP_VERSION="1.5.0"
PHPLDAPADMIN_VERSION="0.9.0"
POSTGRES_VERSION="13.14"
KONG_VERSION="2.8.4"

if [[ "$(docker images -q ivanfranchin/simple-service:${SIMPLE_SERVICE_VERSION} 2> /dev/null)" == "" ]] ; then
  echo "[WARNING] Before initialize the environment, build the simple-service Docker image: ./docker-build.sh [native]"
  exit 1
fi

source scripts/my-functions.sh

echo
echo "Starting environment"
echo "===================="

echo
echo "Creating network"
echo "----------------"
docker network create springboot-kong-net

echo
echo "Starting simple-service"
echo "-----------------------"
docker run -d \
  --name simple-service \
  --restart=unless-stopped \
  --network=springboot-kong-net \
  ivanfranchin/simple-service:${SIMPLE_SERVICE_VERSION}

echo
echo "Starting openldap"
echo "-----------------"
docker run -d \
  --name openldap \
  -p 389:389 \
  -e "LDAP_ORGANISATION=MyCompany Inc." \
  -e "LDAP_DOMAIN=mycompany.com" \
  --restart=unless-stopped \
  --network=springboot-kong-net \
  osixia/openldap:${OPENLDAP_VERSION}

echo
echo "Starting phpldapadmin"
echo "---------------------"
docker run -d \
  --name phpldapadmin \
  -p 6443:443 \
  -e "PHPLDAPADMIN_LDAP_HOSTS=openldap" \
  --restart=unless-stopped \
  --network=springboot-kong-net \
  osixia/phpldapadmin:${PHPLDAPADMIN_VERSION}

echo
echo "Starting kong-database"
echo "----------------------"
docker run -d \
  --name kong-database \
  -p 5432:5432 \
  -e "POSTGRES_USER=kong" \
  -e "POSTGRES_PASSWORD=kong" \
  -e "POSTGRES_DB=kong" \
  --restart=unless-stopped \
  --network=springboot-kong-net \
  postgres:${POSTGRES_VERSION}

echo
wait_for_container_log "kong-database" "port 5432"

echo
echo "Running kong-database migration"
echo "-------------------------------"
docker run --rm \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_PASSWORD=kong" \
  --network=springboot-kong-net \
  kong:${KONG_VERSION} kong migrations bootstrap

echo
echo "Starting kong"
echo "-------------"
docker run -d \
  --name kong \
  -p 8000:8000 \
  -p 8443:8443 \
  -p 8001:8001 \
  -p 8444:8444 \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -e "KONG_ADMIN_LISTEN_SSL=0.0.0.0:8444" \
  --restart=unless-stopped \
  --network=springboot-kong-net \
  kong:${KONG_VERSION}

echo
wait_for_container_log "kong" "finished preloading"

echo
wait_for_container_log "simple-service" "Started"

echo
echo "Environment Up and Running"
echo "=========================="
echo

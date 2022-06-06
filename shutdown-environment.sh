#!/usr/bin/env bash

echo
echo "Starting the environment shutdown"
echo "================================="

echo
echo "Removing containers"
echo "-------------------"
docker rm -fv simple-service kong-database kong phpldapadmin openldap

echo
echo "Removing network"
echo "----------------"
docker network rm springboot-kong-net

echo
echo "Environment shutdown successfully"
echo "================================="
echo

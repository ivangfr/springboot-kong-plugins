# springboot-kong

The goal of this project is to create a simple [`Spring Boot`](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/) REST API and securing it with [`Kong`](https://getkong.org) using the `LDAP Authentication` and `Basic Authentication` plugins. Besides, we will explore more plugins that `Kong` offers like: `Rate Limiting`, `Prometheus` and `StatsD` plugins.

## Project Diagram

![project-diagram](images/project-diagram.png)

## Application

- ### simple-service

  `Spring Boot` Java Web application that exposes two endpoints:
   - `/api/public`: that can be access by anyone, it is not secured;
   - `/api/private`: that must be accessed only by authenticated users.

## Prerequisites

- [`Java 11+`](https://www.oracle.com/java/technologies/javase-jdk11-downloads.html)
- [`Docker`](https://www.docker.com/)
- [`jq`](https://stedolan.github.io/jq)

## Build application Docker Image

- Open a terminal and navigate to `springboot-kong` root folder

- Run the command below to build `simple-service` Docker Image
  ```
  ./mvnw clean compile jib:dockerBuild --projects simple-service
  ``` 

## Start environment

- In a terminal, make use you are in `springboot-kong` root folder

- Run the following script
  ```
  ./start-docker-containers.sh
  ```
  > **Note:** `simple-service` application is running as a docker container. The container does not expose any port to HOST machine. So, it cannot be accessed directly, forcing the caller to use `Kong` as gateway server in order to access it.

## Import OpenLDAP Users

The `LDIF` file that we will use, `springboot-kong/ldap/ldap-mycompany-com.ldif`, has already a pre-defined structure for `mycompany.com`. Basically, it has 2 groups (`developers` and `admin`) and 4 users (`Bill Gates`, `Steve Jobs`, `Mark Cuban` and `Ivan Franchin`). Besides, it is defined that `Bill Gates`, `Steve Jobs` and `Mark Cuban` belong to `developers` group and `Ivan Franchin` belongs to `admin` group.
```
Bill Gates > username: bgates, password: 123
Steve Jobs > username: sjobs, password: 123
Mark Cuban > username: mcuban, password: 123
Ivan Franchin > username: ifranchin, password: 123
```

There are two ways to import those users: by running a script or using `phpldapadmin`

### Import users running a script

- In another terminal, make use you are in `springboot-kong` root folder

- Run the following script
  ```
  ./import-openldap-users.sh
  ```
  
- Check users imported using [`ldapsearch`](https://linux.die.net/man/1/ldapsearch)
  ```
  ldapsearch -x -D "cn=admin,dc=mycompany,dc=com" \
    -w admin -H ldap://localhost:389 \
    -b "ou=users,dc=mycompany,dc=com" \
    -s sub "(uid=*)"
  ```

### Import users using phpldapadmin

- Access https://localhost:6443

- Login with the credentials
  ```
  Login DN: cn=admin,dc=mycompany,dc=com
  Password: admin
  ```

- Import the file `springboot-kong/ldap/ldap-mycompany-com.ldif`

- You should see something like

  ![openldap](images/openldap.png)

## Kong

In order to configure `Kong`, you need to go to a terminal.

### Check Status

- Before starting adding `Kong` Services, Routes and Plugins, check if it's running by executing the following command
  ```
  curl -I http://localhost:8001
  ```

  It should return
  ```
  HTTP/1.1 200 OK
  ```

### Add Service

- Using `application/x-www-form-urlencoded` content type
  ```
  curl -i -X POST http://localhost:8001/services/ \
    -d "name=simple-service" \
    -d "protocol=http" \
    -d "host=simple-service" \
    -d "port=8080"
  ```

**OR** 

- Using `application/json` content type. Besides, in order to set `protocol`, `host`, `port` and `path` at once, the `url` shorthand attribute can be used.
  ```
  curl -i -X POST http://localhost:8001/services/ \
    -H 'Content-Type: application/json' \
    -d '{ "name": "simple-service", "url":"http://simple-service:8080" }'
  ```

### Add routes

1. One default route for the service, no specific `path` included
   ```
   PUBLIC_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/simple-service/routes/ \
     -d "protocols[]=http" \
     -d "hosts[]=simple-service" | jq -r '.id')
     
   echo "PUBLIC_ROUTE_ID=$PUBLIC_ROUTE_ID"
   ```

1. Another route specifically for `/api/private` endpoint (it will be secured and only accessible by LDAP users)
   ```
   PRIVATE_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/simple-service/routes/ \
     -H 'Content-Type: application/json' \
     -d '{ "protocols": ["http"], "hosts": ["simple-service"], "paths": ["/api/private"], "strip_path": false }' | jq -r '.id')
   
   echo "PRIVATE_ROUTE_ID=$PRIVATE_ROUTE_ID"
   ```

1. Finally, one route for `/actuator/httptrace` endpoint (it will be secured and only accessible by pre-defined users)
   ```
   HTTPTRACE_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/simple-service/routes/ \
     -H 'Content-Type: application/json' \
     -d '{ "protocols": ["http"], "hosts": ["simple-service"], "paths": ["/actuator/httptrace"], "strip_path": false }' | jq -r '.id')
   
   echo "HTTPTRACE_ROUTE_ID=$HTTPTRACE_ROUTE_ID"
   ```

1. \[Optional\] To list all `simple-service` routes run
   ```
   curl -s http://localhost:8001/services/simple-service/routes | jq .
   ```

### Call endpoints

1. Call `/api/public` endpoint
   ```
   curl -i http://localhost:8000/api/public -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 200
   It is public.
   ```

1. Call `/api/private` endpoint
   ```
   curl -i http://localhost:8000/api/private -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 200
   null, it is private.
   ```

   > **Note:** This endpoint is not secured by the application, that is why the response is returned. The idea is to use `Kong` to secure it. It will be done on the next steps.

1. Call `/actuator/httptrace` endpoint
   ```
   curl -i http://localhost:8000/actuator/httptrace -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 200
   {"traces":[{"timestamp":"...
   ```

   > **Note:** As happened previously with `/api/private`, `/actuator/httptrace` endpoint is not secured by the application. We will use `Kong` to secure it on the next steps.

## Plugins

In this project, we are going to add those plugins: `LDAP Authentication`, `Basic Authentication`, `Rate Limiting`, `Prometheus` and `StatsD`. Please refer to https://konghq.com/plugins for more.

### Add LDAP Authentication plugin

The `LDAP Authentication` plugin will be used to secure the `/api/private` endpoint.

1. Add plugin to route `PRIVATE_ROUTE_ID`
   ```
   LDAP_AUTH_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$PRIVATE_ROUTE_ID/plugins \
     -d "name=ldap-auth" \
     -d "config.hide_credentials=true" \
     -d "config.ldap_host=ldap-host" \
     -d "config.ldap_port=389" \
     -d "config.start_tls=false" \
     -d "config.base_dn=ou=users,dc=mycompany,dc=com" \
     -d "config.verify_ldap_host=false" \
     -d "config.attribute=cn" \
     -d "config.cache_ttl=60" \
     -d "config.header_type=ldap" | jq -r '.id')
     
   echo "LDAP_AUTH_PLUGIN_ID=$LDAP_AUTH_PLUGIN_ID"
   ```

   > **Note:** If you need to update some `LDAP Authentication` plugin configuration, run the following `PATCH` call informing the field you want to update, for example
   > ```
   > curl -X PATCH http://localhost:8001/plugins/${LDAP_AUTH_PLUGIN_ID} -d "config.base_dn=ou=users,dc=mycompany,dc=com"
   > ```

1. Try to call `/api/private` endpoint without credentials
   ```
   curl -i http://localhost:8000/api/private -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 401 Unauthorized
   {"message":"Unauthorized"}
   ```

1. Call `/api/private` endpoint using Bill Gates base64 encode credentials
   ```
   curl -i http://localhost:8000/api/private \
     -H "Authorization:ldap $(echo -n 'Bill Gates':123 | base64)" \
     -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 200
   Bill Gates, it is private.
   ```

### Add Basic Authentication plugin

The `Basic Authentication` plugin will be used to secure the `/actuator/httptrace` endpoint

1. Add plugin to route `HTTPTRACE_ROUTE_ID`
   ```
   BASIC_AUTH_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$HTTPTRACE_ROUTE_ID/plugins \
     -d "name=basic-auth" \
     -d "config.hide_credentials=true" | jq -r '.id')
     
   echo "BASIC_AUTH_PLUGIN_ID=$BASIC_AUTH_PLUGIN_ID"
   ```

1. Try to call `/actuator/httptrace` endpoint without credentials.
   ```
   curl -i http://localhost:8000/actuator/httptrace -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 401 Unauthorized
   {"message":"Unauthorized"}
   ```

1. Create a consumer
   ```
   IFRANCHIN_CONSUMER_ID=$(curl -s -X POST http://localhost:8001/consumers -d "username=ivanfranchin" | jq -r '.id')
   
   echo "IFRANCHIN_CONSUMER_ID=$IFRANCHIN_CONSUMER_ID"
   ```

1. Create a credential for consumer
   ```
   IFRANCHIN_CREDENTIAL_ID2=$(curl -s -X POST http://localhost:8001/consumers/ivanfranchin/basic-auth \
     -d "username=ivan.franchin" \
     -d "password=123" | jq -r '.id')
     
   echo "IFRANCHIN_CREDENTIAL_ID2=$IFRANCHIN_CREDENTIAL_ID2"
   ```

1. Call `/api/private` endpoint using `ivan.franchin` credential
   ```
   curl -i -u ivan.franchin:123 http://localhost:8000/actuator/httptrace -H 'Host: simple-service'
   ```

   It should return
   ```
   HTTP/1.1 200
   {"traces":[{"timestamp":"...
   ```

1. Let's create another consumer just for testing purpose
   ```
   ADMINISTRATOR_CONSUMER_ID=$(curl -s -X POST http://localhost:8001/consumers -d "username=administrator" | jq -r '.id')
   
   echo "ADMINISTRATOR_CONSUMER_ID=$ADMINISTRATOR_CONSUMER_ID"
   
   ADMINISTRATOR_CREDENTIAL_ID=$(curl -s -X POST http://localhost:8001/consumers/administrator/basic-auth \
     -d "username=administrator" \
     -d "password=123" | jq -r '.id')
     
   echo "ADMINISTRATOR_CREDENTIAL_ID=$ADMINISTRATOR_CREDENTIAL_ID"
   ```

### Add Rate Limiting plugin

We are going to add the following rate limitings:
- `/api/public`: 1 request a second
- `/api/private`: 5 requests a minute
- `/actuator/httptrace`: 2 requests a minute or 100 requests an hour

1. Add plugin to route `PUBLIC_ROUTE_ID`
   ```
   PUBLIC_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$PUBLIC_ROUTE_ID/plugins \
     -d "name=rate-limiting"  \
     -d "config.second=1" | jq -r '.id')
     
   echo "PUBLIC_RATE_LIMIT_PLUGIN_ID=$PUBLIC_RATE_LIMIT_PLUGIN_ID"
   ```
1. Add plugin to route `PRIVATE_ROUTE_ID`
   ```
   PRIVATE_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$PRIVATE_ROUTE_ID/plugins \
     -d "name=rate-limiting"  \
     -d "config.minute=5" | jq -r '.id')
     
   echo "PRIVATE_RATE_LIMIT_PLUGIN_ID=$PRIVATE_RATE_LIMIT_PLUGIN_ID"
   ```

1. Add plugin to route `HTTPTRACE_ROUTE_ID`
   ```
   HTTPTRACE_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$HTTPTRACE_ROUTE_ID/plugins \
     -d "name=rate-limiting"  \
     -d "config.minute=2" \
     -d "config.hour=100" | jq -r '.id')
     
   echo "HTTPTRACE_RATE_LIMIT_PLUGIN_ID=$HTTPTRACE_RATE_LIMIT_PLUGIN_ID"
   ```

1. Make some calls to those endpoints

   - Test `/api/public`
     ```
     curl -i http://localhost:8000/api/public -H 'Host: simple-service'
     
     curl -i http://localhost:8000/actuator/health -H 'Host: simple-service'
     ```

   - Test `/actuator/httptrace`
     ```
     curl -I -u ivan.franchin:123 http://localhost:8000/actuator/httptrace -H 'Host: simple-service'
     
     curl -I -u administrator:123 http://localhost:8000/actuator/httptrace -H 'Host: simple-service'
     ```

   - Test `/api/private`
     ```
     curl -i http://localhost:8000/api/private \
       -H "Authorization:ldap $(echo -n 'Bill Gates':123 | base64)" \
       -H 'Host: simple-service'
     
     curl -i http://localhost:8000/api/private \
       -H "Authorization:ldap $(echo -n 'Mark Cuban':123 | base64)" \
       -H 'Host: simple-service'
     ```

1. After exceeding some calls in a minute, you should see
   ```
   HTTP/1.1 429 Too Many Requests
   {"message":"API rate limit exceeded"}
   ```

### Add Prometheus plugin

1. Add plugin to `simple-service`
   ```
   PROMETHEUS_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/services/simple-service/plugins \
     -d "name=prometheus" | jq -r '.id')
     
   echo "PROMETHEUS_PLUGIN_ID=$PROMETHEUS_PLUGIN_ID"
   ```

1. You can see some metrics
   ```
   curl -i http://localhost:8001/metrics
   ```

### Add StatsD plugin

1. Add plugin to `simple-service`
   ```
   GRAPHITE_STATSD_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/services/simple-service/plugins \
     -d "name=statsd"  \
     -d "config.host=graphite-statsd" \
     -d "config.port=8125" | jq -r '.id')
     
   echo "GRAPHITE_STATSD_PLUGIN_ID=$GRAPHITE_STATSD_PLUGIN_ID"
   ```

1. Make some requests to `simple-service` endpoints

1. Access `Graphite-Statsd` at http://localhost:8081 and check the `kong` statistics.

   ![graphite-statsd](images/graphite-statsd.png)

## Shutdown

Go to the terminal where you run the script `start-docker-containers.sh` and press `q` to stop and remove all containers

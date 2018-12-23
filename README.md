# springboot-kong

## Goal

The goal of this project is to create a simple REST API and securing it with [`Kong`](https://getkong.org) using the
`LDAP Authentication` and `Basic Authentication` plugins. Besides, we will explore more plugins that Kong offers like:
`Rate Limiting`, `StatsD` and `Prometheus` plugins.

## Build springboot-kong docker image

In `/springboot-kong` root folder, run
```
mvn clean package docker:build -DskipTests
``` 

## Start environment

Run the following script present in `springboot-kong` project root folder.
```
./start-docker-containers
```

> `springboot-kong` application is running in a docker container. The container does not expose any port to HOST machine.
> So, you cannot access the application directly, forcing the user to use of Kong as gateway server to access `springboot-kong`.

## Configuring OpenLDAP

![openldap](images/openldap.png)

1. Access the link: https://localhost:6443

2. Login with the credentials
```
Login DN: cn=admin,dc=mycompany,dc=com
Password: admin
```

3. Import the file `/springboot-kong/ldap/ldap-mycompany-com.ldif`

This file has already a pre-defined structure for mycompany.com.
Basically, it has 2 groups (developers and admin) and 4 users (Bill Gates, Steve Jobs, Mark Cuban and Ivan Franchin).
Besides, it is defined that Bill Gates, Steve Jobs and Mark Cuban belong to developers group and Ivan Franchin belongs to admin group.
```
Bill Gates > username: bgates, password: 123
Steve Jobs > username: sjobs, password: 123
Mark Cuban > username: mcuban, password: 123
Ivan Franchin > username: ifranchin, password: 123
```

4. In a terminal, you can test OpenLDAP
```
ldapsearch -x -D "cn=admin,dc=mycompany,dc=com" \
  -w admin -H ldap://localhost:389 \
  -b "ou=users,dc=mycompany,dc=com" \
  -s sub "(uid=*)"
```

## KONG

***Note. In order to run some commands/scripts, you must have [`jq`](https://stedolan.github.io/jq) installed on you
machine***

Before adding to Kong Services, Routes and Plugins, check if `Kong` it's running
``` 
curl -I http://localhost:8001
```

### Add Service

- Using `application/x-www-form-urlencoded` content type
```
curl -i -X POST http://localhost:8001/services/ \
  -d "name=springboot-kong" \
  -d "protocol=http" \
  -d "host=springboot-kong" \
  -d "port=8080"
```

**OR** 

- You can use `application/json` content type. Besides, in order to set `protocol`, `host`, `port` and `path` at once,
the `url` shorthand attribute can be used.
```
curl -i -X POST http://localhost:8001/services/ \
  -H 'Content-Type: application/json' \
  -d '{ "name": "springboot-kong", "url":"http://springboot-kong:8080" }'
```

### Add routes

1. One default route for the service, no specific `path` included
```
PUBLIC_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/springboot-kong/routes/ \
  -d "protocols[]=http" \
  -d "hosts[]=springboot-kong" | jq -r '.id')
  
echo "PUBLIC_ROUTE_ID=$PUBLIC_ROUTE_ID"
```

2. Another route specifically for `/api/private` endpoint (it will be secured and only accessible by LDAP users)
```
PRIVATE_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/springboot-kong/routes/ \
  -H 'Content-Type: application/json' \
  -d '{ "protocols": ["http"], "hosts": ["springboot-kong"], "paths": ["/api/private"], "strip_path": false }' | jq -r '.id')

echo "PRIVATE_ROUTE_ID=$PRIVATE_ROUTE_ID"
```

3. Finally, one route for `/actuator/httptrace` endpoint (it will be secured and only accessible by pre-defined users)
```
HTTPTRACE_ROUTE_ID=$(curl -s -X POST http://localhost:8001/services/springboot-kong/routes/ \
  -H 'Content-Type: application/json' \
  -d '{ "protocols": ["http"], "hosts": ["springboot-kong"], "paths": ["/actuator/httptrace"], "strip_path": false }' | jq -r '.id')

echo "HTTPTRACE_ROUTE_ID=$HTTPTRACE_ROUTE_ID"
```

> In order to list all `springboot-kong` routes, run: `curl -s http://localhost:8001/services/springboot-kong/routes | jq .`

### Call endpoints

1. `/api/public` endpoint
```
curl -i http://localhost:8000/api/public -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 200
It is public.
```

2. `/api/private` endpoint
```
curl -i http://localhost:8000/api/private -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 200
null, it is private.
```

**PS. this endpoint is not secured by the application, that is why the response is returned. The idea is to use Kong to
secure it. It will be done on the next steps.**

3. `/actuator/httptrace` endpoint
```
curl -i http://localhost:8000/actuator/httptrace -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 200
{"traces":[{"timestamp":"...
```

**PS. again, as happened previously with `/api/private`, `/actuator/httptrace` endpoint is not secured by the application.
We will use Kong to secure it on the next steps.**

### Plugins

In this project, we are going to add those plugins: `LDAP Authentication`, `Rate Limiting`, `StatsD` and `Basic Authentication`.
Please refer to https://konghq.com/plugins for more plugins.

#### Add LDAP Authentication plugin

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

> If you need to update some `LDAP Authentication` plugin configuration, run the following `PATCH` call informing
> the field you want to update, for example:
> ```
> curl -X PATCH http://localhost:8001/plugins/${LDAP_AUTH_PLUGIN_ID} \
>   -d "config.base_dn=ou=users,dc=mycompany,dc=com"
> ```

2. Try to call `/api/private` endpoint without credentials.
```
curl -i http://localhost:8000/api/private -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 401 Unauthorized
{"message":"Unauthorized"}
```

3. Call `/api/private` endpoint using Bill Gates base64 encode credentials
```
curl -i http://localhost:8000/api/private \
  -H "Authorization:ldap $(echo -n 'Bill Gates':123 | base64)" \
  -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 200
Bill Gates, it is private.
```

#### Add Basic Authentication plugin

The `Basic Authentication` plugin will be used to secure the `/actuator/httptrace` endpoint

1. Add plugin to route `HTTPTRACE_ROUTE_ID`
```
BASIC_AUTH_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$HTTPTRACE_ROUTE_ID/plugins \
  -d "name=basic-auth" \
  -d "config.hide_credentials=true" | jq -r '.id')
  
echo "BASIC_AUTH_PLUGIN_ID=$BASIC_AUTH_PLUGIN_ID"
```

2. Try to call `/actuator/httptrace` endpoint without credentials.
```
curl -i http://localhost:8000/actuator/httptrace -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 401 Unauthorized
{"message":"Unauthorized"}
```

3. Create a consumer
```
curl -X POST http://localhost:8001/consumers -d "username=ivanfranchin"
```

4. Create a credential for consumer
```
curl -X POST http://localhost:8001/consumers/ivanfranchin/basic-auth \
  -d "username=ivan.franchin" \
  -d "password=123"
```

5. Call `/api/private` endpoint using `ivan.franchin` credential
```
curl -i -u ivan.franchin:123 http://localhost:8000/actuator/httptrace -H 'Host: springboot-kong'
```

It should return
```
HTTP/1.1 200
{"traces":[{"timestamp":"...
```

6. Let's create another consumer just for testing purpose
```
curl -X POST http://localhost:8001/consumers -d "username=administrator"

curl -X POST http://localhost:8001/consumers/administrator/basic-auth \
  -d "username=administrator" \
  -d "password=123"
```

#### Add Rate Limiting plugin

We are going to add the following rate limitings:
- `/api/public`: 1 request a second;
- `/api/private`: 5 requests a minute;
- `/actuator/httptrace`: 2 requests a minute or 100 requests an hour.

Let's set them.

1. Add plugin to route `PUBLIC_ROUTE_ID`
```
PUBLIC_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$PUBLIC_ROUTE_ID/plugins \
  -d "name=rate-limiting"  \
  -d "config.second=1" | jq -r '.id')
  
echo "PUBLIC_RATE_LIMIT_PLUGIN_ID=$PUBLIC_RATE_LIMIT_PLUGIN_ID"
```
2. Add plugin to route `PRIVATE_ROUTE_ID`
```
PRIVATE_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$PRIVATE_ROUTE_ID/plugins \
  -d "name=rate-limiting"  \
  -d "config.minute=5" | jq -r '.id')
  
echo "PRIVATE_RATE_LIMIT_PLUGIN_ID=$PRIVATE_RATE_LIMIT_PLUGIN_ID"
```

3. Add plugin to route `HTTPTRACE_ROUTE_ID`
```
HTTPTRACE_RATE_LIMIT_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/routes/$HTTPTRACE_ROUTE_ID/plugins \
  -d "name=rate-limiting"  \
  -d "config.minute=2" \
  -d "config.hour=100" | jq -r '.id')
  
echo "HTTPTRACE_RATE_LIMIT_PLUGIN_ID=$HTTPTRACE_RATE_LIMIT_PLUGIN_ID"
```

4. Make some calls those endpoints

- Test `/api/public`
```
curl -i http://localhost:8000/api/public -H 'Host: springboot-kong'

curl -i http://localhost:8000/actuator/health -H 'Host: springboot-kong'
```

- Test `/actuator/httptrace`
```
curl -I -u ivan.franchin:123 http://localhost:8000/actuator/httptrace -H 'Host: springboot-kong'

curl -I -u administrator:123 http://localhost:8000/actuator/httptrace -H 'Host: springboot-kong'
```

- Test `/api/private`
```
curl -i http://localhost:8000/api/private \
  -H "Authorization:ldap $(echo -n 'Bill Gates':123 | base64)" \
  -H 'Host: springboot-kong'

curl -i http://localhost:8000/api/private \
  -H "Authorization:ldap $(echo -n 'Mark Cuban':123 | base64)" \
  -H 'Host: springboot-kong'
```

***P.S. The rate limiting is the same for Bill Gates and Mark Cuban! That's wrong!***

5. After exceeding some calls in a minute, you should see
```
HTTP/1.1 429 Too Many Requests
{"message":"API rate limit exceeded"}
```

#### Add StatsD plugin

1. Add plugin to `springboot-kong` service
```
GRAPHITE_STATSD_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/services/springboot-kong/plugins \
  -d "name=statsd"  \
  -d "config.host=graphite-statsd" \
  -d "config.port=8125" | jq -r '.id')
  
echo "GRAPHITE_STATSD_PLUGIN_ID=$GRAPHITE_STATSD_PLUGIN_ID"
```

2. Make some requests to `springbook-kong` endpoints

3. Access `Graphite-Statsd` at http://localhost:8081 and check the `kong` statistics.

![graphite-statsd](images/graphite-statsd.png)

#### Add Prometheus plugin

1. Add plugin to `springboot-kong` service
```
GRAPHITE_STATSD_PLUGIN_ID=$(curl -s -X POST http://localhost:8001/services/springboot-kong/plugins \
  -d "name=prometheus" | jq -r '.id')
  
echo "GRAPHITE_STATSD_PLUGIN_ID=$GRAPHITE_STATSD_PLUGIN_ID"
```

2. You can see some metrics
```
curl -i http://localhost:8001/metrics
```
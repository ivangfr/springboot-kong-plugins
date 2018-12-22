FROM openjdk:8-jdk-alpine

LABEL maintainer="ivangfr@yahoo.com.br"

RUN apk update && apk add ca-certificates wget && update-ca-certificates

ADD springboot-kong*.jar /springboot-kong.jar

CMD ["java", "-jar", "/springboot-kong.jar"]

EXPOSE 8080
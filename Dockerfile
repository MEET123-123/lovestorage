# Build the tested executable JAR with scripts/build.ps1 before building this image.
ARG JAVA_IMAGE=public.ecr.aws/docker/library/eclipse-temurin:21-jre
FROM ${JAVA_IMAGE}
WORKDIR /app
COPY target/smart-expiry-server-0.4.0-local.jar /app/server.jar
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/server.jar"]

FROM golang:alpine AS build-go

WORKDIR /setup/
COPY /go.mod /
COPY /go.sum /

RUN go build github.com/go-task/task/v3/cmd/task
RUN CGO_ENABLED=0 go build -ldflags='-s -w -X main.version=embedded' github.com/Jigsaw-Code/outline-ss-server/cmd/outline-ss-server

FROM node:18.18.0-alpine3.18 AS build-node

COPY --from=build-go /setup/task /usr/local/bin/

WORKDIR /setup/
COPY . /

RUN npm install
RUN task shadowbox:build TARGET_DIR=/setup/build/
COPY --from=build-go /setup/outline-ss-server /build/bin/

# https://github.com/Jigsaw-Code/outline-server/blob/master/src/shadowbox/Taskfile.yml#L64
FROM node:18.18.0-alpine3.18 AS deploy

ENV SB_STATE_DIR=/shadowbox/state
ENV SB_API_PREFIX=api
ENV SB_CERTIFICATE_FILE=/shadowbox/state/shadowbox-selfsigned.crt
ENV SB_PRIVATE_KEY_FILE=/shadowbox/state/shadowbox-selfsigned.key
VOLUME ["${SB_STATE_DIR}"]

# Default API port
EXPOSE 8081
# Access key port (tf is access key)
EXPOSE 9999
EXPOSE 9999/udp
# Prometheus & related metric services port
EXPOSE 9090 9091 9092

STOPSIGNAL SIGKILL

RUN apk add --no-cache --upgrade coreutils curl openssl bash

RUN mkdir /shadowbox/
RUN mkdir /shadowbox/app/
RUN mkdir /shadowbox/bin/
RUN mkdir -p ${SB_STATE_DIR}
RUN chmod u+s,ug+rwx,o-rwx /shadowbox/

RUN mkdir -p /etc/periodic/weekly/
COPY /src/shadowbox/scripts/update_mmdb.sh /etc/periodic/weekly/update_mmdb.sh
RUN chmod +x /etc/periodic/weekly/update_mmdb.sh
RUN /etc/periodic/weekly/update_mmdb.sh

WORKDIR /shadowbox/

COPY --from=build-node /setup/build/app/ /app/
COPY --from=build-node /setup/build/bin/ /bin/

COPY /docker-entrypoint.sh /docker-entrypoint.sh
COPY /docker-setup.sh /docker-setup.sh
RUN chmod +x /docker-entrypoint.sh
RUN chmod +x /docker-setup.sh

ENTRYPOINT /docker-entrypoint.sh

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

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN apk add --no-cache --upgrade chromium

RUN npm install
RUN task shadowbox:build TARGET_DIR=/setup/build/
COPY --from=build-go /setup/outline-ss-server /setup/build/bin/

# https://github.com/Jigsaw-Code/outline-server/blob/master/src/shadowbox/Taskfile.yml#L64
FROM node:18.18.0-alpine3.18 AS deploy

# https://github.com/puppeteer/puppeteer/issues/7740

ENV SB_STATE_DIR=/shadowbox/state
ENV SB_API_PREFIX=api
ENV SB_CERTIFICATE_FILE=/shadowbox/state/shadowbox-selfsigned.crt
ENV SB_PRIVATE_KEY_FILE=/shadowbox/state/shadowbox-selfsigned.key
VOLUME ${SB_STATE_DIR}

# Default API port
EXPOSE 8081
# Access key port
EXPOSE 8082
EXPOSE 8082/udp

STOPSIGNAL SIGKILL

RUN apk add --no-cache --upgrade coreutils curl openssl jq

RUN mkdir /shadowbox/
RUN mkdir /shadowbox/app/
RUN mkdir /shadowbox/bin/
RUN mkdir -p ${SB_STATE_DIR}

RUN mkdir -p /etc/periodic/weekly/
COPY /src/shadowbox/scripts/update_mmdb.sh /etc/periodic/weekly/update_mmdb.sh
RUN chmod +x /etc/periodic/weekly/update_mmdb.sh
RUN /etc/periodic/weekly/update_mmdb.sh

WORKDIR /shadowbox/

COPY --from=build-node /setup/build/app/ /shadowbox/app/
COPY --from=build-node /setup/build/bin/ /shadowbox/bin/

COPY /docker-entrypoint.sh /docker-entrypoint.sh
COPY /docker-setup.sh /docker-setup.sh
RUN chmod +x /docker-entrypoint.sh
RUN chmod +x /docker-setup.sh

ENTRYPOINT /docker-entrypoint.sh

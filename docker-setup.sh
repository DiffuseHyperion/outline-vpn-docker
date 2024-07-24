#!/bin/sh

PUBLIC_HOSTNAME="$(curl --silent --show-error --fail --ipv4 "https://icanhazip.com/")"

openssl req -x509 -nodes -days 36500 -newkey rsa:4096 -subj "/CN=${PUBLIC_HOSTNAME}" -keyout "${SB_PRIVATE_KEY_FILE}" -out "${SB_CERTIFICATE_FILE}" >&2

jq -n --arg hostname "${PUBLIC_HOSTNAME}" '{"portForNewAccessKeys":8082, "hostname":$hostname}' > "${SB_STATE_DIR}/shadowbox_server_config.json"
#!/bin/sh

PUBLIC_HOSTNAME="$(curl --silent --show-error --fail --ipv4 "https://icanhazip.com/")"

openssl req -x509 -nodes -days 36500 -newkey rsa:4096 -subj "/CN=${PUBLIC_HOSTNAME}" -keyout "${SB_PRIVATE_KEY_FILE}" -out "${SB_CERTIFICATE_FILE}" >&2

CERT_OPENSSL_FINGERPRINT="$(openssl x509 -in "${SB_CERTIFICATE_FILE}" -noout -sha256 -fingerprint)" || return
CERT_HEX_FINGERPRINT="$(echo "${CERT_OPENSSL_FINGERPRINT#*=}" | tr -d :)" || return

PUBLIC_API_URL="https://${PUBLIC_HOSTNAME}:${API_PORT}/${SB_API_PREFIX}"
LOCAL_API_URL="https://localhost:${API_PORT}/${SB_API_PREFIX}"

curl --silent --show-error --fail --insecure --request POST "${LOCAL_API_URL}/access-keys" >&2

jq -n --arg hostname "${PUBLIC_HOSTNAME}" '{"portForNewAccessKeys":8082, "hostname":$hostname}' > "${SB_STATE_DIR}/shadowbox_server_config.json"

jq -n --arg api_url "${PUBLIC_API_URL}" --arg fingerprint "${CERT_HEX_FINGERPRINT}" '{"apiUrl":$api_url, "certSha256":$fingerprint}' > /access.txt
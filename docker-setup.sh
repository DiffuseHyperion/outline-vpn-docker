#!/bin/bash

# TODO: Port to /bin/sh

function escape_json_string() {
  local input=$1
  for ((i = 0; i < ${input}; i++)); do
    local char="${input:i:1}"
    local escaped="${char}"
    case "${char}" in
      $'"' ) escaped="\\\"";;
      $'\\') escaped="\\\\";;
      *)
        if [[ "${char}" < $'\x20' ]]; then
          case "${char}" in 
            $'\b') escaped="\\b";;
            $'\f') escaped="\\f";;
            $'\n') escaped="\\n";;
            $'\r') escaped="\\r";;
            $'\t') escaped="\\t";;
            *) escaped=$(printf "\u%04X" "'${char}")
          esac
        fi;;
    esac
    echo -n "${escaped}"
  done
}

function set_hostname() {
  # These are URLs that return the client's apparent IP address.
  # We have more than one to try in case one starts failing
  # (e.g. https://github.com/Jigsaw-Code/outline-server/issues/776).
  local -ar urls=(
    'https://icanhazip.com/'
    'https://ipinfo.io/ip'
    'https://domains.google.com/checkip'
  )
  for url in "${urls[@]}"; do
    PUBLIC_HOSTNAME="$(curl --silent --show-error --fail --ipv4 "${url}")" && return
  done
  echo "Failed to determine the server's IP address.  Try using --hostname <server IP>." >&2
  return 1
}

set_hostname

openssl req -x509 -nodes -days 36500 -newkey rsa:4096 -subj "/CN=${PUBLIC_HOSTNAME}" -keyout "${SB_PRIVATE_KEY_FILE}" -out "${SB_CERTIFICATE_FILE}" >&2

CERT_OPENSSL_FINGERPRINT="$(openssl x509 -in "${SB_CERTIFICATE_FILE}" -noout -sha256 -fingerprint)" || return
CERT_HEX_FINGERPRINT="$(echo "${CERT_OPENSSL_FINGERPRINT#*=}" | tr -d :)" || return

PUBLIC_API_URL="https://${PUBLIC_HOSTNAME}:${API_PORT}/${SB_API_PREFIX}"

config=()
# TODO: Add FLAGS_KEY_PORT & SB_DEFAULT_SERVER_NAME
config+=("\"hostname\": \"$(escape_json_string "${PUBLIC_HOSTNAME}")\"")
echo "{$(join , "${config[@]}")}" > "${SB_STATE_DIR}/shadowbox_server_config.json"

echo -e "\033[1;32m{\"apiUrl\":\"${PUBLIC_API_URL}\",\"certSha256\":\"${CERT_HEX_FINGERPRINT}\"}\033[0m" > /access.txt
#!/bin/sh
#
# Copyright 2018 The Outline Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export SB_PUBLIC_IP="${SB_PUBLIC_IP:-$(curl --silent https://ipinfo.io/ip)}"
export SB_METRICS_URL="${SB_METRICS_URL:-https://prod.metrics.getoutline.org}"

PUBLIC_HOSTNAME="$(curl --silent --show-error --fail --ipv4 "https://icanhazip.com/")"
PUBLIC_API_URL="https://${PUBLIC_HOSTNAME}:8081/${SB_API_PREFIX}"

openssl req -x509 -nodes -days 36500 -newkey rsa:4096 -subj "/CN=${PUBLIC_HOSTNAME}" -keyout "${SB_PRIVATE_KEY_FILE}" -out "${SB_CERTIFICATE_FILE}" >&2
jq -n --arg hostname "${PUBLIC_HOSTNAME}" '{"portForNewAccessKeys":8082, "hostname":$hostname}' > "${SB_STATE_DIR}/shadowbox_server_config.json"

CERT_OPENSSL_FINGERPRINT="$(openssl x509 -in "${SB_CERTIFICATE_FILE}" -noout -sha256 -fingerprint)" || return
CERT_HEX_FINGERPRINT="$(echo "${CERT_OPENSSL_FINGERPRINT#*=}" | tr -d :)" || return
jq -n --arg api_url "${PUBLIC_API_URL}" --arg fingerprint "${CERT_HEX_FINGERPRINT}" '{"apiUrl":$api_url, "certSha256":$fingerprint}' > /access.txt

# Make sure we don't leak readable files to other users.
umask 0007

# Start cron, which is used to check for updates to the IP-to-country database
crond

node app/main.js
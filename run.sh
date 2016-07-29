#!/bin/sh

set -ex

# Import any extra environment we might need
if [[ -f /dit4c/env.sh ]]; then
  set -a
  source /dit4c/env.sh
  set +a
fi

if [[ "$NGROK_PROTOCOL" == "" ]]; then
  echo "Must specify NGROK_PROTOCOL to use (http,https,tcp)"
  exit 1
fi

if [[ "$DIT4C_INSTANCE_HELPER_AUTH_HOST" == "" ]]; then
  echo "Must specify DIT4C_INSTANCE_HELPER_AUTH_HOST to expose"
  exit 1
fi

if [[ "$DIT4C_INSTANCE_HELPER_AUTH_PORT" == "" ]]; then
  echo "Must specify DIT4C_INSTANCE_HELPER_AUTH_PORT to expose"
  exit 1
fi

if [[ ! -f "$DIT4C_INSTANCE_PRIVATE_KEY" ]]; then
  echo "Unable to find DIT4C_INSTANCE_PRIVATE_KEY: $DIT4C_INSTANCE_PRIVATE_KEY"
  exit 1
fi

if [[ "$DIT4C_INSTANCE_JWT_ISS" == "" ]]; then
  echo "Must specify DIT4C_INSTANCE_JWT_ISS for JWT auth token"
  exit 1
fi

if [[ "$DIT4C_INSTANCE_JWT_KID" == "" ]]; then
  echo "Must specify DIT4C_INSTANCE_JWT_KID for JWT auth token"
  exit 1
fi

if [[ "$DIT4C_INSTANCE_URI_UPDATE_URL" == "" ]]; then
  echo "Must specify DIT4C_INSTANCE_URI_UPDATE_URL"
  exit 1
fi

PORTAL_DOMAIN=$(echo $DIT4C_INSTANCE_URI_UPDATE_URL | awk -F/ '{print $3}')
NGROK_SERVER=$(dig +short TXT $PORTAL_DOMAIN | grep -Eo "dit4c-router=[^\"]*" | cut -d= -f2 | xargs /opt/bin/sort_by_latency.sh | head)

cat > /tmp/.ngrok <<CONFIG
server_addr: $NGROK_SERVER
trust_host_root_certs: true
CONFIG

ngrok -log=stdout -proto=$NGROK \
    $DIT4C_INSTANCE_HELPER_AUTH_HOST:$DIT4C_INSTANCE_HELPER_AUTH_PORT 2>&1 | \
  /opt/bin/listen_for_url.sh | \
  /opt/bin/notify_portal.sh

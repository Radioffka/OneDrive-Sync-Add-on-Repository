#!/usr/bin/env bash
set -euo pipefail

OPT=/data/options.json
CONF=/data/onedrive
CFG=$CONF/config

jq_get() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

LOCAL_DIR=$(jq_get local_folder)
REMOTE_DIR=$(jq_get remote_folder)
CID=$(jq_get azure_client_id)
CSEC=$(jq_get azure_client_secret)
USE_DEVICE=$(jq_get use_device_login)

[[ -z $LOCAL_DIR ]] && { echo "[error] 'local_folder' is mandatory"; exit 1; }

mkdir -p "$CONF" "$LOCAL_DIR"

cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[[ $CID  ]] && echo 'client_id     = "'"$CID"'"'  >>"$CFG"
[[ $CSEC ]] && echo 'client_secret = "'"$CSEC"'"' >>"$CFG"

if [[ $USE_DEVICE == "true" && ! -f "$CONF/refresh_token" ]]; then
    echo "[info] Device-code login – otevři https://microsoft.com/devicelogin a zadej kód, který se objeví níže:"
    onedrive --confdir "$CONF" --signin --synchronize --dry-run || true
fi

ARGS=( --confdir "$CONF" --monitor )
[[ $REMOTE_DIR ]] && ARGS+=( --single-directory "$REMOTE_DIR" )

echo "[info] Config  : $CONF"
echo "[info] Local   : $LOCAL_DIR"
echo "[info] Remote  : ${REMOTE_DIR:-<whole account>}"
echo "[info] Starting onedrive …"
exec onedrive "${ARGS[@]}"


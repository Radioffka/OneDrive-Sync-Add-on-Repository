#!/usr/bin/env bash
# Home-Assistant add-on – OneDrive Sync (v0.3.6)
set -euo pipefail

OPT=/data/options.json
CONF=/data/onedrive
CFG=$CONF/config
HASHF=$CONF/config.hash

# helper pro čtení
jq_get() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

LOCAL_DIR=$(jq_get local_folder)
REMOTE_DIR=$(jq_get remote_folder)
APP_ID=$(jq_get application_id)
TENANT_ID=$(jq_get azure_tenant_id)
AUTHRESP=$(jq_get onedrive_authresponse)

# nové volby
MONITOR_INTERVAL=$(jq_get monitor_interval)
FULLSCAN_FREQ=$(jq_get monitor_fullscan_frequency)

# povinné
if [ -z "$LOCAL_DIR" ]; then
  echo "[error] 'local_folder' is required"
  exit 1
fi

# příprava složek
mkdir -p "$CONF" "$LOCAL_DIR"

# vygeneruj config.ini
cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[ -n "$APP_ID" ]    && echo "application_id    = \"$APP_ID\""    >>"$CFG"
[ -n "$TENANT_ID" ] && echo "azure_tenant_id   = \"$TENANT_ID\"" >>"$CFG"

# autorizace jednorázově, pokud chybí refresh_token
if [ -n "$AUTHRESP" ] && [ ! -f "$CONF/refresh_token" ]; then
  echo "[info] Performing OAuth via onedrive_authresponse"
  AUTH_ARGS=(--confdir "$CONF" --auth-response "$AUTHRESP" --sync)
  [ -n "$REMOTE_DIR" ] && AUTH_ARGS+=(--single-directory "$REMOTE_DIR")
  onedrive "${AUTH_ARGS[@]}" || true
fi

# checksum konfigurace
NEW_HASH=$(md5sum "$OPT" | awk '{print $1}')
OLD_HASH=""
[ -f "$HASHF" ] && OLD_HASH=$(cat "$HASHF")

# full-resync on config change or missing DB
if [ ! -f "$CONF/drive.db" ] || [ "$NEW_HASH" != "$OLD_HASH" ]; then
  echo "[info] Config change or missing DB detected – performing full resync…"
  RESYNC_ARGS=(--confdir "$CONF" --resync --resync-auth --sync)
  [ -n "$REMOTE_DIR" ] && RESYNC_ARGS+=(--single-directory "$REMOTE_DIR")
  onedrive "${RESYNC_ARGS[@]}" || true
fi

# ulož nový hash
echo "$NEW_HASH" > "$HASHF"

# připrav monitor režim
ARGS=(--confdir "$CONF" --monitor)
[ -n "$REMOTE_DIR" ] && ARGS+=(--single-directory "$REMOTE_DIR")
# přidat volby pro interval a fullscan
[ -n "$MONITOR_INTERVAL" ] && ARGS+=(--monitor-interval "$MONITOR_INTERVAL")
[ -n "$FULLSCAN_FREQ" ]   && ARGS+=(--monitor-fullscan-frequency "$FULLSCAN_FREQ")

echo "[info] Config dir       : $CONF"
echo "[info] Local dir        : $LOCAL_DIR"
echo "[info] Remote dir       : ${REMOTE_DIR:-<whole drive>}"
echo "[info] Monitor interval : ${MONITOR_INTERVAL:-300}s"
echo "[info] Fullscan freq    : ${FULLSCAN_FREQ:-12}×"
echo "[info] Starting monitor mode…"

exec onedrive "${ARGS[@]}"

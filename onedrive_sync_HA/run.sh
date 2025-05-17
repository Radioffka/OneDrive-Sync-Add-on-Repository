#!/usr/bin/env bash
#
#  Home-Assistant add-on entry script
#  ----------------------------------
#  • Reads /data/options.json injected by HA Supervisor
#  • Regenerates a clean onedrive configuration on every start
#    (prevents legacy keys like 'single_directory' living forever)
#  • Starts the client in --monitor mode
#
#  THIS PART WORKS.  The only runtime crash we have left is the
#  OpenSSL/cURL bug visible right after onedrive starts.
#
set -euo pipefail

OPT=/data/options.json          # Supervisor-managed JSON with user options
CONF=/data/onedrive             # Persistent config dir for onedrive
CFG=$CONF/config                # onedrive configuration file

jq_get() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

LOCAL_DIR=$(jq_get local_folder)          # host folder to sync
REMOTE_DIR=$(jq_get remote_folder)        # OneDrive sub-folder
CID=$(jq_get azure_client_id)             # optional App-folder client ID
CSEC=$(jq_get azure_client_secret)        # optional App-folder secret

# Must have a local folder
[[ -z $LOCAL_DIR ]] && { echo "[error] 'local_folder' is mandatory"; exit 1; }

mkdir -p "$CONF" "$LOCAL_DIR"

# ── regenerate a clean config on every boot ────────────────────────────────
cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[[ $CID  ]] && echo 'client_id     = "'"$CID"'"'  >>"$CFG"
[[ $CSEC ]] && echo 'client_secret = "'"$CSEC"'"' >>"$CFG"

# Build CLI arguments
ARGS=( --confdir "$CONF" --monitor )
[[ $REMOTE_DIR ]] && ARGS+=( --single-directory "$REMOTE_DIR" )

echo "[info] Config  : $CONF"
echo "[info] Local   : $LOCAL_DIR"
echo "[info] Remote  : ${REMOTE_DIR:-<whole account>}"
echo "[info] Starting onedrive … (crash currently happens here!)"

exec onedrive "${ARGS[@]}"


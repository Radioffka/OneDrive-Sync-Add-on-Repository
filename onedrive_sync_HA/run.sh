#!/usr/bin/env bash
#
# Home-Assistant add-on – OneDrive Sync
# -------------------------------------
# • načte /data/options.json (Supervisor)
# • vygeneruje čistý config při každém startu
# • pokud je zapnutý `use_device_login` a ještě není refresh_token,
#   spustí device-code flow (onedrive --login)
# • jinak (nebo po úspěšném loginu) spustí klienta v --monitor režimu
#
set -euo pipefail

OPT=/data/options.json
CONF=/data/onedrive
CFG=$CONF/config

jq_get() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

# ---------- volby z GUI ----------
LOCAL_DIR=$(jq_get local_folder)
REMOTE_DIR=$(jq_get remote_folder)
CID=$(jq_get azure_client_id)
CSEC=$(jq_get azure_client_secret)
USE_DEVICE=$(jq_get use_device_login)   # "true" / "false"

[[ -z $LOCAL_DIR ]] && { echo "[error] 'local_folder' is mandatory"; exit 1; }

mkdir -p "$CONF" "$LOCAL_DIR"

# ---------- čistý config ----------
cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[[ $CID  ]] && echo 'client_id     = "'"$CID"'"'  >>"$CFG"
[[ $CSEC ]] && echo 'client_secret = "'"$CSEC"'"' >>"$CFG"

# ---------- device-code přihlášení (jednorázové) ----------
if [[ $USE_DEVICE == "true" && ! -f "$CONF/refresh_token" ]]; then
    echo "[info] Device-code login – otevři https://microsoft.com/devicelogin a zadej kód, který se objeví níže:"
    onedrive --confdir "$CONF" --login --synchronize --dry-run || true
fi

# ---------- spuštění monitoru ----------
ARGS=( --confdir "$CONF" --monitor )
[[ $REMOTE_DIR ]] && ARGS+=( --single-directory "$REMOTE_DIR" )

echo "[info] Config  : $CONF"
echo "[info] Local   : $LOCAL_DIR"
echo "[info] Remote  : ${REMOTE_DIR:-<whole account>}"
echo "[info] Starting onedrive …"

exec onedrive "${ARGS[@]}"

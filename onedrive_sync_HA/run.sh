#!/usr/bin/env bash
#
# Home-Assistant add-on – OneDrive Sync
# -------------------------------------
# • Čte /data/options.json (injektuje Supervisor)
# • Při každém startu regeneruje čistý onedrive config
# • Pokud v options existuje onedrive_authresponse a ještě není refresh_token,
#   provede neinteraktivní přihlášení a tokeny uloží.
# • Nakonec spustí klienta v --monitor režimu.
#
set -euo pipefail

OPT=/data/options.json          # JSON s volbami add-onu
CONF=/data/onedrive             # Persistentní adresář onedrive
CFG=$CONF/config                # onedrive configuration file

# Helper pro čtení pole z JSONu
jq_get() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

# Uživatelské volby
LOCAL_DIR=$(jq_get local_folder)          # povinné
REMOTE_DIR=$(jq_get remote_folder)        # volitelné
CID=$(jq_get azure_client_id)             # volitelné
CSEC=$(jq_get azure_client_secret)        # volitelné
AUTHRESP=$(jq_get onedrive_authresponse)  # volitelné – jednorázový login

[[ -z $LOCAL_DIR ]] && { echo "[error] 'local_folder' is mandatory"; exit 1; }

mkdir -p "$CONF" "$LOCAL_DIR"

# ── Vygeneruj čistý konfig každým bootem ───────────────────────────────────
cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[[ $CID  ]] && echo 'client_id     = "'"$CID"'"'  >>"$CFG"
[[ $CSEC ]] && echo 'client_secret = "'"$CSEC"'"' >>"$CFG"

# ── Jednorázové přihlášení přes auth-response (pokud chybí refresh_token) ──
if [[ -n $AUTHRESP && ! -f "$CONF/refresh_token" ]]; then
    echo "[info] Using onedrive_authresponse from options.json"
    onedrive --confdir "$CONF" --auth-response "$AUTHRESP" --synchronize --dry-run || true
fi

# ── Spuštění klienta v monitor módu ─────────────────────────────────────────
ARGS=( --confdir "$CONF" --monitor )
[[ $REMOTE_DIR ]] && ARGS+=( --single-directory "$REMOTE_DIR" )

echo "[info] Config  : $CONF"
echo "[info] Local   : $LOCAL_DIR"
echo "[info] Remote  : ${REMOTE_DIR:-<whole account>}"
echo "[info] Starting onedrive …"

exec onedrive "${ARGS[@]}"



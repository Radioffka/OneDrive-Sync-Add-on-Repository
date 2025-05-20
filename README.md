# OneDrive Sync Home Assistant Add-on Documentation (v1.1.1)

## Overview and Purpose

The **OneDrive Sync** add-on for Home Assistant provides seamless, headless, bidirectional synchronization between a local folder on the Home Assistant host and a designated folder in your Microsoft OneDrive account. Its primary purpose is to keep files in sync in both directions – changes on the Home Assistant side are uploaded to OneDrive, and changes in the OneDrive folder are pulled down to the local folder. This is useful for backing up Home Assistant data to the cloud or accessing media/files from OneDrive on your Home Assistant instance.

**Key Features:**
- **Bidirectional sync:** Ensures the local directory and OneDrive folder mirror each other.
- **Non-interactive OAuth2 setup:** Uses a device code flow suitable for headless containers, allowing you to authorize the add-on without needing a browser in the container.
- **Selective folder sync:** Optionally sync only a specified subfolder in OneDrive.
- **Auto-resync on configuration changes:** Automatically detects changes in add-on configuration and triggers a full re-sync to apply updates.
- **Headless operation:** Runs continuously as a background service in Home Assistant Supervisor.

## Architecture and Build Process

This add-on is distributed as a local add-on, meaning it includes source code (Dockerfile and scripts) that the Home Assistant Supervisor will build into a Docker image on your device. The build uses a **multi-stage Docker build** to compile the OneDrive client from source and produce a slim runtime image:

### Builder Stage

```dockerfile
FROM debian:bookworm AS builder
ARG ONEDRIVE_REF=v2.5.5
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update  && apt-get install -y --no-install-recommends       git build-essential pkg-config ca-certificates curl       libcurl4-openssl-dev libsqlite3-dev libxml2-dev libssl-dev       zlib1g-dev ldc  && git clone --branch "$ONEDRIVE_REF" https://github.com/abraunegg/onedrive.git /src  && cd /src  && git fetch --tags  && sed -i 's/checkOpenSSLVersion();/\/\* disabled \*\//' src/main.d  && ./configure  && make -j"$(nproc)"
```

- Installs Git, compilers (GCC, LDC), and development libraries.
- Clones the OneDrive client repository at the specified version tag.
- Fetches all tags to avoid shallow clone issues.
- Patches out the OpenSSL version check to prevent crashes.
- Compiles the client to produce the `onedrive` binary.

### Runtime Stage

```dockerfile
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update  && apt-get install -y --no-install-recommends       bash ca-certificates       libcurl4 libsqlite3-0 libxml2 libssl3 libphobos2-ldc-shared100       jq openssl  && update-ca-certificates  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/onedrive /usr/local/bin/onedrive
COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]
```

- Installs only runtime dependencies (shell, certificates, libraries).
- Copies the compiled OneDrive binary and the entrypoint script.
- Sets the script as the container’s entrypoint.

## Configuration Options

Configure the add-on via the Supervisor UI (**Configuration** tab). The following options are available in `config.yaml`:

| Option                      | Type    | Required | Default               | Description                                                                                       |
|-----------------------------|---------|:--------:|-----------------------|---------------------------------------------------------------------------------------------------|
| `local_folder`              | string  | Yes      | `/media/onedrive/`    | Host path to sync (must be writable; will be created if missing).                                 |
| `remote_folder`             | string  | No       | `HomeAssistant`       | OneDrive subfolder name under root. Empty syncs the entire drive.                                 |
| `application_id`            | string  | No       | `""`                  | Azure AD Application (Client) ID. Uses default if empty; set for business/multi-tenant scenarios. |
| `azure_tenant_id`           | string  | No       | `common`              | Azure AD Tenant: `common`, `organizations`, or specific GUID.                                     |
| `onedrive_authresponse`     | string  | No       | `""`                  | OAuth2 redirect URL containing `?code=…` for initial auth. Paste once and restart.                 |
| `monitor_interval`          | integer | No       | `300`                 | Seconds between incremental sync checks (default 5 minutes).                                       |
| `monitor_fullscan_frequency`| integer | No       | `12`                  | Number of intervals before a full scan (default every 12× `monitor_interval`, i.e., hourly).     |

### Add-on Manifest (`config.yaml`)

```yaml
name: OneDrive Sync
slug: onedrive_sync
version: "1.1.1"
description: Mirror a local folder ↔ a OneDrive folder using abraunegg/onedrive v2.5.5
url: https://github.com/your-repo/addons/local/onedrive_sync

arch:
  - amd64
  - aarch64
  - armv7

startup: services
boot: auto

map:
  - media:rw

options:
  local_folder: "/media/onedrive/"
  remote_folder: "HomeAssistant"
  application_id: ""
  azure_tenant_id: "common"
  onedrive_authresponse: ""
  monitor_interval: 300
  monitor_fullscan_frequency: 12

schema:
  local_folder: str
  remote_folder: str?
  application_id: str?
  azure_tenant_id: str?
  onedrive_authresponse: str?
  monitor_interval: int?
  monitor_fullscan_frequency: int?
```

## Runtime Behavior

### Initial Authentication Flow
1. **First start:** If no `refresh_token` exists, the script logs an OAuth URL.
2. **Authorize:** Copy the URL into a browser, log in, grant consent, and obtain the redirect URL with `?code=…`.
3. **Configure:** Paste this full URL into `onedrive_authresponse` in the UI and restart the add-on.
4. **One-time sync:** The script runs `onedrive --auth-response … --sync`, exchanges tokens, and performs the initial sync.

> **Tip:** After successful auth, clear `onedrive_authresponse`.

### Normal Sync Operation
- The script calculates an MD5 hash of `options.json` and compares it to the previous run.
- If `drive.db` is missing or the hash changed, it executes:
  ```bash
  onedrive --confdir /data/onedrive --resync --resync-auth --sync
  [--single-directory "$REMOTE_FOLDER"]
  ```
- The new hash is saved to `/data/onedrive/config.hash`.
- The script then starts monitor mode:
  ```bash
  onedrive --confdir /data/onedrive --monitor     [--single-directory "$REMOTE_FOLDER"]     [--monitor-interval $MONITOR_INTERVAL]     [--monitor-fullscan-frequency $FULLSCAN_FREQ]
  ```

### Entry Script (`run.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

OPT=/data/options.json
CONF=/data/onedrive
CFG=$CONF/config
HASHF=$CONF/config.hash

jq_get(){ jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

LOCAL_DIR=$(jq_get local_folder)
REMOTE_DIR=$(jq_get remote_folder)
APP_ID=$(jq_get application_id)
TENANT_ID=$(jq_get azure_tenant_id)
AUTHRESP=$(jq_get onedrive_authresponse)
MONITOR_INTERVAL=$(jq_get monitor_interval)
FULLSCAN_FREQ=$(jq_get monitor_fullscan_frequency)

[ -z "$LOCAL_DIR" ] && { echo "[error] 'local_folder' is required"; exit 1; }

mkdir -p "$CONF" "$LOCAL_DIR"

# Write OneDrive client config
cat >"$CFG" <<EOF
sync_dir = "$LOCAL_DIR"
EOF
[ -n "$APP_ID"   ] && echo "application_id = "$APP_ID"" >>"$CFG"
[ -n "$TENANT_ID"] && echo "azure_tenant_id  = "$TENANT_ID"" >>"$CFG"

# Perform initial OAuth if needed
if [ -n "$AUTHRESP" ] && [ ! -f "$CONF/refresh_token" ]; then
  echo "[info] Performing OAuth via onedrive_authresponse"
  AUTH_ARGS=(--confdir "$CONF" --auth-response "$AUTHRESP" --sync)
  [ -n "$REMOTE_DIR" ] && AUTH_ARGS+=(--single-directory "$REMOTE_DIR")
  onedrive "${AUTH_ARGS[@]}" || true
fi

# Detect config changes
NEW_HASH=$(md5sum "$OPT" | awk '{print $1}')
OLD_HASH=$(cat "$HASHF" 2>/dev/null || echo "")

if [ ! -f "$CONF/drive.db" ] || [ "$NEW_HASH" != "$OLD_HASH" ]; then
  echo "[info] Config change or missing DB detected – performing full resync…"
  RESYNC_ARGS=(--confdir "$CONF" --resync --resync-auth --sync)
  [ -n "$REMOTE_DIR" ] && RESYNC_ARGS+=(--single-directory "$REMOTE_DIR")
  onedrive "${RESYNC_ARGS[@]}" || true
fi

echo "$NEW_HASH" > "$HASHF"

# Launch monitor mode
ARGS=(--confdir "$CONF" --monitor)
[ -n "$REMOTE_DIR"       ] && ARGS+=(--single-directory "$REMOTE_DIR")
[ -n "$MONITOR_INTERVAL" ] && ARGS+=(--monitor-interval "$MONITOR_INTERVAL")
[ -n "$FULLSCAN_FREQ"    ] && ARGS+=(--monitor-fullscan-frequency "$FULLSCAN_FREQ")

echo "[info] Config dir       : $CONF"
echo "[info] Local dir        : $LOCAL_DIR"
echo "[info] Remote dir       : ${REMOTE_DIR:-<whole drive>}"
echo "[info] Monitor interval : ${MONITOR_INTERVAL:-300}s"
echo "[info] Fullscan freq    : ${FULLSCAN_FREQ:-12}×"
echo "[info] Starting monitor mode…"

exec onedrive "${ARGS[@]}"
```

## Troubleshooting

- **Authentication issues:** Ensure `application_id` and `azure_tenant_id` are correct and a redirect URL is pasted correctly.
- **SSL errors:** Verify `ca-certificates` and `openssl` are installed.
- **Frequent full resyncs:** Confirm `/data` is persistent so `config.hash` survives restarts.
- **Permission problems:** Files synced to `local_folder` may be owned by root on the host.

## Changelog

- **v1.1.1** – Added `monitor_interval` & `monitor_fullscan_frequency`; improved logging.
- **v1.1.0** – First 1.x stable release, UI schema alignment.
- **v0.3.6** – Monitoring config options; script version bump.
- **v0.3.5** – Switched to `--sync`; added `--resync-auth`.
- **v0.3.4** – Auto-resync on config change.
- **v0.3.2** – Added `bash` and `ca-certificates`; automatic OAuth initiation.
- **v0.3.1** – Fixed Git clone/tag issue.
- **v0.3.0** – Initial release.

## License & Acknowledgments

- **MIT License** for this add-on.
- **Apache 2.0** for the abraunegg/onedrive client.
- Thanks to the Home Assistant and Docker communities.

## Proposed Improvements

1. **Granular config-change handling:** Trigger full resync only on critical changes.
2. **Debug mode:** Expose verbose logging via UI toggle.
3. **Modular entry script:** Refactor `run.sh` into functions or Python.
4. **Process supervision:** Auto-restart the OneDrive client on crashes.
5. **One-way/multi-folder sync:** Support backup-only modes or multiple sync pairs.
6. **UI status integration:** Expose sync status and metrics in Home Assistant UI.

###############################################################################
# Home-Assistant add-on  —  OneDrive Sync (bidirectional folder mirroring)
###############################################################################

##### 1️⃣  BUILD STAGE ########################################################
FROM debian:bookworm AS build

ARG ONEDRIVE_TAG=master
ARG DEBIAN_FRONTEND=noninteractive

# Kompilační nástroje + hlavičky
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git build-essential pkg-config ldc \
      libcurl4-openssl-dev libssl-dev libsqlite3-dev libxml2-dev \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Kompletní klon (bez --depth) kvůli git describe
RUN git clone --branch "${ONEDRIVE_TAG}" \
      https://github.com/abraunegg/onedrive.git /src
WORKDIR /src

# ---------------------------------------------------------------------------
# 🔥 PATCH: zahoď fork() v getOpenSSLVersion() a vezmi verzi přímo z libcurl
# ---------------------------------------------------------------------------
RUN sed -i '/string getOpenSSLVersion()/,/^}/c\
string getOpenSSLVersion() {\n\
    import std.conv : to;\n\
    auto info = curl_version_info(CURLVERSION_NOW);\n\
    return to!string(info.ssl_version);\n\
}' src/util.d

# Build
RUN ./configure && make -j"$(nproc)"

##### 2️⃣  RUNTIME STAGE ######################################################
FROM debian:bookworm-slim AS runtime
ARG DEBIAN_FRONTEND=noninteractive

# Pouze nutné runtime knihovny
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libcurl4 libssl3 openssl libsqlite3-0 libxml2 \
      inotify-tools ca-certificates bash jq && \
    rm -rf /var/lib/apt/lists/*

# Binárka + D-runtime
COPY --from=build /src/onedrive /usr/local/bin/onedrive
COPY --from=build /usr/lib/*/libdruntime-ldc-shared*.so.* /usr/local/lib/
COPY --from=build /usr/lib/*/libphobos2-ldc-shared*.so.*  /usr/local/lib/
RUN ldconfig

# Perzistentní složky (Supervisor mapuje /data a /media)
RUN mkdir -p /data/onedrive /media/onedrive

# Entrypoint
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /data
ENTRYPOINT ["/run.sh"]

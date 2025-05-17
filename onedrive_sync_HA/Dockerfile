###############################################################################
# Home-Assistant add-on  —  OneDrive Sync (bidirectional folder mirroring)
###############################################################################

##### 1️⃣  BUILD STAGE ########################################################
FROM debian:bookworm AS build

# Tag / branch to compile – master already contains the OpenSSL-3 fix
ARG ONEDRIVE_TAG=master
ARG DEBIAN_FRONTEND=noninteractive

# Tool-chain & headers
RUN apt-get update &&     apt-get install -y --no-install-recommends       git build-essential pkg-config ldc       libcurl4-openssl-dev libssl-dev libsqlite3-dev libxml2-dev       ca-certificates &&     rm -rf /var/lib/apt/lists/*

# Source
RUN git clone --branch "${ONEDRIVE_TAG}"       https://github.com/abraunegg/onedrive.git /src
WORKDIR /src

# Build
RUN ./configure && make -j"$(nproc)"

##### 2️⃣  RUNTIME STAGE ######################################################
FROM debian:bookworm-slim AS runtime
ARG DEBIAN_FRONTEND=noninteractive

# Runtime libs – keep libcurl4 + libssl3 and add openssl (providers)
RUN apt-get update &&     apt-get install -y --no-install-recommends       libcurl4 libssl3 openssl libsqlite3-0 libxml2       inotify-tools ca-certificates bash jq &&     rm -rf /var/lib/apt/lists/*

# Copy binary + D runtime
COPY --from=build /src/onedrive /usr/local/bin/onedrive
COPY --from=build /usr/lib/*/libdruntime-ldc-shared*.so.* /usr/local/lib/
COPY --from=build /usr/lib/*/libphobos2-ldc-shared*.so.*  /usr/local/lib/
RUN ldconfig

# Persistent dirs (Supervisor maps /data & /media)
RUN mkdir -p /data/onedrive /media/onedrive

# Entry-point
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /data
ENTRYPOINT ["/run.sh"]

# syntax=docker/dockerfile:1

######################### build stage #########################
FROM debian:bookworm AS builder
ARG ONEDRIVE_REF=v2.5.5
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git build-essential pkg-config ca-certificates curl \
      libcurl4-openssl-dev libsqlite3-dev libxml2-dev libssl-dev \
      zlib1g-dev ldc \
 && git clone --branch "$ONEDRIVE_REF" https://github.com/abraunegg/onedrive.git /src \
 && cd /src \
 && git fetch --tags \
 && sed -i 's/checkOpenSSLVersion();/\/\* checkOpenSSLVersion disabled \*\//' src/main.d \
 && ./configure \
 && make -j"$(nproc)"

######################### runtime stage #########################
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates \
      libcurl4 libsqlite3-0 libxml2 libssl3 libphobos2-ldc-shared100 jq openssl \
 && update-ca-certificates \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/onedrive /usr/local/bin/onedrive
COPY run.sh /run.sh

RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]

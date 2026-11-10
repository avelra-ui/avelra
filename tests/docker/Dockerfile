# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
COPY sdk.tar.gz /tmp/sdk.tar.gz
RUN mkdir -p /sdk \
 && tar -xzf /tmp/sdk.tar.gz -C /sdk --strip-components=1 \
 && rm /tmp/sdk.tar.gz
COPY bare.sh deb.sh /test/

FROM base AS bare
RUN chmod +x /test/bare.sh
ENTRYPOINT ["/test/bare.sh"]

FROM base AS deb
COPY avelra.deb /tmp/avelra.deb
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && cd /tmp \
 && apt-get install -y --no-install-recommends ./avelra.deb \
 && rm -rf /var/lib/apt/lists/*
RUN chmod +x /test/deb.sh
ENTRYPOINT ["/test/deb.sh"]

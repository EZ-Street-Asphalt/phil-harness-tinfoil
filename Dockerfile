# syntax=docker/dockerfile:1
#
# Generic bootstrap image for an agent harness on Tinfoil Containers.
#
# This image contains ONLY public software: the DeepSeek Harness (dsh) from
# npm, Caddy, git and an ssh client, plus bootstrap.sh. Everything that is
# PHIL's — plugins, presets, skills, the Caddy and start scripts — is fetched
# at boot from a PRIVATE repository over a read-only deploy key held in the
# Tinfoil secrets vault, so no proprietary source is in a public artifact.
# See bootstrap.sh for the variables.
FROM caddy:2 AS caddy

FROM node:22-bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git openssh-client bubblewrap ripgrep libcap2-bin \
 && rm -rf /var/lib/apt/lists/*
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
# The official image gives caddy cap_net_bind_service as a file capability.
# Tinfoil runs workloads with zero capabilities and no-new-privileges, where
# the kernel refuses to exec such a file ("Operation not permitted"); we only
# listen on an unprivileged port, so drop it.
RUN setcap -r /usr/bin/caddy && getcap /usr/bin/caddy | grep -q . && exit 1 || true

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY bootstrap.sh ./
RUN chmod +x bootstrap.sh

ENV PORT=8080 \
    DSH_PORT=4120 \
    DSH_HOME=/data
EXPOSE 8080
CMD ["/app/bootstrap.sh"]

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
 && apt-get install -y --no-install-recommends ca-certificates curl git openssh-client bubblewrap ripgrep \
 && rm -rf /var/lib/apt/lists/*
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy

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

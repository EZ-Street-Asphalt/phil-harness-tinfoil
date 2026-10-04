#!/usr/bin/env bash
#
# Fetch the harness's private pieces at boot, then hand over to them.
#
#   PHIL_SOURCE_REPO        git ssh URL of the private repo (default below)
#   PHIL_SOURCE_REF         branch, tag or commit to check out (default: staging)
#   PHIL_SOURCE_PATH        directory inside the repo holding the harness (default: apps/agent/dsh)
#   PHIL_SOURCE_SSH_KEY_B64 secret: base64 of a READ-ONLY deploy key for that repo
#
# The checked-out directory is expected to provide docker-entrypoint.sh,
# start.sh, Caddyfile(.token), phil.cordis.yml, presets/ and plugins/ — the
# same files the Railway image bakes in. Its node_modules are the public
# packages installed in this image (/app/node_modules), linked in.
#
# Note on attestation: Tinfoil measures this image and the config, not what
# is fetched here. The fetched code is PHIL's own, pulled over an authenticated
# channel pinned by PHIL_SOURCE_REF; pin a tag or commit for a fixed release.
set -euo pipefail

repo="${PHIL_SOURCE_REPO:-git@github.com:EZ-Street-Asphalt/customer-updater.git}"
ref="${PHIL_SOURCE_REF:-staging}"
subdir="${PHIL_SOURCE_PATH:-apps/agent/dsh}"
: "${PHIL_SOURCE_SSH_KEY_B64:?PHIL_SOURCE_SSH_KEY_B64 secret is required}"

mkdir -p /root/.ssh && chmod 700 /root/.ssh
printf '%s' "$PHIL_SOURCE_SSH_KEY_B64" | base64 -d > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
ssh-keyscan -t ed25519,rsa github.com >> /root/.ssh/known_hosts 2>/dev/null
export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"

work=/opt/phil
rm -rf "$work" && mkdir -p "$work"
echo "bootstrap: fetching $subdir from $repo@$ref"
git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$ref" "$repo" "$work/src" 2>&1 | tail -2 || {
  # A commit sha is not a branch: clone shallowly, then check it out.
  git clone --quiet --filter=blob:none --sparse "$repo" "$work/src"
  git -C "$work/src" checkout --quiet "$ref"
}
git -C "$work/src" sparse-checkout set "$subdir"
echo "bootstrap: at $(git -C "$work/src" rev-parse --short HEAD)"

harness="$work/src/$subdir"
[[ -x "$harness/docker-entrypoint.sh" ]] || chmod +x "$harness"/*.sh
ln -sfn /app/node_modules "$harness/node_modules"
# The key is only needed for the fetch.
shred -u /root/.ssh/id_ed25519 2>/dev/null || rm -f /root/.ssh/id_ed25519
unset PHIL_SOURCE_SSH_KEY_B64

cd "$harness"
exec ./docker-entrypoint.sh

# phil-harness-tinfoil

Tinfoil Containers configuration and a **generic bootstrap image** for PHIL's
agent harness (the DeepSeek Harness, `dsh`).

Nothing proprietary lives here. The image holds public software only — `dsh`
from npm, Caddy, git — and `bootstrap.sh`, which at boot fetches PHIL's own
plugins, presets and scripts from a private repository over a read-only deploy
key kept in Tinfoil's secrets vault, then starts them. Tinfoil requires the
config and image to be readable; this split keeps the private code private.

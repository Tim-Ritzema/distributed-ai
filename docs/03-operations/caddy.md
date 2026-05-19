# Caddy Setup

Runbook for the Caddy reverse proxy accepted in [ADR-0011](../05-decisions/0011-reverse-proxy.md).

## Ownership

`distributed-ai` owns:

- Caddyfile source: [`../../ops/caddy/Caddyfile`](../../ops/caddy/Caddyfile)
- SvelteKit health endpoint: [`../../apps/web/src/routes/_health/+server.ts`](../../apps/web/src/routes/_health/+server.ts)
- Routing contract: prod SvelteKit `127.0.0.1:3000`, dev SvelteKit `127.0.0.1:3001`, Phoenix `127.0.0.1:4000`

`local-computer-control` owns:

- Building/installing the Caddy binary on `mac-mini-2`
- Supplying `CADDY_CLOUDFLARE_API_TOKEN` to the Caddy launchd service
- Launchd plist, log path, reload/restart wiring, and firewall rules

## Cloudflare Token

Caddy needs a narrow runtime token for DNS-01 ACME. Do not use the broader `CF_API_TOKEN` from `.env` for the long-running Caddy service.

Create a Cloudflare API token with exactly:

- `Zone / Zone / Read`
- `Zone / DNS / Edit`

Scope it to:

- `Specific zone: dinkerwupp.com`

Do not grant:

- `Zone / Zone / Edit`
- `Zone / DNS Settings / Edit`
- Account-level permissions
- Other zones

For local testing only, the narrow token may live in the gitignored root `.env` as:

```bash
CF_NARROW_TOKEN=...
```

The Caddyfile expects the runtime variable name:

```bash
CADDY_CLOUDFLARE_API_TOKEN
```

Map `CF_NARROW_TOKEN` to `CADDY_CLOUDFLARE_API_TOKEN` when testing locally.

## Build Caddy With Cloudflare DNS

Vanilla `brew install caddy` is insufficient because it does not include the Cloudflare DNS provider module.

Install Go and `xcaddy`:

```bash
brew install go
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
```

Build a local Caddy binary with `caddy-dns/cloudflare`:

```bash
mkdir -p ~/.local/bin
~/go/bin/xcaddy build \
  --with github.com/caddy-dns/cloudflare \
  --output ~/.local/bin/caddy
```

Add it to your shell path:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Persist that in `~/.zshrc` if desired.

## Verify The Binary

```bash
~/.local/bin/caddy version
~/.local/bin/caddy list-modules | grep dns.providers.cloudflare
```

Expected module line:

```text
dns.providers.cloudflare
```

If that module is missing, rebuild with `xcaddy --with github.com/caddy-dns/cloudflare`.

## Format And Validate The Caddyfile

Caddy `v2.11.3` does not support `caddy fmt --check`. Use `--diff` instead:

```bash
~/.local/bin/caddy fmt --diff ops/caddy/Caddyfile
```

If formatting is already clean, the output contains only unchanged lines prefixed with spaces and no `-` / `+` diff lines.

Validate with the narrow token:

```bash
set -a
source .env
set +a

CADDY_CLOUDFLARE_API_TOKEN="$CF_NARROW_TOKEN" \
  ~/.local/bin/caddy validate --config ops/caddy/Caddyfile
```

Expected final line:

```text
Valid configuration
```

Do not use `CADDY_CLOUDFLARE_API_TOKEN=dummy` for validation. The Cloudflare module validates token shape and rejects obviously invalid strings.

## Test The Token Can Edit DNS

This creates a temporary TXT record in `dinkerwupp.com` and deletes it immediately. It does not print the token.

```bash
set -a
source .env
set +a

ZONE_JSON=$(curl --fail --silent --show-error \
  --request GET "https://api.cloudflare.com/client/v4/zones?name=dinkerwupp.com" \
  --header "Authorization: Bearer ${CF_NARROW_TOKEN}" \
  --header "Content-Type: application/json")

ZONE_ID=$(printf "%s" "$ZONE_JSON" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  const data = JSON.parse(s);
  if (!data.success || !data.result?.length) {
    console.error("Could not read dinkerwupp.com zone");
    process.exit(1);
  }
  process.stdout.write(data.result[0].id);
});
')

TEST_NAME="_opencode-caddy-test-$(date +%s).dinkerwupp.com"

DATA=$(TEST_NAME="$TEST_NAME" node -e '
process.stdout.write(JSON.stringify({
  type: "TXT",
  name: process.env.TEST_NAME,
  content: "opencode-caddy-token-test",
  ttl: 120
}));
')

CREATE_JSON=$(curl --fail --silent --show-error \
  --request POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  --header "Authorization: Bearer ${CF_NARROW_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "$DATA")

RECORD_ID=$(printf "%s" "$CREATE_JSON" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  const data = JSON.parse(s);
  if (!data.success || !data.result?.id) {
    console.error("Could not create test TXT record");
    process.exit(1);
  }
  process.stdout.write(data.result.id);
});
')

DELETE_JSON=$(curl --fail --silent --show-error \
  --request DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  --header "Authorization: Bearer ${CF_NARROW_TOKEN}" \
  --header "Content-Type: application/json")

printf "%s" "$DELETE_JSON" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  const data = JSON.parse(s);
  if (!data.success) {
    console.error("Created test TXT record but could not delete it");
    process.exit(1);
  }
  console.log("Cloudflare token can create and delete TXT records in dinkerwupp.com");
});
'
```

Expected output:

```text
Cloudflare token can create and delete TXT records in dinkerwupp.com
```

## Caddyfile Contract

The checked-in Caddyfile does this:

- `i.dinkerwupp.com` page routes proxy to SvelteKit prod at `127.0.0.1:3000`
- `dev.dinkerwupp.com` page routes proxy to SvelteKit dev at `127.0.0.1:3001`
- `/api/*` proxies to Phoenix at `127.0.0.1:4000`
- `/socket` and `/socket/*` proxy to Phoenix at `127.0.0.1:4000`
- `/health` rewrites to SvelteKit `/_health`
- Direct `/_health*` requests return `404`
- HSTS is set explicitly with `Strict-Transport-Security: max-age=31536000; includeSubDomains`

The Caddyfile is name-bound to `i.dinkerwupp.com` and `dev.dinkerwupp.com`; do not add a catch-all site block unless a later ADR changes the ingress model.

## Production Checklist

Before starting the real launchd service on `mac-mini-2`:

- Build/install Caddy with `dns.providers.cloudflare` present.
- Provision the narrow Cloudflare token outside this repo and expose it to launchd as `CADDY_CLOUDFLARE_API_TOKEN`.
- Ensure SvelteKit prod runs with `HOST=127.0.0.1 PORT=3000`.
- Ensure SvelteKit dev runs with `HOST=127.0.0.1 PORT=3001`.
- Ensure Phoenix binds `127.0.0.1:4000`.
- Validate `ops/caddy/Caddyfile` with the real runtime token.
- Configure firewall rules so only `:80` and `:443` are exposed on the LAN interface.
- Decide where Caddy request logs go; `local-computer-control` must create and permission any file log directory.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `caddy: command not found` | `~/.local/bin` is not on `PATH` | Run `~/.local/bin/caddy ...` or add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc`. |
| `unknown flag: --check` | Caddy `v2.11.3` lacks `fmt --check` | Use `caddy fmt --diff ops/caddy/Caddyfile`. |
| `module not registered: dns.providers.cloudflare` | Caddy was installed without the Cloudflare DNS module | Rebuild with `xcaddy build --with github.com/caddy-dns/cloudflare`. |
| `API token 'dummy' appears invalid` | Validation used an invalid-shaped fake token | Validate with `CF_NARROW_TOKEN` mapped to `CADDY_CLOUDFLARE_API_TOKEN`. |
| Cloudflare API returns `403` when creating TXT records | Token can read the zone but lacks DNS record edit permission | Grant `Zone / DNS / Edit` scoped to `dinkerwupp.com`. |
| Browser can hit `/_health` directly | Caddyfile catch-all is routing internal health paths | Keep `handle /_health* { respond 404 }` before the page-route catch-all. |

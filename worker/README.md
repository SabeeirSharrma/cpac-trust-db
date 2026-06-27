# cpac-trust-db API Worker

Cloudflare Worker that proxies `api.thecinderproject.qd.je/cpac-trust-db/api/*` to Supabase.

## Setup

```bash
cd worker
npm install
npx wrangler login
npx wrangler deploy
```

## DNS (desec.io)

Add a CNAME record:

```
Name: api
Type: CNAME
Value: cpac-trust-db-api.sabplay-idk.workers.dev
TTL: 3600
```

This makes the proxy available at `https://api.thecinderproject.qd.je/cpac-trust-db/api/*`.

## Endpoints

Proxied to Supabase `/rest/v1/*`:

| Proxy path | Supabase path |
|---|---|
| `/cpac-trust-db/api/meta` | `/rest/v1/meta` |
| `/cpac-trust-db/api/advisories` | `/rest/v1/advisories` |
| `/cpac-trust-db/api/snapshots` | `/rest/v1/snapshots` |
| `/cpac-trust-db/api/snapshots/<pkg>` | `/rest/v1/snapshots?package=eq.<pkg>` |

## Environment Variables

Set in `wrangler.toml` or via `wrangler secret put`:

- `SUPABASE_URL` — `https://qzhhsyucnlswmsvpssdh.supabase.co`
- `SUPABASE_ANON_KEY` — anon key from Supabase dashboard

## Local Development

```bash
npx wrangler dev
```

Worker runs at `http://localhost:8787/cpac-trust-db/api/...`

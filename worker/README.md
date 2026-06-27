# cpac-trust-db API Worker

Cloudflare Worker that proxies `thecinderproject.qd.je/cpac-trust-db/api/*` to Supabase.

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
Name: thecinderproject.qd.je
Type: CNAME
Value: cpac-trust-db-api.<your-subdomain>.workers.dev
TTL: 300
```

## Endpoints

After deploy, the worker is available at:

```
https://cpac-trust-db-api.<your-subdomain>.workers.dev/cpac-trust-db/api/*
```

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

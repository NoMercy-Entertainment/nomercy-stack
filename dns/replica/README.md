# ns2: home replica of the srv.nomercy.tv name server

ns1 (the droplet) is the primary. ns2 is a read-only copy that answers the same names.
If ns1 dies, ns2 keeps every `*.srv.nomercy.tv` name alive.

## What runs where

| Where | What |
|-------|------|
| ns1 (droplet) | CoreDNS, `txt-updater` with `GET /zone` (new), `/txt` (unchanged) |
| ns2 (LXC docker host) | `coredns-replica`, `zone-sync`, `zone-tunnel` |

- `zone-tunnel` opens an SSH tunnel to ns1: local `:8081` forwards to ns1 `127.0.0.1:8081`.
- `zone-sync` fetches `GET /zone` through the tunnel every 3 s with the bearer token.
  It replaces `zones/dynamic.db` only when the download is non-empty, contains `SOA` and differs.
  CoreDNS reloads the file every 5 s. A new ACME token is on ns2 within about 8 s worst case.
- The synthesis rules (A, AAAA, NODATA) are in the Corefile and need no sync.
- `Corefile` here equals `../Corefile` except for the second apex NS line (`ns2.nomercy.tv.`).
  The SOA stays `ns1.nomercy.tv.` because an SOA names one primary.

## Deploy to the home host

1. Copy `dns/replica/` to the host, for example `/opt/nomercy-dns-replica`.
2. `cp .env.example .env` and fill in `DNS_BIND_IP`, `TXT_UPDATER_TOKEN` (same value as ns1), `TUNNEL_HOST`.
3. Create `secrets/tunnel_key` (ed25519 private key, mode 600) and `secrets/known_hosts` (`ssh-keyscan` of ns1, checked by eye).
4. On ns1, add the public key to the tunnel account's `authorized_keys` (below).
5. `docker compose -f replica-compose.yml up -d`.
6. From another machine: `bash dns/replica/test-replica.sh <ns1-ip> <ns2-ip>`.

`.env`, `secrets/` and `zones/` are gitignored. Only `.env.example` is committed.

## Restrict the tunnel key (on the droplet)

One line in `authorized_keys` of the tunnel account. The key can open one forward and nothing else:

```
restrict,port-forwarding,permitopen="127.0.0.1:8081",command="/bin/false" ssh-ed25519 AAAA... ns2-zone-tunnel
```

Use a dedicated unprivileged account for it, not root.

## Test

- `bash dns/replica/test-replica.sh --local` builds a throw-away upstream, a reference CoreDNS and the replica,
  compares A, AAAA, NODATA, SOA and NS answers, and plants a TXT through `POST /txt`.
- `bash dns/replica/test-replica.sh REF_IP REPLICA_IP` compares two running servers
  (set `PLANT_URL` and `PLANT_TOKEN` to add the planted TXT check).

## Not done here

- ns1's own Corefile still lists only ns1. Change it after ns2 is proven.
- The NS records at the registrar / Cloudflare and the glue for `ns2.nomercy.tv` are separate steps.

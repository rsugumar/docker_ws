FROM caddy:2.9.1-builder as builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddy-dns/duckdns

FROM caddy:2.9.1

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

FROM caddy:2-builder AS builder

ARG CADDY_DNS_PLUGIN=

RUN if [ -n "$CADDY_DNS_PLUGIN" ]; then \
    xcaddy build --with "$CADDY_DNS_PLUGIN"; \
  else \
    xcaddy build; \
  fi

FROM caddy:2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
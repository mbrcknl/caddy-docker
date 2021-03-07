# Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
# SPDX-License-Identifier: Apache-2.0

FROM golang:alpine AS caddy_builder

RUN apk update \
    && apk upgrade \
    && apk add ca-certificates git

RUN go get github.com/caddyserver/xcaddy/cmd/xcaddy

RUN xcaddy build \
    --output /go/bin/caddy \
    --with github.com/mbrcknl/caddy_yaml_adapter \
    --with github.com/mbrcknl/caddy_dns_cloudflare

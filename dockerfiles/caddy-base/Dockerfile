# Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
# SPDX-License-Identifier: Apache-2.0

FROM alpine

RUN mkdir -p /config/caddy /data/caddy \
    && apk upgrade --no-cache \
    && apk add --no-cache ca-certificates mailcap

# Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
# SPDX-License-Identifier: Apache-2.0

FROM golang:alpine AS caddy_builder

COPY main.go /caddy/

RUN apk update && apk upgrade && apk add ca-certificates git

ENV CGO_ENABLED=0

RUN cd /caddy \
    && go mod init main \
    && go mod edit -replace github.com/caddyserver/caddy/v2@v2.3.0=github.com/mbrcknl/caddy/v2@mbrcknl-2.3.0

RUN cd /caddy && go mod tidy
RUN cd /caddy && go get -u ./...
RUN cd /caddy && go build -o /caddy/caddy -ldflags "-w -s" -trimpath

FROM scratch

COPY --from=caddy_builder /caddy/caddy /caddy/go.mod /caddy/go.sum /caddy/

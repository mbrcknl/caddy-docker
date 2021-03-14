// Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
// SPDX-License-Identifier: Apache-2.0

package main

import (
    caddycmd "github.com/caddyserver/caddy/v2/cmd"
    _ "github.com/caddyserver/caddy/v2/modules/standard"
    _ "github.com/mbrcknl/caddy_yaml_adapter"
    _ "github.com/mbrcknl/caddy_dns_cloudflare"
)

func main() {
    caddycmd.Main()
}

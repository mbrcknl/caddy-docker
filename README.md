<!--
  Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
  SPDX-License-Identifier: Apache-2.0
-->

# Caddy Docker image

This is a custom Docker image build of [Caddy](https://caddyserver.com).

For the official images, see [Caddy on Docker Hub](https://hub.docker.com/_/caddy).

Some differences between these and the official images:
- This build is intened for my own use, and might change at any time. It
  currently includes some extra Caddy modules.
- I'm playing fast and loose with versions, always trying to build with the
  latest everything. This suits me for now, but I might change my mind if it
  comes back to bite me.

There are two related images:
- [`caddy-base`](https://github.com/users/mbrcknl/packages/container/package/caddy-base)
  is just Alpine Linux with some extra packages. Maintaining this as a separate
  image allows us to avoid some image rebuilds.
- [`caddy`](https://github.com/users/mbrcknl/packages/container/package/caddy)
  builds on `caddy-base`, and adds the `caddy` executable.

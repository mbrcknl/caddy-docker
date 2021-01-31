# Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
# SPDX-License-Identifier: Apache-2.0

FROM ghcr.io/mbrcknl/caddy-base

COPY caddy /bin/caddy

ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

VOLUME /config/caddy
VOLUME /data/caddy

EXPOSE 80
EXPOSE 443
EXPOSE 2019

WORKDIR /srv

CMD ["/bin/caddy", "run", "--config", "/config/caddy/caddy.yaml", "--adapter", "yaml"]

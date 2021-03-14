#!/bin/bash

# Copyright 2021 Matthew Brecknell <matthew@brecknell.net>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

registry=ghcr.io/mbrcknl

export DOCKER_BUILDKIT=1

create_date=$(date -u "+%FT%TZ")
current_revision=$(git rev-parse --verify HEAD)

force_build_base=false
force_build_caddy=false
first_build_base=false
first_build_caddy=false
rebuild_base=false
rebuild_apk=false
rebuild_caddy=false
rebuild_exe=false

trace() {
  echo "build.sh: $*"
}

if [ "$GITHUB_EVENT_NAME" = "workflow_dispatch" ]; then
  case "$INPUT_FORCE_BUILD_IMAGE" in
  "caddy")
    trace "will force-build caddy"
    force_build_caddy=true
    ;;
  "caddy-base")
    trace "will force-build caddy-base"
    force_build_base=true
    ;;
  "")
    ;;
  *)
    trace "force-build-image bad input: $INPUT_FORCE_BUILD_IMAGE"
    exit 1
  esac
fi

trace "pulling base images"

get_alpine_version() {
  local image="$1"
  docker run --rm -i "$image" sh -c 'source /etc/os-release && echo $VERSION_ID'
}

docker pull --quiet alpine
alpine_version="$(get_alpine_version alpine)"
trace "Alpine Linux version $alpine_version"

if ! $force_build_base; then
  if docker pull --quiet $registry/caddy-base; then
    old_alpine_version="$(get_alpine_version $registry/caddy-base)"
  else
    trace "$registry/caddy-base not found"
    first_build_base=true
  fi

  # Does the base Alpine image need updating?

  layers() {
    local image="$1"
    docker image inspect "$image" | jq -r '.[0].RootFS.Layers[]' | sort
  }

  fresh_base_layers() {
    local base_image derived_image base_layers derived_layers
    base_image="$1"
    derived_image="$2"
    # Fetch layers for the two images.
    # We don't inline these into the test below, because we want to see errors.
    base_layers="$(layers "$base_image")"
    derived_layers="$(layers "$derived_image")"
    # Are there any layers in the base image that are not in the derived image?
    [ -n "$(comm -23 <(echo "$base_layers") <(echo "$derived_layers"))" ]
  }

  test_apk_updates() {
    trace "testing whether $registry/caddy-base needs apk updates"
    docker run --rm -i $registry/caddy-base /bin/sh -c \
      'apk update \
       && (apk list --installed | sort > /tmp/1) \
       && apk upgrade \
       && (apk list --installed | sort > /tmp/2) \
       && diff -U 0 -L "old/packages" /tmp/1 -L "new/packages" /tmp/2'
  }

  if ! $first_build_base; then
    trace "testing whether there is a new alpine image"
    if fresh_base_layers alpine $registry/caddy-base; then
      trace "there is a new alpine image (old=$old_alpine_version, new=$alpine_version)"
      rebuild_base=true
    elif ! test_apk_updates; then
      trace "there is not a new alpine image, but there are apk updates"
      rebuild_apk=true
    fi
  fi
fi

build_base() {
  $force_build_base || $first_build_base || $rebuild_base || $rebuild_apk
}

if build_base; then
  trace "building and pushing $registry/caddy-base"
  docker build --no-cache --tag $registry/caddy-base \
    --label org.opencontainers.image.created="$create_date" \
    --label org.opencontainers.image.source=https://github.com/mbrcknl/caddy-docker \
    --label org.opencontainers.image.revision="$current_revision" \
    --label org.opencontainers.image.description="Alpine Linux with extra packages for use by the Caddy webserver" \
    --label org.brecknell.github.actions.run.id="$GITHUB_RUN_ID" \
    --label org.brecknell.github.actions.run.number="$GITHUB_RUN_NUMBER" \
    --label org.brecknell.version.alpine="$alpine_version" \
    dockerfiles/caddy-base
  docker push $registry/caddy-base
fi

# Does the caddy executable need updating?

trace "unconditionally building a new caddy executable"

get_caddy_golang_version() {
  local caddy_exe
  caddy_exe="$1"
  if ! (docker run --rm -i -v "$PWD/$caddy_exe":/caddy golang:alpine go version /caddy | awk '{print $2}'); then
    echo unknown
  fi
}

get_caddy_version() {
  local caddy_img
  caddy_img="$1"
  if ! (docker run --rm -i "$registry/$caddy_img" /caddy/caddy version | awk '{print $1}'); then
    echo unknown
  fi
}

docker build --no-cache --pull --tag $registry/caddy-exe dockerfiles/caddy-exe
new_caddy_exe_container_id=$(docker create $registry/caddy-exe /caddy/caddy)
docker cp $new_caddy_exe_container_id:/caddy dockerfiles/caddy/caddy
docker rm $new_caddy_exe_container_id
golang_version="$(get_caddy_golang_version dockerfiles/caddy/caddy/caddy)"
caddy_version="$(get_caddy_version caddy-exe)"

if ! build_base && ! $force_build_caddy; then
  trace "pulling $registry/caddy to compare caddy executables"
  if ! docker pull --quiet $registry/caddy; then
    trace "$registry/caddy not found"
    first_build_caddy=true
  elif fresh_base_layers $registry/caddy-base $registry/caddy; then
    trace "$registry/caddy is older than $registry/caddy-base"
    rebuild_caddy=true
  else
    trace "comparing old and new caddy executables"
    old_caddy_exe_container_id=$(docker create $registry/caddy)
    old_caddy_exe=caddy-$old_caddy_exe_container_id
    docker cp $old_caddy_exe_container_id:/caddy $old_caddy_exe
    docker rm $old_caddy_exe_container_id
    old_golang_version="$(get_caddy_golang_version $old_caddy_exe)"
    old_caddy_version="$(get_caddy_version caddy)"
    if ! cmp $old_caddy_exe/caddy dockerfiles/caddy/caddy/caddy; then
      trace "old and new caddy executables differ"
      trace "Go: $old_golang_version -> $golang_version"
      trace "Caddy: $old_caddy_version -> $caddy_version"
      for file in go.mod go.sum; do
        diff -U 0 -L old/$file $old_caddy_exe/$file -L new/$file dockerfiles/caddy/caddy/$file || true
      done
      rebuild_exe=true
    fi
    rm -rf $old_caddy_exe
  fi
fi

build_caddy() {
  build_base || $force_build_caddy || $first_build_caddy || $rebuild_caddy || $rebuild_exe
}

# If needed, (re)build and push the final caddy image.

show_versions() {
  echo "Versions:"
  echo "  Alpine Linux: $alpine_version"
  echo "  Go: $golang_version"
  echo "  Caddy: $caddy_version"
}

if build_caddy; then
  trace "building and pushing $registry/caddy"
  docker build --tag $registry/caddy \
    --label org.opencontainers.image.created="$create_date" \
    --label org.opencontainers.image.source=https://github.com/mbrcknl/caddy-docker \
    --label org.opencontainers.image.revision="$current_revision" \
    --label org.opencontainers.image.description="A custom build of the Caddy webserver" \
    --label org.brecknell.github.actions.run.id="$GITHUB_RUN_ID" \
    --label org.brecknell.github.actions.run.number="$GITHUB_RUN_NUMBER" \
    --label org.brecknell.version.alpine="$alpine_version" \
    --label org.brecknell.version.golang="$golang_version" \
    --label org.brecknell.version.caddy="$caddy_version" \
    dockerfiles/caddy
  docker push $registry/caddy

  show_versions
  echo "The caddy image was (re)built because:"
  if $force_build_base; then echo "- A caddy-base build was explicitly requested"; fi
  if $force_build_caddy; then echo "- A caddy build was explicitly requested"; fi
  if $first_build_base; then echo "- There wasn't an existing caddy-base image"; fi
  if $first_build_caddy; then echo "- There wasn't an existing caddy image"; fi
  if $rebuild_base; then echo "- Alpine Linux has a new release"; fi
  if $rebuild_apk; then echo "- Alpine Linux has package updates"; fi
  if $rebuild_caddy; then echo "- The caddy image was not up-to-date with caddy-base"; fi
  if $rebuild_exe; then echo "- The caddy executable has been updated"; fi
else
  show_versions
  echo "The caddy image was already up to date."
fi

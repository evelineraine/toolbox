#!/usr/bin/env sh

XDG_DATA_ROOT=${XDG_DATA_ROOT:-$HOME/.local/share}

containerdir=$XDG_DATA_ROOT/containers

mkdir -p $containerdir
storagedir=$(mktemp --tmpdir="$containerdir" -d "storage.XXXXXXXXXX")

podman run \
    --device /dev/fuse:rw \
    --volume $storagedir:/var/lib/containers:Z \
    --security-opt label=disable \
    --workdir /src \
    --volume .:/src:ro \
    --volume ./build:/build:rw \
    --env builddir=/build \
    quay.io/buildah/stable \
        sh -x toolbox.sh

# Required to remove overalayfs files owned by container root (or container-in-container root)
podman unshare rm -rf $storagedir

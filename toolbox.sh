#!/usr/bin/env sh

# ENV varaiables
version=${version:-"draft"}
sha=${sha:-""}
snapshot="$(date --utc +%Y%m%d%H%M%S)${sha:+git$sha}"
builddir=${builddir:-"./build"}

# Constants
NAME="evelineraine/toolbox"
NAME_DASH=${NAME//\//-}
AUTHOR="Eveline Raine <eveline@raine.ai>"

container=$(buildah from registry.fedoraproject.org/f31/fedora-toolbox)

buildah copy $container locale.conf /etc/
buildah copy $container kubernetes.repo /etc/yum.repos.d/

buildah run $container -- dnf upgrade -y
buildah run $container -- dnf install -y $(cat packages/rpm)
buildah run $container -- pip --no-cache-dir --disable-pip-version-check install $(cat packages/pip)

buildah run $container -- dnf clean all

# Activate Python argcomplete BASH completion
buildah run $container -- activate-global-python-argcomplete

# Container-specific ENV variables
# Run nested buildah without cgroup isolation (the only way to do it)
buildah config --env BUILDAH_ISOLATION=chroot $container

buildah config \
    --author "$AUTHOR" \
    --created-by "buildah" \
    --label maintainer="$AUTHOR" \
    --label version="$version" \
    --annotation org.opencontainers.image.created="$(date --utc --rfc-3339=seconds)" \
    --annotation org.opencontainers.image.authors="$AUTHOR" \
    --annotation org.opencontainers.image.url="https://github.com/evelineraine/toolbox/blob/master/README.md" \
    --annotation org.opencontainers.image.source="https://github.com/evelineraine/toolbox" \
    --annotation org.opencontainers.image.version="$version" \
    --annotation org.opencontainers.image.revision="$sha" \
    --annotation org.opencontainers.image.license="MIT" \
    --annotation org.opencontainers.image.title="Eveline Raine's Toolbox Image" \
    --annotation org.opencontainers.image.description="Official Toolbox image, plus custom software & configs installed" \
    $container

image=$(buildah commit --rm $container $NAME:$snapshot)
buildah tag $image $NAME:$version

mkdir -p $builddir
buildah push $image oci-archive:$builddir/$NAME_DASH-$snapshot.tar:$snapshot
ln -srf $builddir/$NAME_DASH-$snapshot.tar $builddir/$NAME_DASH-$version.tar

#!/usr/bin/env sh

# Constants
NAME="evelineraine/toolbox"
NAME_DASH=${NAME//\//-}
AUTHOR="Eveline Raine <eveline@raine.ai>"

# ENV varaiables
version=${version:-"draft"}
sha=${sha:-""}
snapshot="$(date --utc +%Y%m%d%H%M%S)${sha:+git$sha}"
builddir=${builddir:-"./build"}

container=$(buildah from registry.fedoraproject.org/f31/fedora-toolbox)

buildah copy $container locale.conf /etc/

# Google Cloud Kubernetes repo
# See: kubernetes.io/docs/tasks/tools/install-kubectl/#install-using-native-package-management
buildah copy $container kubernetes.repo /etc/yum.repos.d/

# Remove .absent packages first, and then exclude them when installing .present
# Ensures there is an error if one of .present packages depends on a .absent one
buildah run $container -- dnf remove -y $(cat packages/rpm.absent)
buildah run $container -- dnf install --exclude="$(cat packages/rpm.absent)" -y $(cat packages/rpm.present)
buildah run $container -- pip --no-cache-dir --disable-pip-version-check install $(cat packages/pip)

buildah run $container -- dnf clean all

# Activate Python argcomplete BASH completion
# See: docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#shell-completion
buildah run $container -- activate-global-python-argcomplete

# Container-specific ENV variables
# Run nested buildah without cgroup isolation (the only way to do it)
# See: github.com/containers/buildah/blob/master/contrib/docker/Dockerfile
buildah config --env BUILDAH_ISOLATION=chroot $container

# See: github.com/opencontainers/image-spec/blob/master/annotations.md
# See: github.com/opencontainers/image-spec/blob/master/conversion.md#annotation-fields
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

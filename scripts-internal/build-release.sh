#!/bin/bash

TAG="${TAG:-cloudfoundry-$(date +%Y%m%d)}"
PACKAGE=dist-generics-$TAG.tar.gz

DIST_DIR="${DIST_DIR:-.}"
SPEC_FILE_ORIG=$(ls $DIST_DIR/dist-spec-*.yaml)
SPEC_FILE=$(basename $SPEC_FILE_ORIG)
cp $SPEC_FILE_ORIG $SPEC_FILE

DIST_TMP=dist-tmp
rm -rf $DIST_TMP
mkdir $DIST_TMP
tar -xvzf $DIST_DIR/dist-debs-*.tar.gz -C $DIST_TMP

STAGE_DIR=dist-stage
rm -rf $STAGE_DIR
mkdir -p $STAGE_DIR/release

bosh reset-release
bash scripts-internal/add-aci-blobs.sh $DIST_TMP
export VERSION=$(git describe --tags)
bosh create-release --version $VERSION --tarball $STAGE_DIR/release/aci-containers-release-$VERSION.tar.gz --force
cp config/blobs.yml config_blobs.yml

cp -r -a scripts $STAGE_DIR/
cp -r -a manifest-generation $STAGE_DIR/
cp -a $DIST_TMP/acc-provision*.deb $STAGE_DIR/

tar -cvzf $PACKAGE -C $STAGE_DIR .
CHKSUM=$(md5sum $PACKAGE | cut -d' ' -f 1)

COMMIT=$(git rev-parse HEAD)
BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
REPO=$(git config --get remote.origin.url)
cat >> $SPEC_FILE <<EOF
---
module:
    name: aci-containers-release
    repository:
    - url: $REPO
      branch: $BRANCH
      commit: $COMMIT
    packages
    - name: $PACKAGE
      md5sum: $CHKSUM
EOF

# publish $PACKAGE, config_blobs.yml, dist-spec-*.yaml

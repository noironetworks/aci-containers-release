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
mkdir -p $STAGE_DIR/tile

# create BOSH release
bosh reset-release
bash scripts-internal/add-aci-blobs.sh $DIST_TMP
export VERSION=$(git describe --tags)-${BUILD_NUMBER:-0}
export RELEASE_FILE=aci-containers-release-$VERSION.tar.gz
export TILE_FILE=aci-containers-tile-$VERSION.pivotal
bosh create-release --version $VERSION --tarball $RELEASE_FILE --force
CHKSUM=$(md5sum $RELEASE_FILE | cut -d' ' -f 1)
cp config/blobs.yml config_blobs.yml

# Copy scripts and tools
cp -r -a scripts $STAGE_DIR/
cp -r -a manifest-generation $STAGE_DIR/
mv $RELEASE_FILE $STAGE_DIR/release/
cp -a $DIST_TMP/acc-provision*.deb $STAGE_DIR/

# create pivotal tile
mkdir -p $STAGE_DIR/metadata
mkdir -p $STAGE_DIR/migrations
sed -e "s/<aci-containers-release-file>/$RELEASE_FILE/" \
    -e "s/<aci-containers-release-version>/$VERSION/" \
    -e "s/<aci-cni-plugin-tile-version>/$VERSION/" \
    pcf-tile-metadata/aci-cni-plugin.yml.template > $STAGE_DIR/metadata/aci-cni-plugin.yml
pushd $STAGE_DIR
mv release releases
zip -r $TILE_FILE metadata/ migrations/ releases/
TILE_CHKSUM=$(md5sum $TILE_FILE | cut -d' ' -f 1)
mv $TILE_FILE tile/
mv releases release
rm -rf metadata/ migrations/
popd

# create the dist file
tar -cvzf $PACKAGE -C $STAGE_DIR .

COMMIT=$(git rev-parse HEAD)
if [ -z "$GIT_BRANCH" ]; then
   BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
else
   BRANCH=$GIT_BRANCH
fi
REPO=$(git config --get remote.origin.url)
cat >> $SPEC_FILE <<EOF
---
module:
    name: aci-containers-release
    repository:
    - url: $REPO
      branch: $BRANCH
      commit: $COMMIT
    packages:
    - name: $RELEASE_FILE
      md5sum: $CHKSUM
    - name: $TILE_FILE
      md5sum: $TILE_CHKSUM
EOF

# publish $PACKAGE, config_blobs.yml, dist-spec-*.yaml

#!/usr/bin/env bash
### every exit != 0 fails the script
set -e

if [ "${DISTRO}" == "oracle7" ]; then
  DISTRO=centos
elif [ "${DISTRO}" == "oracle8" ]; then
  DISTRO=oracle
fi

COMMIT_ID="fa0008ce9742287b87bbc2ad845f2bdf018bd250"
BRANCH="develop"
COMMIT_ID_SHORT=$(echo "${COMMIT_ID}" | cut -c1-6)

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

mkdir -p $STARTUPDIR/webcam
wget -qO- https://kasmweb-build-artifacts.s3.amazonaws.com/kasm_webcam_server/${COMMIT_ID}/kasm_webcam_server_${ARCH}_${BRANCH}.${COMMIT_ID_SHORT}.tar.gz | tar -xvz -C $STARTUPDIR/webcam/


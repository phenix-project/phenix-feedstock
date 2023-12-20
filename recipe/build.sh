#!/bin/bash
set -xe

openssl enc -d \
  -aes-256-cbc \
  -salt \
  -md sha256 \
  -iter 100000 \
  -pbkdf2 \
  -in ${SRC_DIR}/phenix.enc \
  -out phenix.tgz \
  -pass env:TARBALL_PASSWORD
rm -fr ./modules phenix.enc
tar -xf phenix.tgz
rm phenix.tgz
mv phenix*/modules .
mv phenix*/rest .

# delete pickled data
cd modules
rm -fr ./chem_data/rotarama_data/*.pickle
rm -fr ./chem_data/rotarama_data/*.dlite
rm -fr ./chem_data/cablam_data/*.pickle
rm -fr ./chem_data/cablam_data/*.dlite
cd ..
echo Check disk space
df -h

# always rename files starting with AUX and NUL to avoid issues on Windows
cd modules/chem_data/geostd/a
for f in `/bin/ls AUX.*`; do
  echo ${f}
  mv -f ${f} data_${f}
done
cd ../../../..

cd modules/chem_data/geostd/n
for f in `/bin/ls NUL.*`; do
  echo ${f}
  mv -f ${f} data_${f}
done
cd ../../../..

# move chem_data manually to avoid copy
mv ./modules/chem_data ${SP_DIR}

# clean source cache
ARTIFACT_DIR=/home/conda/feedstock_root/build_artifacts
SUBDIR=linux-64
if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
  ARTIFACT_DIR=/Users/runner/miniforge3/conda-bld/
  SUBDIR=osx-64
  if [[ "$CC" == *"arm64"* ]]; then
    SUBDIR=osx-arm64
  fi
fi
cd ${ARTIFACT_DIR}/src_cache
rm -fr *

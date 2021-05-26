#!/bin/bash
set -xe

export TARBALL="https://artprodcus3.artifacts.visualstudio.com/Aa21b64c7-c136-4a25-ab50-eb9ba3fa4296/f0ee1b2f-77b3-4fa6-a2c5-97101b71b939/_apis/artifact/cGlwZWxpbmVhcnRpZmFjdDovL3BoZW5peC1yZWxlYXNlL3Byb2plY3RJZC9mMGVlMWIyZi03N2IzLTRmYTYtYTJjNS05NzEwMWI3MWI5MzkvYnVpbGRJZC8xMDU1L2FydGlmYWN0TmFtZS9waGVuaXgtMjAyMS4wNS5hMjQ1/content?format=file&subPath=%2Fphenix-2021.05.a24.enc"

printenv

curl -L -o phenix.enc ${TARBALL}
echo ${TARBALL_PASSWORD} > ./password
cat ./password
ls
openssl enc -d -aes-256-cbc -in phenix.enc -out phenix.tgz -md sha256 -pass file:./password
ls
rm -fr ./modules
tar -xf phenix.tgz
mv phenix*/modules .

# reapply patches
git apply ${RECIPE_DIR}/crys3d.patch
cp ${RECIPE_DIR}/phaser_SConscript ./modules/phaser/SConscript
cp ${RECIPE_DIR}/bootstrap.py ./modules/cctbx_project/libtbx/auto_build/bootstrap.py

# copy autogenerated header to avoid binary compiler check on osx-arm64
# and apply patch
if [[ "$CC" == *"arm64"* ]]; then
  git apply ${RECIPE_DIR}/libtbx_osx-arm64.patch
  mkdir -p build/include/boost_adaptbx
  cp ${RECIPE_DIR}/type_id_eq.h build/include/boost_adaptbx/type_id_eq.h
  cd modules
  git clone -b cpp-3.3.0 https://github.com/msgpack/msgpack-c.git msgpack-3.1.1
  cd ..
fi

# get latest DIALS repositories
cd modules
rm -fr dials dxtbx xia2
git clone https://github.com/dials/dials.git
git clone https://github.com/dials/dxtbx.git
cd ..

# link bootstrap.py
ln -s modules/cctbx_project/libtbx/auto_build/bootstrap.py

# remove extra source code
rm -fr ./modules/boost
rm -fr ./modules/eigen
rm -fr ./modules/scons

# build
${PYTHON} bootstrap.py build --builder=phenix --use-conda ${PREFIX} --nproc 4 \
  --config-flags="--compiler=conda" --config-flags="--use_environment_flags" \
  --config-flags="--enable_cxx11" --config-flags="--no_bin_python"

# remove intermediate objects in build directory
cd build
find . -name "*.o" -type f -delete
cd ..

# fix rpath on macOS because libraries and extensions will be in different locations
if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
  echo Fixing rpath:
  ${PYTHON} ${RECIPE_DIR}/fix_macos_rpath.py
fi

# copy files in build
echo Copying build
EXTRA_CCTBX_DIR=${PREFIX}/share/cctbx
mkdir -p ${EXTRA_CCTBX_DIR}
CCTBX_CONDA_BUILD=./modules/cctbx_project/libtbx/auto_build/conda_build
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/install_build.py --preserve-egg-dir

# copy version and copyright files
${PYTHON} ./modules/cctbx_project/libtbx/version.py --version=${PKG_VERSION}
cp ./modules/cctbx_project/COPYRIGHT.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.h ${PREFIX}/include/cctbx
cd ./modules/cctbx_project
${PYTHON} setup.py install
cd ../..

# copy libtbx_env and update dispatchers
echo Copying libtbx_env
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
${PYTHON} ${CCTBX_CONDA_BUILD}/update_libtbx_env.py

# remove extra copies of dispatchers
echo Removing some duplicate dispatchers
find ${PREFIX}/bin -name "*show_dist_paths" -not -name "libtbx.show_dist_paths" -type f -delete
find ${PREFIX}/bin -name "*show_build_path" -not -name "libtbx.show_build_path" -type f -delete

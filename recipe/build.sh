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

# reapply patches
cp ${RECIPE_DIR}/phaser_SConscript ./modules/phaser/SConscript

# clean up sources
rm -fr ./modules/cctbx_project/xfel/euxfel/definitions

cp ${RECIPE_DIR}/parseHHpred.py ./modules/phaser_voyager/old_storage/scripts/parseHHpred.py
rm -fr ./modules/phaser_voyager/old_storage/VoyagerGUI-QTC/old_gui

if [[ "$CC" != *"arm64"* ]]; then
  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/phaser_regression
  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/phaser_voyager

  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/reduce
  futurize -f lib2to3.fixes.fix_except -wn ./modules/reduce

  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/tntbx
fi

# copy autogenerated header to avoid binary compiler check on osx-arm64
# and apply patch
if [[ "$CC" == *"arm64"* ]]; then
  git apply ${RECIPE_DIR}/libtbx_osx-arm64.patch
  mkdir -p build/include/boost_adaptbx
  cp ${RECIPE_DIR}/type_id_eq.h build/include/boost_adaptbx/type_id_eq.h
fi

# link bootstrap.py
ln -s modules/cctbx_project/libtbx/auto_build/bootstrap.py

# compress chem_data to save disk space
cd modules
rm -fr ./chem_data/rotarama_data/*.pickle
rm -fr ./chem_data/rotarama_data/*.dlite
rm -fr ./chem_data/cablam_data/*.pickle
rm -fr ./chem_data/cablam_data/*.dlite
cd ..
echo Check disk space
df -h

# remove extra source code
rm -fr ./modules/boost
rm -fr ./modules/eigen
rm -fr ./modules/scons
rm -fr ./modules/msgpack*

# remove some libtbx_refresh.py files
# rm -fr ./modules/dials/libtbx_refresh.py
rm -fr ./modules/dxtbx/libtbx_refresh.py
rm -fr ./modules/iota/libtbx_refresh.py
rm -fr ./modules/xia2/libtbx_refresh.py

# build
export CCTBX_SKIP_CHEMDATA_CACHE_REBUILD=1
if [[ "$CC" == *"arm64"* ]]; then
  ${PYTHON} bootstrap.py build \
    --builder=phenix_release \
    --use-conda ${PREFIX} \
    --nproc 4 \
    --verbose \
    --config-flags="--compiler=conda" \
    --config-flags="--use_environment_flags" \
    --config-flags="--no_bin_python" \
    --config-flags="--cxxstd=c++14"
else
  ${PYTHON} bootstrap.py build \
    --builder=phenix_release \
    --use-conda ${PREFIX} \
    --nproc 4 \
    --verbose \
    --config-flags="--compiler=conda" \
    --config-flags="--use_environment_flags" \
    --config-flags="--no_bin_python"
fi

# remove intermediate objects in build directory
cd build
find . -name "*.o" -type f -delete
cd ..

# remove compiled Python files
# https://stackoverflow.com/questions/28991015/python3-project-remove-pycache-folders-and-pyc-files
${PYTHON} -Bc "import pathlib; import shutil; [shutil.rmtree(p) for p in pathlib.Path('.\build').rglob('__pycache__')]"
${PYTHON} -Bc "import pathlib; import shutil; [shutil.rmtree(p) for p in pathlib.Path('.\modules').rglob('__pycache__')]"

# fix rpath on macOS because libraries and extensions will be in different locations
if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
  echo Fixing rpath:
  ${PYTHON} ${RECIPE_DIR}/fix_macos_rpath.py
fi

echo Check disk space
df -h

# move chem_data manually to avoid copy
mv ./modules/chem_data ${SP_DIR}

# copy files in build
echo Copying build
EXTRA_CCTBX_DIR=${PREFIX}/share/cctbx
mkdir -p ${EXTRA_CCTBX_DIR}
CCTBX_CONDA_BUILD=./modules/cctbx_project/libtbx/auto_build/conda_build
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/install_build.py --preserve-egg-dir

# copy version and copyright files
echo Copying version and copyright files
${PYTHON} ./modules/cctbx_project/libtbx/version.py --version=${PKG_VERSION}
cp ./modules/cctbx_project/COPYRIGHT.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.h ${PREFIX}/include/cctbx
cd ./modules/cctbx_project
${PYTHON} setup.py install
cd ../..

# copy Phenix environment files and changelog
echo Copying Phenix environment files
EXTRA_PHENIX_DIR=${PREFIX}/share/phenix
mkdir -p ${EXTRA_PHENIX_DIR}
cp -a ./modules/phenix/conda_envs ${EXTRA_PHENIX_DIR}
cp ./modules/phenix/CHANGES ${EXTRA_PHENIX_DIR}

# copy libtbx_env and update dispatchers
echo Copying libtbx_env
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
if [[ -f "${PREFIX}/python.app/Contents/MacOS/python" ]]; then
  ${PREFIX}/python.app/Contents/MacOS/python ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
else
  ${PYTHON} ${CCTBX_CONDA_BUILD}/update_libtbx_env.py
fi

# remove extra copies of dispatchers
echo Removing some duplicate dispatchers
find ${PREFIX}/bin -name "*show_dist_paths" -not -name "libtbx.show_dist_paths" -type f -delete
find ${PREFIX}/bin -name "*show_build_path" -not -name "libtbx.show_build_path" -type f -delete

# install dxtbx, dials, iota, and xia2
cd modules
# for m in dxtbx dials iota xia2; do
for m in dxtbx iota xia2; do
  rm -fr ${SP_DIR}/${m}
  cd ./${m}
  ${PYTHON} -m pip install . -vv --no-deps
  cd ..
done
cd ..

# copy dxtbx_flumpy.so separately since it does not end it *_ext.so
cp ./build/lib/dxtbx_flumpy.so ${SP_DIR}/../lib-dynload/

# clean up cbflib
echo Fix cbflib
cp ./build/lib/*cbf* ${PREFIX}/lib
for f in _pycbf.so cbflib_ext.so; do
  mv ${PREFIX}/lib/${f} ${PREFIX}/lib/python${PY_VER}/lib-dynload/${f}
done
rm -f ${PREFIX}/lib/pycbf.py
mv ${SP_DIR}/cbflib/pycbf/pycbf.py ${SP_DIR}
rm -fr ${SP_DIR}/cbflib

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

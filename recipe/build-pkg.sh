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

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/ccp4io/libccp4/build-aux
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/cbflib/libtool
cp $BUILD_PREFIX/share/gnuconfig/config.* ./modules/cbflib

# clean up sources
rm -fr ./modules/cctbx_project/xfel/euxfel/definitions

if [[ "$CC" != *"arm64"* ]]; then
  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/phaser_regression
  # futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/phaser_voyager

  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/reduce
  futurize -f lib2to3.fixes.fix_except -wn ./modules/reduce

  futurize -f libfuturize.fixes.fix_print_with_import -wn ./modules/tntbx
fi

# copy autogenerated header to avoid binary compiler check on osx-arm64
if [[ "$CC" == *"arm64"*  ]]; then
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
rm -fr ./modules/dials/libtbx_refresh.py
rm -fr ./modules/dxtbx/libtbx_refresh.py
rm -fr ./modules/iota/libtbx_refresh.py
rm -fr ./modules/xia2/libtbx_refresh.py

# set extra compilation flags
export CPPFLAGS="${CPPFLAGS} -DBOOST_TIMER_ENABLE_DEPRECATED -O3"
export CXXFLAGS="${CXXFLAGS} -DBOOST_TIMER_ENABLE_DEPRECATED -O3"
export CFLAGS="${CFLAGS} -DBOOST_TIMER_ENABLE_DEPRECATED -O3"

# build
export CCTBX_SKIP_CHEMDATA_CACHE_REBUILD=1
${PYTHON} bootstrap.py build \
  --builder=phenix \
  --use-conda ${PREFIX} \
  --nproc ${CPU_COUNT} \
  --config-flags="--compiler=conda" \
  --config-flags="--use_environment_flags" \
  --config-flags="--cxxstd=c++14" \
  --config-flags="--no_bin_python" \
  --verbose

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
# mv ./modules/chem_data ${SP_DIR}
# remove chem_data
rm -fr ./modules/chem_data

# copy files in build
echo Copying build
EXTRA_CCTBX_DIR=${PREFIX}/share/cctbx
mkdir -p ${EXTRA_CCTBX_DIR}
CCTBX_CONDA_BUILD=./modules/cctbx_project/libtbx/auto_build/conda_build
./build/bin/libtbx.python ${CCTBX_CONDA_BUILD}/install_build.py --preserve-egg-dir

# copy version and copyright files
echo Copying version and copyright files
${PYTHON} ./modules/cctbx_project/libtbx/version.py
cp ./modules/cctbx_project/COPYRIGHT.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.txt ${EXTRA_CCTBX_DIR}
cp ./modules/cctbx_project/cctbx_version.h ${PREFIX}/include/cctbx
cd ./modules/cctbx_project
${PYTHON} -m pip install . -vv
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

# copy REST credentials
echo Copying REST credentials
cp -a ./rest ${EXTRA_CCTBX_DIR}

# remove extra copies of dispatchers
echo Removing some duplicate dispatchers
find ${PREFIX}/bin -name "*show_dist_paths" -not -name "libtbx.show_dist_paths" -type f -delete
find ${PREFIX}/bin -name "*show_build_path" -not -name "libtbx.show_build_path" -type f -delete

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

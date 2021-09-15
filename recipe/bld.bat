echo on

call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl m2-gzip m2-tar openssl
call %CONDA%\condabin\conda.bat activate test

dir D:\bld\src_cache
del /S /Q D:\bld\src_cache\phenix*.tar.gz
dir

cd %SRC_DIR%
openssl enc -d ^
  -aes-256-cbc ^
  -salt ^
  -md sha256 ^
  -iter 100000 ^
  -pbkdf2 ^
  -in %SRC_DIR%\phenix.enc ^
  -out %SRC_DIR%\phenix.tar ^
  -pass env:TARBALL_PASSWORD
dir
del /S /Q %SRC_DIR%\phenix.enc
tar -xf phenix.tar
del phenix.tar
cd phenix-installer*
move .\modules ..
cd ..
dir

REM remove chem_data, phenix_examples, and phenix_regression
@REM cd .\modules
@REM rmdir /S /Q .\chem_data
@REM rmdir /S /Q .\phenix_examples
@REM rmdir /S /Q .\phenix_regression
@REM cd ..
@REM dir

REM reapply patches
git apply %RECIPE_DIR%\crys3d.patch
git apply %RECIPE_DIR%\libtbx_SConscript.patch
copy %RECIPE_DIR%\phaser_SConscript .\modules\phaser\SConscript
copy %RECIPE_DIR%\bootstrap.py .\modules\cctbx_project\libtbx\auto_build\bootstrap.py

REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons
dir

REM build
%PYTHON% bootstrap.py build --builder=phenix --use-conda %PREFIX% --nproc 4 --config-flags="--enable_cxx11" --config-flags="--no_bin_python"
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..

REM rebuild rotarama and cablam caches
del /S /Q .\modules\chem_data\rotarama_data\*.pickle
del /S /Q .\modules\chem_data\rotarama_data\*.dlite
del /S /Q .\modules\chem_data\cablam_data\*.pickle
del /S /Q .\modules\chem_data\cablam_data\*.dlite
call ./build/bin/mmtbx.rebuild_rotarama_cache
call ./build/bin/mmtbx.rebuild_cablam_cache

REM remove intermediate objects in build directory
cd build
del /S /Q *.obj
cd ..

REM copy files in build
REM not sure why directory changes, which is why "cd %SRC_DIR%" is needed
SET EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
SET CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
cd %SRC_DIR%
dir
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\install_build.py --prefix %LIBRARY_PREFIX% --sp-dir %SP_DIR% --ext-dir %PREFIX%\lib --preserve-egg-dir
if %errorlevel% neq 0 exit /b %errorlevel%

REM copy version and copyright files
%PYTHON% .\modules\cctbx_project\libtbx\version.py --version=%PKG_VERSION%
if %errorlevel% neq 0 exit /b %errorlevel%
copy .\modules\cctbx_project\COPYRIGHT.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.h %LIBRARY_INC%\cctbx
cd .\modules\cctbx_project
%PYTHON% setup.py install
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..\..

REM copy libtbx_env and update dispatchers
echo Copying libtbx_env
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%
%PYTHON% %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra copies of dispatchers
attrib +H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib +H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
del /Q %LIBRARY_BIN%\*show_build_path.bat
del /Q %LIBRARY_BIN%\*show_dist_paths.bat
attrib -H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib -H %LIBRARY_BIN%\libtbx.show_dist_paths.bat

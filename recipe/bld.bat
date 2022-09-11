echo on

call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl m2-gzip m2-tar openssl
call %CONDA%\condabin\conda.bat activate

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
dir
del phenix.tar
cd phenix-installer*
dir
call %CONDA%\condabin\conda.bat deactivate test

REM reapply patches
git apply %RECIPE_DIR%\libtbx_SConscript.patch
copy %RECIPE_DIR%\phaser_SConscript .\modules\phaser\SConscript
@REM copy %RECIPE_DIR%\bootstrap.py .\modules\cctbx_project\libtbx\auto_build\bootstrap.py

REM clean up sources
rmdir /S /Q .\modules\cctbx_project\xfel\euxfel\definitions

call futurize -f libfuturize.fixes.fix_print_with_import -wn .\modules\phaser_regression
call futurize -f libfuturize.fixes.fix_print_with_import -wn .\modules\phaser_voyager

copy %RECIPE_DIR%\parseHHpred.py .\modules\phaser_voyager\old_storage\scripts\parseHHpred.py
rmdir /S /Q .\modules\phaser_voyager\old_storage\VoyagerGUI-QTC\old_gui

call futurize -f libfuturize.fixes.fix_print_with_import -wn .\modules\reduce
call futurize -f lib2to3.fixes.fix_except -wn .\modules\reduce

call futurize -f libfuturize.fixes.fix_print_with_import -wn .\modules\tntbx

REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons
rmdir /S /Q .\modules\phenix_regression
rmdir /S /Q .\modules\phaser_regression
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

REM move chem_data, phenix_examples, and phenix_regression
cd .\modules
move .\chem_data %SP_DIR%
move .\phenix_examples %SP_DIR%
REM move .\phenix_regression %SP_DIR%
cd ..
dir

REM copy files in build
REM not sure why directory changes, which is why "cd %SRC_DIR%" is needed
SET EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
SET CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
cd %SRC_DIR%
cd phenix-installer*
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

REM copy Phenix environment files
SET EXTRA_PHENIX_DIR=%LIBRARY_PREFIX%\share\phenix
mkdir  %EXTRA_PHENIX_DIR%
cd %SRC_DIR%
cd phenix-installer*
move .\modules\phenix\conda_envs %EXTRA_PHENIX_DIR%
if %errorlevel% neq 0 exit /b %errorlevel%

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
if %errorlevel% neq 0 exit /b %errorlevel%

REM clean up cbflib
move %SP_DIR%\cbflib\pycbf\pycbf.py %SP_DIR%
rmdir /S /Q %SP_DIR%\cbflib
if %errorlevel% neq 0 exit /b %errorlevel%

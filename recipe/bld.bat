echo on

dir C:\

call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl git openssl xz
call %CONDA%\condabin\conda.bat activate test
call %CONDA%\condabin\conda.bat clean --all -y

REM clear up more disk space
dir D:\bld\src_cache
del /S /Q D:\bld\src_cache\*
dir D:\bld\src_cache

cd %SRC_DIR%
dir
@REM c:\\c\\envs\\b\\Library\bin\openssl.exe ^
openssl ^
  enc -d ^
  -aes-256-cbc ^
  -salt ^
  -md sha256 ^
  -iter 100000 ^
  -pbkdf2 ^
  -in %SRC_DIR%\phenix.enc ^
  -out %SRC_DIR%\phenix.tar.xz ^
  -pass env:TARBALL_PASSWORD
if %errorlevel% neq 0 exit /b %errorlevel%
dir
del /S /Q %SRC_DIR%\phenix.enc
tar -xf phenix.tar.xz
if %errorlevel% neq 0 exit /b %errorlevel%
dir
del /S /Q phenix.tar.xz
cd phenix-installer*
dir
call %CONDA%\condabin\conda.bat deactivate

REM reapply patches
git apply %RECIPE_DIR%\libtbx_SConscript.patch
git apply %RECIPE_DIR%\bootstrap_win.patch
copy %RECIPE_DIR%\phaser_SConscript .\modules\phaser\SConscript

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
dir

REM remove some libtbx_refresh.py files
del /S /Q .\modules\dxtbx\libtbx_refresh.py
del /S /Q .\modules\iota\libtbx_refresh.py
del /S /Q .\modules\xia2\libtbx_refresh.py

REM shorten PATH
@REM set OLDPATH=%PATH%
@REM set PATH=%BUILD_PREFIX%;%BUILD_PREFIX%\Library\mingw-w64\bin;%BUILD_PREFIX%\Library\usr\bin;%BUILD_PREFIX%\Library\bin;%BUILD_PREFIX%\Scripts;%BUILD_PREFIX%\bin;%PREFIX%;%PREFIX%\Library\mingw-w64\bin;%PREFIX%\Library\usr\bin;%PREFIX%\Library\bin;%PREFIX%\Scripts;%PREFIX%\bin;C:\Miniforge;C:\Miniforge\Library\mingw-w64\bin;C:\Miniforge\Library\usr\bin;C:\Miniforge\Library\bin;C:\Miniforge\Scripts;C:\Miniforge\bin;C:\Miniforge\condabin;C:\Miniforge\Scripts
@REM call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x64

REM build
set CCTBX_SKIP_CHEMDATA_CACHE_REBUILD=1
%PYTHON% bootstrap.py build ^
  --builder=phenix_release ^
  --use-conda %PREFIX% ^
  --nproc 4 ^
  --config-flags="--no_bin_python"
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..

REM delete rotarama and cablam caches
cd %SRC_DIR%
cd phenix-installer*
del /S /Q .\modules\chem_data\rotarama_data\*.pickle
del /S /Q .\modules\chem_data\rotarama_data\*.dlite
del /S /Q .\modules\chem_data\cablam_data\*.pickle
del /S /Q .\modules\chem_data\cablam_data\*.dlite

REM remove intermediate objects in build directory
cd %SRC_DIR%
cd phenix-installer*
cd build
del /S /Q *.obj

REM remove compiled Python files
REM https://stackoverflow.com/questions/28991015/python3-project-remove-pycache-folders-and-pyc-files
cd %SRC_DIR%
cd phenix-installer*
%PYTHON% -Bc "import pathlib; import shutil; [shutil.rmtree(p) for p in pathlib.Path('.\build').rglob('__pycache__')]"
%PYTHON% -Bc "import pathlib; import shutil; [shutil.rmtree(p) for p in pathlib.Path('.\modules').rglob('__pycache__')]"

REM move chem_data, phenix_examples, and phenix_regression
cd %SRC_DIR%
cd phenix-installer*
cd .\modules
move .\chem_data %SP_DIR%
move .\phenix_examples %SP_DIR%
move .\phenix_regression %SP_DIR%
dir
cd ..

REM copy files in build
REM not sure why directory changes, which is why "cd %SRC_DIR%" is needed
set EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
set CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
cd %SRC_DIR%
cd phenix-installer*
dir
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\install_build.py ^
  --prefix %LIBRARY_PREFIX% ^
  --sp-dir %SP_DIR% ^
  --ext-dir %PREFIX%\lib ^
  --preserve-egg-dir
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
set EXTRA_PHENIX_DIR=%LIBRARY_PREFIX%\share\phenix
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

REM cop REST credentials
echo Copying REST credentials
mkdir %EXTRA_CCTBX_DIR%\rest
copy C:\rest\token %EXTRA_CCTBX_DIR%\rest\token
copy C:\rest\url %EXTRA_CCTBX_DIR%\rest\url

REM remove extra copies of dispatchers
@REM set PATH=%OLDPATH%
attrib +H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib +H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
del /Q %LIBRARY_BIN%\*show_build_path.bat
del /Q %LIBRARY_BIN%\*show_dist_paths.bat
attrib -H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib -H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
if %errorlevel% neq 0 exit /b %errorlevel%

REM install dxtbx, dials, iota, and xia2
rmdir /S /Q %SP_DIR%\dxtbx
rmdir /S /Q %SP_DIR%\iota
rmdir /S /Q %SP_DIR%\xia2
cd modules
cd .\dxtbx
%PYTHON% -m pip install . -vv --no-deps
cd ..
cd .\iota
%PYTHON% -m pip install . -vv --no-deps
cd ..
cd .\xia2
%PYTHON% -m pip install . -vv --no-deps
cd ..
cd ..

REM copy dxtbx_flumpy.so separately since it does not end it *_ext.so
REM copy ./build/lib/dxtbx_flumpy.so ${SP_DIR}/../lib-dynload/

REM copy items for Start Menu
set MENU_DIR=%PREFIX%\Menu
mkdir %MENU_DIR%

copy .\modules\gui_resources\icons\custom\phenix.ico %MENU_DIR%
if %errorlevel% neq 0 exit /b %errorlevel%

%PYTHON% %RECIPE_DIR%\scripts\win_update_menu.py --file %RECIPE_DIR%\menu-windows.json --version %PKG_VERSION%
if %errorlevel% neq 0 exit /b %errorlevel%

copy %RECIPE_DIR%\menu-windows.json %MENU_DIR%\phenix.json
if %errorlevel% neq 0 exit /b %errorlevel%

REM clean up cbflib
move %SP_DIR%\cbflib\pycbf\pycbf.py %SP_DIR%
rmdir /S /Q %SP_DIR%\cbflib
if %errorlevel% neq 0 exit /b %errorlevel%

REM clean up build directory
cd %SRC_DIR%
cd phenix-installer*
rmdir /S /Q .\build
if %errorlevel% neq 0 exit /b %errorlevel%
dir

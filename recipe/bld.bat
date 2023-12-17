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
copy %RECIPE_DIR%\phaser_replacements\phaser_SConscript .\modules\phaser\SConscript
copy %RECIPE_DIR%\phaser_replacements\install_build.py .\modules\cctbx_project\libtbx\auto_build\conda_build\install_build.py
copy %RECIPE_DIR%\phaser_replacements\main.py .\modules\phaser\phaser\command_line\main.py
@REM fix boost/timer.hpp
@REM copy %RECIPE_DIR%\phaser_replacements\libtbx_SConscript .\modules\cctbx_project\libtbx\SConscript
@REM copy %RECIPE_DIR%\phaser_replacements\boost_adaptbx_SConscript .\modules\cctbx_project\boost_adaptbx\SConscript

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
set OLDPATH=%PATH%
echo "OLD PATH"
echo %PATH%
%PYTHON% %RECIPE_DIR%\scripts\get_unique_paths.py > unique_paths.txt
echo "SCRIPT OUTPUT"
more unique_paths.txt
for /F "tokens=*" %%A in (unique_paths.txt) do set UNIQUE_PATH=%%A;%UNIQUE_PATH%
echo "UNIQUE_PATH"
echo %UNIQUE_PATH%
set PATH=%UNIQUE_PATH%
echo "NEW PATH"
echo %PATH%

REM build
set CCTBX_SKIP_CHEMDATA_CACHE_REBUILD=1
%PYTHON% bootstrap.py build ^
  --builder=phenix ^
  --use-conda %PREFIX% ^
  --nproc 4 ^
  --config-flags="--no_bin_python" ^
  --config-flags="--cxxstd=c++14"
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
@REM cd %SRC_DIR%
@REM cd phenix-installer*
@REM cd .\modules
@REM move .\chem_data %SP_DIR%
@REM move .\phenix_examples %SP_DIR%
@REM move .\phenix_regression %SP_DIR%
@REM dir
@REM cd ..

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
  --ext-dir %PREFIX%\lib
if %errorlevel% neq 0 exit /b %errorlevel%

REM copy version and copyright files
@REM %PYTHON% .\modules\cctbx_project\libtbx\version.py --version=%PKG_VERSION%
@REM if %errorlevel% neq 0 exit /b %errorlevel%
@REM copy .\modules\cctbx_project\COPYRIGHT.txt %EXTRA_CCTBX_DIR%
@REM copy .\modules\cctbx_project\cctbx_version.txt %EXTRA_CCTBX_DIR%
@REM copy .\modules\cctbx_project\cctbx_version.h %LIBRARY_INC%\cctbx
@REM cd .\modules\cctbx_project
@REM %PYTHON% setup.py install
@REM if %errorlevel% neq 0 exit /b %errorlevel%
@REM cd ..\..

REM copy Phenix environment files
@REM set EXTRA_PHENIX_DIR=%LIBRARY_PREFIX%\share\phenix
@REM mkdir  %EXTRA_PHENIX_DIR%
@REM cd %SRC_DIR%
@REM cd phenix-installer*
@REM move .\modules\phenix\conda_envs %EXTRA_PHENIX_DIR%
@REM if %errorlevel% neq 0 exit /b %errorlevel%

REM copy libtbx_env and update dispatchers
echo Copying libtbx_env
robocopy /E .\modules\cctbx_project\libtbx %SP_DIR%\libtbx
robocopy /E .\modules\cctbx_project\scitbx %SP_DIR%\scitbx
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%
%PYTHON% %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%
rmdir /S /Q %SP_DIR%\libtbx
rmdir /S /Q %SP_DIR%\scitbx

REM remove libtbx and scitbx from installation
del /Q %LIBRARY_BIN%\libtbx.*
del /Q %LIBRARY_BIN%\scitbx.*
del /Q %LIBRARY_BIN%\sphinx.*
rmdir /S /Q %EXTRA_CCTBX_DIR%

REM copy REST credentials
@REM echo Copying REST credentials
@REM mkdir %EXTRA_CCTBX_DIR%\rest
@REM copy .\rest\token %EXTRA_CCTBX_DIR%\rest\token
@REM copy .\rest\url %EXTRA_CCTBX_DIR%\rest\url

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
@REM cd modules
@REM cd .\dxtbx
@REM %PYTHON% -m pip install . -vv --no-deps
@REM cd ..
@REM cd .\iota
@REM %PYTHON% -m pip install . -vv --no-deps
@REM cd ..
@REM cd .\xia2
@REM %PYTHON% -m pip install . -vv --no-deps
@REM cd ..
@REM cd ..

REM copy dxtbx_flumpy.so separately since it does not end it *_ext.so
REM copy ./build/lib/dxtbx_flumpy.so ${SP_DIR}/../lib-dynload/

REM copy items for Start Menu
@REM set MENU_DIR=%PREFIX%\Menu
@REM mkdir %MENU_DIR%

@REM copy .\modules\gui_resources\icons\custom\phenix.ico %MENU_DIR%
@REM if %errorlevel% neq 0 exit /b %errorlevel%

@REM %PYTHON% %RECIPE_DIR%\scripts\win_update_menu.py --file %RECIPE_DIR%\menu-windows.json --version %PKG_VERSION%
@REM if %errorlevel% neq 0 exit /b %errorlevel%

@REM copy %RECIPE_DIR%\menu-windows.json %MENU_DIR%\phenix.json
@REM if %errorlevel% neq 0 exit /b %errorlevel%

REM clean up cbflib
@REM move %SP_DIR%\cbflib\pycbf\pycbf.py %SP_DIR%
rmdir /S /Q %SP_DIR%\cbflib
if %errorlevel% neq 0 exit /b %errorlevel%

REM clean up build directory
cd %SRC_DIR%
cd phenix-installer*
rmdir /S /Q .\build
if %errorlevel% neq 0 exit /b %errorlevel%
dir

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

REM clean up sources
rmdir /S /Q .\modules\cctbx_project\xfel\euxfel\definitions

REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons
dir

REM remove some libtbx_refresh.py files
del /S /Q .\modules\iota\libtbx_refresh.py
del /S /Q .\modules\xia2\libtbx_refresh.py

REM build
%PYTHON% bootstrap.py build ^
  --builder=phenix_release ^
  --use-conda %PREFIX% ^
  --nproc %CPU_COUNT% ^
  --config-flags="--cxxstd=c++14" ^
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
cd build
del /S /Q *.obj
cd ..

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
@REM move .\chem_data %SP_DIR%
rmdir /S /Q .\chem_data
move .\phenix_examples %SP_DIR%
move .\phenix_regression %SP_DIR%
dir
cd ..

REM copy files in build
SET EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
SET CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
cd %SRC_DIR%
cd phenix-installer*
dir
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\install_build.py ^
  --prefix %LIBRARY_PREFIX% ^
  --sp-dir %SP_DIR% ^
  --ext-dir %PREFIX%\lib ^
  --preserve-egg-dir
if %errorlevel% neq 0 exit /b %errorlevel%

REM copy Phaser defaults
mkdir  %EXTRA_CCTBX_DIR%\include
xcopy .\build\include\phaser* %EXTRA_CCTBX_DIR%\include

REM copy command_line directory for New_Voyager
move .\modules\phaser_voyager\command_line %SP_DIR%\New_Voyager
dir %SP_DIR%\New_Voyager

REM copy modules/elbow files
xcopy /E /Y .\modules\elbow %SP_DIR%
rmdir /S /Q %SP_DIR%\elbow\elbow\command_line
dir %SP_DIR%\elbow

REM copy version and copyright files
%PYTHON% .\modules\cctbx_project\libtbx\version.py
if %errorlevel% neq 0 exit /b %errorlevel%
copy .\modules\cctbx_project\COPYRIGHT.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.h %LIBRARY_INC%\cctbx
cd .\modules\cctbx_project
%PYTHON% -m pip install . -vv
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

REM copy REST credentials
echo Copying REST credentials
mkdir %EXTRA_CCTBX_DIR%\rest
copy .\rest\token %EXTRA_CCTBX_DIR%\rest\token
copy .\rest\url %EXTRA_CCTBX_DIR%\rest\url
copy .\rest\ai_url %EXTRA_CCTBX_DIR%\rest\ai_url

REM copy build/include_paths for some tests
echo Copying ./build/include_paths
copy .\build\include_paths %EXTRA_CCTBX_DIR%

REM copy annlib headers and then clean up annlib
xcopy /E .\modules\annlib\include\ANN %EXTRA_CCTBX_DIR%\annlib_adaptbx\include\ANN\
rmdir /S /Q .\build\annlib
rmdir /S /Q .\modules\annlib

REM remove extra copies of dispatchers
attrib +H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib +H %LIBRARY_BIN%\libtbx.show_dist_paths.bat
del /Q %LIBRARY_BIN%\*show_build_path.bat
del /Q %LIBRARY_BIN%\*show_dist_paths.bat
attrib -H %LIBRARY_BIN%\libtbx.show_build_path.bat
attrib -H %LIBRARY_BIN%\libtbx.show_dist_paths.bat

REM add version to phenix dispatcher
%PYTHON% %RECIPE_DIR%\scripts\add_phenix_version.py --prefix %PREFIX% --version %PKG_VERSION%

REM fix dxtbx and dials
xcopy /E %SP_DIR%\not_dxtbx\src\dxtbx %SP_DIR%
xcopy /E %SP_DIR%\not_dxtbx\src\dxtbx.egg-info %SP_DIR%

xcopy /E %SP_DIR%\not_dials\src\dials %SP_DIR%
xcopy /E %SP_DIR%\not_dials\src\dials.egg-info %SP_DIR%

REM install iota and xia2
rmdir /S /Q %SP_DIR%\iota
rmdir /S /Q %SP_DIR%\xia2
cd modules
cd .\iota
%PYTHON% -m pip install . -vv --no-deps > iota.log 2> iota_error.log
cd ..
cd .\xia2
%PYTHON% -m pip install . -vv --no-deps > xia2.log 2> xia2_error.log
cd ..
cd ..

REM copy items for Start Menu
set MENU_DIR=%PREFIX%\Menu
mkdir %MENU_DIR%

copy .\modules\gui_resources\icons\custom\phenix.ico %MENU_DIR%
if %errorlevel% neq 0 exit /b %errorlevel%

%PYTHON% %RECIPE_DIR%\scripts\win_update_menu.py --file %RECIPE_DIR%\menu-windows.json --version %PKG_VERSION%
if %errorlevel% neq 0 exit /b %errorlevel%

copy /Y %RECIPE_DIR%\menu-windows.json %MENU_DIR%\%PKG_NAME%_menu.json
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

echo on

call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl m2-gzip m2-tar openssl
call %CONDA%\condabin\conda.bat activate test
SET TARBALL="https://artprodcus3.artifacts.visualstudio.com/Aa21b64c7-c136-4a25-ab50-eb9ba3fa4296/f0ee1b2f-77b3-4fa6-a2c5-97101b71b939/_apis/artifact/cGlwZWxpbmVhcnRpZmFjdDovL3BoZW5peC1yZWxlYXNlL3Byb2plY3RJZC9mMGVlMWIyZi03N2IzLTRmYTYtYTJjNS05NzEwMWI3MWI5MzkvYnVpbGRJZC8xMTEzL2FydGlmYWN0TmFtZS9waGVuaXgtMjAyMS4wNi5hMDc1/content?format=file&subPath=/phenix-2021.06.a07.enc"
curl -L -o phenix.enc %TARBALL%
openssl enc -d -aes-256-cbc -in phenix.enc -out phenix.tgz -md sha256 -pass env:TARBALL_PASSWORD
rmdir /S /Q .\modules
tar -xzf phenix.tgz
del phenix.enc
del phenix.tgz
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

REM remove intermediate objects in build directory
cd build
del /S /Q *.obj
cd ..

REM copy files in build
SET EXTRA_CCTBX_DIR=%LIBRARY_PREFIX%\share\cctbx
mkdir  %EXTRA_CCTBX_DIR%
SET CCTBX_CONDA_BUILD=.\modules\cctbx_project\libtbx\auto_build\conda_build
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

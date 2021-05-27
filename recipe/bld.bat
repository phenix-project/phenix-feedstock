echo on

call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl m2-gzip m2-tar openssl
call %CONDA%\condabin\conda.bat activate test
SET TARBALL="https://artprodcus3.artifacts.visualstudio.com/Aa21b64c7-c136-4a25-ab50-eb9ba3fa4296/f0ee1b2f-77b3-4fa6-a2c5-97101b71b939/_apis/artifact/cGlwZWxpbmVhcnRpZmFjdDovL3BoZW5peC1yZWxlYXNlL3Byb2plY3RJZC9mMGVlMWIyZi03N2IzLTRmYTYtYTJjNS05NzEwMWI3MWI5MzkvYnVpbGRJZC8xMDU1L2FydGlmYWN0TmFtZS9waGVuaXgtMjAyMS4wNS5hMjQ1/content?format=zip"
curl -L -o phenix.enc %TARBALL%
more phenix.enc
openssl enc -d -aes-256-cbc -in phenix.enc -out phenix.tgz -md sha256 -pass env:TARBALL_PASSWORD
rmdir /S /Q .\modules
tar -xzf phenix.tgz
del phenix.tgz
cd phenix-installer*
move .\modules ..
cd ..

REM reapply patches
git apply %RECIPE_DIR%\crys3d.patch
copy %RECIPE_DIR%\phaser_SConscript .\modules\phaser\SConscript
copy %RECIPE_DIR%\bootstrap.py .\modules\cctbx_project\libtbx\auto_build\bootstrap.py

REM get latest DIALS repositories
@REM cd modules
@REM rmdir /S /Q .\dials
@REM rmdir /S /Q .\dxtbx
@REM rmdir /S /Q .\xia2
@REM git clone https://github.com/dials/dials.git
@REM git clone https://github.com/dials/dxtbx.git
@REM cd ..

REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons

REM build
%PYTHON% bootstrap.py build --builder=phenix --use-conda %PREFIX% --nproc 4 --config-flags="--enable_cxx11" --config-flags="--no_bin_python"
if %errorlevel% neq 0 exit /b %errorlevel%
cd build
call .\bin\libtbx.configure cma_es crys3d fable rstbx spotinder
if %errorlevel% neq 0 exit /b %errorlevel%
call .\bin\libtbx.scons -j %CPU_COUNT%
if %errorlevel% neq 0 exit /b %errorlevel%
call .\bin\libtbx.scons -j %CPU_COUNT%
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

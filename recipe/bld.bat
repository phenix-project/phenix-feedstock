call %CONDA%\condabin\conda.bat create -n test -y -c conda-forge curl m2-gzip m2-tar
call %CONDA%\condabin\conda.bat activate test
curl -L -O "http://cci.lbl.gov/~bkpoon/abc.txt"
rmdir /S /Q .\modules
dir
tar -xzf abc.txt
move phenix*\modules .
call %CONDA%\condabin\conda.bat deactivate
call %CONDA%\condabin\conda.bat remove -n test -y --all

REM reapply patches
git apply %RECIPE_DIR%\crys3d.patch
copy %RECIPE_DIR%\phaser_SConscript .\modules\phaser\SConscript
copy %RECIPE_DIR%\bootstrap.py .\modules\cctbx_project\libtbx\auto_build\bootstrap.py

REM get latest DIALS repositories
cd modules
rmdir /S /Q .\dials
rmdir /S /Q .\dxtbx xia2
git clone https://github.com/dials/dials.git
git clone https://github.com/dials/dxtbx.git
cd ..

REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons

REM build
%PYTHON% bootstrap.py build --builder=cctbx --use-conda %PREFIX% --nproc 4 --config-flags="--enable_cxx11" --config-flags="--no_bin_python"
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

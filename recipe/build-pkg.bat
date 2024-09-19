REM copy bootstrap.py
copy modules\cctbx_project\libtbx\auto_build\bootstrap.py .
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source code
rmdir /S /Q .\modules\boost
rmdir /S /Q .\modules\eigen
rmdir /S /Q .\modules\scons

REM build
%PYTHON% bootstrap.py build ^
  --builder=cctbx ^
  --use-conda %PREFIX% ^
  --nproc %CPU_COUNT% ^
  --config-flags="--cxxstd=c++14" ^
  --config-flags="--no_bin_python" ^
  --config-flags="--skip_phenix_dispatchers"
if %errorlevel% neq 0 exit /b %errorlevel%
cd build
call .\bin\libtbx.configure cma_es crys3d fable rstbx serialtbx spotinder
if %errorlevel% neq 0 exit /b %errorlevel%
call .\bin\libtbx.scons -j %CPU_COUNT%
if %errorlevel% neq 0 exit /b %errorlevel%
call .\bin\libtbx.scons -j %CPU_COUNT%
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..

REM remove dxtbx and cbflib
del /S /Q .\build\*cbflib*
del /S /Q .\build\lib\cbflib*
for /D %%i in (.\build\lib\*dxtbx*) do rmdir /S /Q %%i
rmdir /S /Q .\modules\dxtbx
rmdir /S /Q .\modules\cbflib
call .\build\bin\libtbx.python %RECIPE_DIR%\clean_env.py
if %errorlevel% neq 0 exit /b %errorlevel%

REM remove extra source files (C, C++, Fortran, CUDA)
cd build
del /S /Q *.c
del /S /Q *.cpp
del /S /Q *.cu
del /S /Q *.f
cd ..\modules
del /S /Q *.c
del /S /Q *.cpp
del /S /Q *.cu
del /S /Q *.f
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

REM copy gui_resources
xcopy /E /I .\modules\gui_resources %SP_DIR%\gui_resources

REM copy version and copyright files
%PYTHON% .\modules\cctbx_project\libtbx\version.py --version=%PKG_VERSION%
if %errorlevel% neq 0 exit /b %errorlevel%
copy .\modules\cctbx_project\COPYRIGHT.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.txt %EXTRA_CCTBX_DIR%
copy .\modules\cctbx_project\cctbx_version.h %LIBRARY_INC%\cctbx
cd .\modules\cctbx_project
%PYTHON% -m pip install . -vv
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..\..

REM copy libtbx_env and update dispatchers
echo Copying libtbx_env
call .\build\bin\libtbx.python %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%
%PYTHON% %CCTBX_CONDA_BUILD%\update_libtbx_env.py
if %errorlevel% neq 0 exit /b %errorlevel%

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

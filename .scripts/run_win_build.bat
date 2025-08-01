:: PLEASE NOTE: This script has been automatically generated by conda-smithy. Any changes here
:: will be lost next time ``conda smithy rerender`` is run. If you would like to make permanent
:: changes to this script, consider a proposal to conda-smithy so that other feedstocks can also
:: benefit from the improvement.

:: INPUTS (required environment variables)
:: CONFIG: name of the .ci_support/*.yaml file for this job
:: CI: azure, github_actions, or unset
:: MINIFORGE_HOME: where to install the base conda environment
:: UPLOAD_PACKAGES: true or false
:: UPLOAD_ON_BRANCH: true or false

setlocal enableextensions enabledelayedexpansion

FOR %%A IN ("%~dp0.") DO SET "REPO_ROOT=%%~dpA"
if "%MINIFORGE_HOME%"=="" set "MINIFORGE_HOME=%USERPROFILE%\Miniforge3"
:: Remove trailing backslash, if present
if "%MINIFORGE_HOME:~-1%"=="\" set "MINIFORGE_HOME=%MINIFORGE_HOME:~0,-1%"
call :start_group "Provisioning base env with micromamba"
set "MAMBA_ROOT_PREFIX=%MINIFORGE_HOME%-micromamba-%RANDOM%"
set "MICROMAMBA_VERSION=1.5.10-0"
set "MICROMAMBA_URL=https://github.com/mamba-org/micromamba-releases/releases/download/%MICROMAMBA_VERSION%/micromamba-win-64"
set "MICROMAMBA_TMPDIR=%TMP%\micromamba-%RANDOM%"
set "MICROMAMBA_EXE=%MICROMAMBA_TMPDIR%\micromamba.exe"

echo Downloading micromamba %MICROMAMBA_VERSION%
if not exist "%MICROMAMBA_TMPDIR%" mkdir "%MICROMAMBA_TMPDIR%"
powershell -ExecutionPolicy Bypass -Command "(New-Object Net.WebClient).DownloadFile('%MICROMAMBA_URL%', '%MICROMAMBA_EXE%')"
if !errorlevel! neq 0 exit /b !errorlevel!

echo Creating environment
call "%MICROMAMBA_EXE%" create --yes --root-prefix "%MAMBA_ROOT_PREFIX%" --prefix "%MINIFORGE_HOME%" ^
    --channel conda-forge ^
    pip python=3.12 conda-build conda-forge-ci-setup=4 "conda-build>=24.1"
if !errorlevel! neq 0 exit /b !errorlevel!
echo Removing %MAMBA_ROOT_PREFIX%
del /S /Q "%MAMBA_ROOT_PREFIX%" >nul
del /S /Q "%MICROMAMBA_TMPDIR%" >nul
call :end_group

call :start_group "Configuring conda"

:: Activate the base conda environment
echo Activating environment
call "%MINIFORGE_HOME%\Scripts\activate.bat"
:: Configure the solver
set "CONDA_SOLVER=libmamba"
if !errorlevel! neq 0 exit /b !errorlevel!
set "CONDA_LIBMAMBA_SOLVER_NO_CHANNELS_FROM_INSTALLED=1"

:: Set basic configuration
echo Setting up configuration
setup_conda_rc .\ ".\recipe" .\.ci_support\%CONFIG%.yaml
if !errorlevel! neq 0 exit /b !errorlevel!
echo Running build setup
CALL run_conda_forge_build_setup


if !errorlevel! neq 0 exit /b !errorlevel!

if EXIST LICENSE.txt (
    echo Copying feedstock license
    copy LICENSE.txt "recipe\\recipe-scripts-license.txt"
)
if NOT [%HOST_PLATFORM%] == [%BUILD_PLATFORM%] (
    set "EXTRA_CB_OPTIONS=%EXTRA_CB_OPTIONS% --no-test"
)

if NOT [%flow_run_id%] == [] (
        set "EXTRA_CB_OPTIONS=%EXTRA_CB_OPTIONS% --extra-meta flow_run_id=%flow_run_id% remote_url=%remote_url% sha=%sha%"
)

call :end_group

:: Build the recipe
echo Building recipe
conda-build.exe "recipe" -m .ci_support\%CONFIG%.yaml --suppress-variables %EXTRA_CB_OPTIONS%
if !errorlevel! neq 0 exit /b !errorlevel!

call :start_group "Inspecting artifacts"
:: inspect_artifacts was only added in conda-forge-ci-setup 4.9.4
WHERE inspect_artifacts >nul 2>nul && inspect_artifacts --recipe-dir ".\recipe" -m .ci_support\%CONFIG%.yaml || echo "inspect_artifacts needs conda-forge-ci-setup >=4.9.4"
call :end_group

:: Prepare some environment variables for the upload step
if /i "%CI%" == "github_actions" (
    set "FEEDSTOCK_NAME=%GITHUB_REPOSITORY:*/=%"
    set "GIT_BRANCH=%GITHUB_REF:refs/heads/=%"
    if /i "%GITHUB_EVENT_NAME%" == "pull_request" (
        set "IS_PR_BUILD=True"
    ) else (
        set "IS_PR_BUILD=False"
    )
    set "TEMP=%RUNNER_TEMP%"
)
if /i "%CI%" == "azure" (
    set "FEEDSTOCK_NAME=%BUILD_REPOSITORY_NAME:*/=%"
    set "GIT_BRANCH=%BUILD_SOURCEBRANCHNAME%"
    if /i "%BUILD_REASON%" == "PullRequest" (
        set "IS_PR_BUILD=True"
    ) else (
        set "IS_PR_BUILD=False"
    )
    set "TEMP=%UPLOAD_TEMP%"
)
set "UPLOAD_ON_BRANCH=upload"
:: Note, this needs GIT_BRANCH too

:: Validate

if /i "%UPLOAD_PACKAGES%" == "true" (
    if /i "%IS_PR_BUILD%" == "false" (
        call :start_group "Uploading packages"
        if not exist "%TEMP%\" md "%TEMP%"
        set "TMP=%TEMP%"
        upload_package  .\ ".\recipe" .ci_support\%CONFIG%.yaml
        if !errorlevel! neq 0 exit /b !errorlevel!
        call :end_group
    )
)

exit

:: Logging subroutines

:start_group
if /i "%CI%" == "github_actions" (
    echo ::group::%~1
    exit /b
)
if /i "%CI%" == "azure" (
    echo ##[group]%~1
    exit /b
)
echo %~1
exit /b

:end_group
if /i "%CI%" == "github_actions" (
    echo ::endgroup::
    exit /b
)
if /i "%CI%" == "azure" (
    echo ##[endgroup]
    exit /b
)
exit /b

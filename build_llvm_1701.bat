@echo off
setlocal

REM Script for building the LLVM installer on Windows,
REM used for the the weekly snapshots at http://www.llvm.org/builds.
REM
REM Usage: build_llvm_package.bat <revision>

REM Prerequisites:
REM
REM   Visual Studio 2019, CMake, Ninja, SVN, GNUWin32, SWIG, Python 3,
REM   NSIS with the strlen_8192 patch,
REM   Visual Studio 2019 SDK and Nuget (for the clang-format plugin),
REM   Perl (for the OpenMP run-time), 7Zip.
REM
REM
REM   For LLDB, SWIG version <= 3.0.8 needs to be used to work around
REM   https://github.com/swig/swig/issues/769


REM You need to modify the paths below:
set vsdevcmd=C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat

set python64_dir=C:\Users\Pichau\AppData\Local\Programs\Python\Python39

set revision=llvmorg-17.0.1
set package_version=17.0.1
set build_dir=llvm_package_1701-final

echo Revision: %revision%
echo Package version: %package_version%
echo Build dir: %build_dir%
echo.
pause

mkdir %build_dir%
cd %build_dir%

echo Checking out %revision%
7z x ..\src.zip || exit /b
mv llvm-project-* llvm-project || exit /b

REM Setting CMAKE_CL_SHOWINCLUDES_PREFIX to work around PR27226.
set cmake_flags=^
  -DCMAKE_BUILD_TYPE=Release ^
  -DLLVM_ENABLE_ASSERTIONS=OFF ^
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON ^
  -DLLVM_BUILD_LLVM_C_DYLIB=ON ^
  -DCMAKE_INSTALL_UCRT_LIBRARIES=ON ^
  -DPython3_FIND_REGISTRY=NEVER ^
  -DPACKAGE_VERSION=%package_version% ^
  -DLLDB_RELOCATABLE_PYTHON=1 ^
  -DLLDB_ENABLE_PYTHON=ON ^
  -DLLDB_TEST_COMPILER=%cd%\build32_stage0\bin\clang.exe ^
  -DCMAKE_CL_SHOWINCLUDES_PREFIX="Note: including file: " ^
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;compiler-rt;lldb;openmp"

REM TODO: Run the "check-all" tests.

set OLDPATH=%PATH%

set "VSCMD_START_DIR=%CD%"
set PATH=%OLDPATH%
call "%vsdevcmd%" -arch=amd64
set PATH=%python64_dir%;%PATH%
set CC=
set CXX=
mkdir build64_stage0
cd build64_stage0
cmake -GNinja %cmake_flags% -DPYTHON_HOME=%python64_dir% -DPython3_ROOT_DIR=%python64_dir% ..\llvm-project\llvm || exit /b
ninja || ninja || ninja || exit /b
ninja check-llvm || ninja check-llvm || ninja check-llvm || exit /b
ninja check-clang || ninja check-clang || ninja check-clang || exit /b
ninja check-lld || ninja check-lld || ninja check-lld || exit /b
ninja check-sanitizer || ninja check-sanitizer || ninja check-sanitizer || exit /b
ninja check-clang-tools || ninja check-clang-tools || ninja check-clang-tools || exit /b
ninja check-clangd || ninja check-clangd || ninja check-clangd || exit /b
cd..

mkdir build64
cd build64
set CC=..\build64_stage0\bin\clang-cl
set CXX=..\build64_stage0\bin\clang-cl
cmake -GNinja %cmake_flags% -DPYTHON_HOME=%python64_dir% -DPython3_ROOT_DIR=%python64_dir% ..\llvm-project\llvm || exit /b
ninja || ninja || ninja || exit /b
ninja check-llvm || ninja check-llvm || ninja check-llvm || exit /b
ninja check-clang || ninja check-clang || ninja check-clang || exit /b
ninja check-lld || ninja check-lld || ninja check-lld || exit /b
ninja check-sanitizer || ninja check-sanitizer || ninja check-sanitizer || exit /b
ninja check-clang-tools || ninja check-clang-tools || ninja check-clang-tools || exit /b
ninja check-clangd || ninja check-clangd || ninja check-clangd || exit /b
ninja package || exit /b

7z x LLVM-%package_version%-win64.exe -orepack
rmdir /s /q repack\$PLUGINSDIR
del repack\Uninstall.exe
7z a LLVM-%package_version%-win64.zip .\repack\* -mx9
cd ..

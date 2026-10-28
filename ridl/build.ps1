# Builds the LLVM a KLF distribution carries from this checkout, and packs it:
# the Windows counterpart of build.sh, run from a developer prompt.
#
#   ridl/build.ps1 <build-dir> <install-dir> <archive>
#
# MSVC has no libLLVM DLL, so the tools are static and nothing ships beside
# them but clang's own headers.
param(
    [Parameter(Mandatory)] [string] $BuildDir,
    [Parameter(Mandatory)] [string] $InstallDir,
    [Parameter(Mandatory)] [string] $Archive
)
$ErrorActionPreference = 'Stop'
$Source = Split-Path -Parent $PSScriptRoot

cmake -S "$Source\llvm" -B $BuildDir -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$InstallDir" `
    -DLLVM_ENABLE_PROJECTS="clang;lld" `
    -DLLVM_TARGETS_TO_BUILD="X86;AArch64;WebAssembly" `
    -DLLVM_DISTRIBUTION_COMPONENTS="clang;clang-resource-headers;lld;llvm-ar;llvm-strip;llvm-objcopy;llvm-nm;llvm-dwarfdump" `
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF `
    -DCLANG_ENABLE_ARCMT=OFF `
    -DLLVM_ENABLE_BINDINGS=OFF `
    -DLLVM_ENABLE_LIBXML2=OFF `
    -DLLVM_ENABLE_ZLIB=OFF `
    -DLLVM_ENABLE_ZSTD=OFF `
    -DLLVM_INCLUDE_BENCHMARKS=OFF `
    -DLLVM_INCLUDE_DOCS=OFF `
    -DLLVM_INCLUDE_EXAMPLES=OFF `
    -DLLVM_INCLUDE_TESTS=OFF `
    "-DCMAKE_CXX_FLAGS=/D_USE_STD_VECTOR_ALGORITHMS=0"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build $BuildDir --target install-distribution-stripped
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# lld picks its flavour from the name it runs under.
foreach ($name in 'ld.lld', 'ld64.lld', 'lld-link', 'wasm-ld') {
    $target = Join-Path $InstallDir "bin\$name.exe"
    if (-not (Test-Path $target)) { Copy-Item (Join-Path $InstallDir 'bin\lld.exe') $target }
}
$cxx = Join-Path $InstallDir 'bin\clang++.exe'
if (-not (Test-Path $cxx)) { Copy-Item (Join-Path $InstallDir 'bin\clang.exe') $cxx }

& (Join-Path $InstallDir 'bin\clang.exe') --version
New-Item -ItemType Directory -Force (Split-Path -Parent $Archive) | Out-Null
Compress-Archive -Path (Join-Path $InstallDir '*') -DestinationPath $Archive -Force

# Build FarCryCoopLauncher.exe (Tauri, i686) with Rust from Data\cargo, the read-only MSVC in
# D:\TailCore\toolchain\vs and the x86 Windows SDK libs in Tools\winsdk-x86 (there are no x64
# ones, so host and target are i686). The CRT is linked statically: players need no redistributable.
# Usage: & games\far-cry\launcher\build.ps1 [-Out E:\FarCryCoop\Temp\launcher]
param([string]$Out = 'E:\FarCryCoop\Temp\launcher')
. E:\FarCryCoop\env.ps1
$msvc = 'D:\TailCore\toolchain\vs\VC\Tools\MSVC\14.44.35207'
$sdk = 'E:\FarCryCoop\Tools\winsdk-x86'
$env:PATH = "$msvc\bin\Hostx64\x86;$env:PATH"
$env:LIB = "$msvc\lib\x86;$sdk\sdk\lib\um\x86;$sdk\sdk\lib\ucrt\x86"
$env:INCLUDE = "$msvc\include;$sdk\sdk\include\ucrt;$sdk\sdk\include\um;$sdk\sdk\include\shared"
$env:RUSTFLAGS = '-C target-feature=+crt-static'
$env:CARGO_TARGET_DIR = "$Out\target"
cargo build --release --manifest-path "$PSScriptRoot\Cargo.toml"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
Copy-Item "$Out\target\release\FarCryCoopLauncher.exe" $Out

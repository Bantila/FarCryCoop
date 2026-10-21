# Build FarCryCoopSteam.exe (x86 console) with the read-only MSVC in D:\TailCore\toolchain\vs,
# without the Windows SDK and CRT, the same way as games\far-cry\asi\build.ps1.
# Usage: & games\far-cry\steam\build.ps1 [-Out E:\FarCryCoop\Temp\steam]
param([string]$Out = 'E:\FarCryCoop\Temp\steam')
. E:\FarCryCoop\env.ps1
$msvc = 'D:\TailCore\toolchain\vs\VC\Tools\MSVC\14.44.35207'
$bin = "$msvc\bin\Hostx64\x86"
New-Item -ItemType Directory -Force $Out | Out-Null
# Imported functions: name = bytes of stdcall arguments. steam_api.dll is loaded at run time.
$imports = [ordered]@{
  kernel32 = [ordered]@{ GetStdHandle = 4; WriteFile = 20; Sleep = 4; GetTickCount = 0; LoadLibraryA = 4
    GetProcAddress = 8; GetModuleFileNameA = 12; CreateFileA = 28; CloseHandle = 4; ExitProcess = 4
    GetCommandLineA = 0; SetConsoleTitleA = 4; SetConsoleOutputCP = 4 }
  user32 = [ordered]@{ wvsprintfA = 12 }
  ws2_32 = [ordered]@{ WSAStartup = 8; socket = 12; bind = 12; closesocket = 4; ioctlsocket = 12
    recvfrom = 24; sendto = 24 }
}
foreach ($l in $imports.Keys) {
  $c = foreach ($f in $imports[$l].Keys) {
    $n = $imports[$l][$f] / 4
    $a = if ($n) { (0..($n - 1) | ForEach-Object { "int a$_" }) -join ', ' } else { 'void' }
    "void __stdcall $f($a) {}"
  }
  Set-Content "$Out\$l.c" -Encoding ascii $c
  Set-Content "$Out\$l.def" -Encoding ascii (@("LIBRARY $l.dll", 'EXPORTS') + @($imports[$l].Keys))
  & "$bin\cl.exe" /nologo /c /Zl "/Fo$Out\$l.obj" "$Out\$l.c" | Out-Null
  & "$bin\link.exe" /nologo /dll /noentry /nodefaultlib /machine:x86 "/def:$Out\$l.def" `
    "/out:$Out\$l.stub.dll" "/implib:$Out\$l.lib" "$Out\$l.obj" | Out-Null
  if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
& "$bin\cl.exe" /nologo /c /O1 /GS- /W3 /Zl "/I$msvc\include" "/Fo$Out\FarCryCoopSteam.obj" "$PSScriptRoot\FarCryCoopSteam.c"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& "$bin\link.exe" /nologo /nodefaultlib /entry:start /subsystem:console /safeseh:no /machine:x86 `
  "/out:$Out\FarCryCoopSteam.exe" "$Out\FarCryCoopSteam.obj" "$Out\kernel32.lib" "$Out\user32.lib" "$Out\ws2_32.lib"
exit $LASTEXITCODE

#Requires -Version 7
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$AppName = "template"

$RemoteUser = "debian"
$RemoteHost = "192.168.0.113"
$RemoteDir  = "/home/debian/template"

$DoClean  = $false
$DoDeploy = $false
$DoRun    = $false

$Mode = "debug"

function Show-Usage {
    @'
usage: build.ps1 [debug|release] [clean] [--deploy] [--run]

  debug         configure with the Debug preset (default)
  release       configure with the Release preset
  clean         remove this preset's build directory first
  --deploy      rsync the binary to the board after a successful build
  --run         deploy, then execute it on the board over ssh
  -h, --help    show this help

Target settings come from REMOTE_USER, REMOTE_HOST and REMOTE_DIR.
'@
}

foreach ($arg in $args) {
    switch ($arg) {
        "debug"    { $Mode = "debug" }
        "release"  { $Mode = "release" }
        "clean"    { $DoClean = $true }
        "--deploy" { $DoDeploy = $true }
        "--run"    { $DoRun = $true; $DoDeploy = $true }
        "-h"       { Show-Usage; exit 0 }
        "--help"   { Show-Usage; exit 0 }
        default {
            Write-Error "error: unknown argument '$arg'"
            Show-Usage
            exit 2
        }
    }
}

$BuildDir = "build/$Mode"

if ($DoClean) {
    Write-Output "cleaning $BuildDir"
    Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$GoFlags = @("-o", "$BuildDir/$AppName")
if ($Mode -eq "debug") {
    # DISABLE OPTIMIZATIONS FOR DELVE DEBUG
    $GoFlags += "-gcflags=all=-N -l"
} else {
    # STRIP SYMBOLS + NO DWARF => SMALL BINARIES
    $GoFlags += "-ldflags=-s -w"
}

$env:GOOS   = "linux"
$env:GOARCH = "riscv64"
& go build @GoFlags

Write-Output "built: $BuildDir/$AppName"

if ($DoDeploy) {
    Write-Output "deploying to ${RemoteUser}@${RemoteHost}:${RemoteDir}/"
    & wsl rsync -avz "$BuildDir/$AppName" "${RemoteUser}@${RemoteHost}:${RemoteDir}/"
    if ($LASTEXITCODE -ne 0) {
        Write-Error ""
        exit 1
    }
}

if ($DoRun) {
    Write-Output "running ${RemoteDir}/${AppName} on $RemoteHost"
    & ssh "${RemoteUser}@${RemoteHost}" "echo && ${RemoteDir}/${AppName} && echo"
}
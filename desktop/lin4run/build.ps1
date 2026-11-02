param([string]$OutputName = '奶蛙桌宠-联动版.exe')
$ErrorActionPreference = 'Stop'
if ([System.IO.Path]::GetFileName($OutputName) -ne $OutputName -or !$OutputName.EndsWith('.exe')) { throw 'OutputName must be one executable filename' }
$taskRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
python (Join-Path $taskRoot 'tools/prepare_lin4run_desktop.py')
if ($LASTEXITCODE -ne 0) { throw 'Run python tools/prepare_lin4run_desktop.py --download once to prepare official assets and Roslyn.' }
$compilerPath = Join-Path $taskRoot 'tools/roslyn-5.0.0/csc.exe'
$frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
if (!(Test-Path -LiteralPath $frameworkRoot)) { $frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319' }
$referenceNames = @('mscorlib.dll','System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.IO.Compression.dll','System.IO.Compression.FileSystem.dll','System.Web.Extensions.dll','Microsoft.CSharp.dll')
$referenceArgs = @($referenceNames | ForEach-Object { '/reference:' + (Join-Path $frameworkRoot $_) })
$sourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source') -Filter '*.cs' -File | Sort-Object Name | ForEach-Object FullName)
if ($sourcePaths.Count -lt 18) { throw 'The LIN4RUN desktop source set is incomplete.' }
$compilerArgs = @('/nologo','/noconfig','/nostdlib+','/target:winexe','/optimize+','/unsafe+','/platform:anycpu','/langversion:latest','/utf8output','/win32icon:app.ico','/win32manifest:app.manifest',('/out:../'+$OutputName)) + $referenceArgs + $sourcePaths
Push-Location (Join-Path $PSScriptRoot 'source')
try {
    & $compilerPath @compilerArgs
    if ($LASTEXITCODE -ne 0) { throw 'LIN4RUN desktop compilation failed' }
} finally { Pop-Location }

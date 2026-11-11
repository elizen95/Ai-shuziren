[CmdletBinding()]
param(
    [string]$Root = 'D:/Tset',
    [Parameter(Mandatory)][string]$ModelBackup,
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root)
$assets = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'
$modelSource = (Resolve-Path -LiteralPath $ModelBackup).Path
$manifest = Get-Content -LiteralPath "$assets/model-manifest.json" -Raw | ConvertFrom-Json
$wan = Join-Path $rootPath 'vendor/WanGP'
$revision = '31bf2633b678778d0ba262226c103660878234d1'

function Assert-Hash([string]$Path, [string]$Expected) {
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) {
        throw "SHA-256 mismatch: $Path"
    }
}

foreach ($entry in $manifest) {
    $source = Join-Path $modelSource $entry.path
    if (!(Test-Path -LiteralPath $source -PathType Leaf) -or
        (Get-Item -LiteralPath $source).Length -ne $entry.bytes) {
        throw "Missing or incomplete model: $source"
    }
    Assert-Hash $source $entry.sha256
    Write-Host "Verified $($entry.path)"
}
if ($VerifyOnly) { return }

Get-Command git,nvidia-smi -ErrorAction Stop | Out-Null
& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
if ($LASTEXITCODE -ne 0) { throw 'NVIDIA driver check failed' }

$runtime = Join-Path $rootPath 'runtime'
New-Item -ItemType Directory -Force -Path $wan,$runtime | Out-Null
if (!(Test-Path -LiteralPath "$wan/.git")) {
    & git -C $wan init
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize WanGP checkout' }
}
& git -C $wan rev-parse --verify HEAD 2>$null | ForEach-Object { $current = $_ }
if ($current -and $current -ne $revision) { throw "WanGP is already at $current. Choose a fresh -Root." }
if (!$current) {
    & git -C $wan fetch --depth 1 https://github.com/deepbeepmeep/WanGP.git $revision
    if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the pinned WanGP revision' }
    & git -C $wan checkout --detach FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not check out WanGP' }
}

function Install-Archive([string]$Url, [string]$Sha, [string]$Zip, [string]$Directory, [string]$Probe) {
    if (Test-Path -LiteralPath $Probe -PathType Leaf) { return }
    if (!(Test-Path -LiteralPath $Zip -PathType Leaf)) {
        Invoke-WebRequest -Uri $Url -OutFile "$Zip.part" -TimeoutSec 600
        Assert-Hash "$Zip.part" $Sha
        Move-Item -LiteralPath "$Zip.part" -Destination $Zip -Force
    }
    Assert-Hash $Zip $Sha
    Expand-Archive -LiteralPath $Zip -DestinationPath $Directory -Force
    if (!(Test-Path -LiteralPath $Probe -PathType Leaf)) { throw "Runtime file missing: $Probe" }
}

$uv = Join-Path $runtime 'bin/uv.exe'
$ff = Join-Path $runtime 'ffmpeg/proxy/ffmpeg-9.0.2-essentials_build/bin'
New-Item -ItemType Directory -Force -Path "$runtime/ffmpeg" | Out-Null
Install-Archive 'https://github.com/astral-sh/uv/releases/download/0.13.7/uv-x86_64-pc-windows-msvc.zip' '0CDC5B38FE5A8168ED6A25814F5BA43C21D313DD3187314FCCB37B7CEC46E021' "$runtime/uv-0.13.7.zip" "$runtime/bin" $uv
Install-Archive 'https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip' '60F467265B1E312373DBCD92200C2618A74850F98D3D078E94296BB3FA2047BA' "$runtime/ffmpeg/essentials.zip" "$runtime/ffmpeg/proxy" "$ff/ffmpeg.exe"
$env:UV_PYTHON_INSTALL_DIR = "$runtime/python"
if (!$env:UV_CACHE_DIR) { $env:UV_CACHE_DIR = "$runtime/cache" }
& $uv python install 3.11.14 --no-bin
if ($LASTEXITCODE -ne 0) { throw 'Python 3.11.14 install failed' }
$venv = Join-Path $runtime 'wan-env'
$python = Join-Path $venv 'Scripts/python.exe'
if (!(Test-Path -LiteralPath $python)) {
    & $uv venv --python 3.11.14 $venv
    if ($LASTEXITCODE -ne 0) { throw 'WanGP environment creation failed' }
}
& $uv pip sync --python $python --index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cu130 --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-13-nightly/pypi/simple/ "$assets/windows-cu130.lock.txt"
if ($LASTEXITCODE -ne 0) { throw 'Locked WanGP dependencies failed to install' }

foreach ($entry in $manifest) {
    $source = Join-Path $modelSource $entry.path
    $target = Join-Path $wan $entry.path
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        Assert-Hash $target $entry.sha256
        continue
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination "$target.restore"
    Assert-Hash "$target.restore" $entry.sha256
    Move-Item -LiteralPath "$target.restore" -Destination $target
}
New-Item -ItemType Directory -Force -Path "$wan/ffmpeg_bins" | Out-Null
foreach ($tool in 'ffmpeg.exe','ffprobe.exe','ffplay.exe') {
    $link = Join-Path "$wan/ffmpeg_bins" $tool
    if (!(Test-Path -LiteralPath $link)) {
        New-Item -ItemType HardLink -Path $link -Target (Join-Path $ff $tool) | Out-Null
    }
}
& $python -c "import torch, sageattention; x=torch.randn((1,8,512,128),device='cuda',dtype=torch.float16); assert torch.isfinite(sageattention.sageattn(x,x,x)).all().item(); print(torch.__version__,torch.cuda.get_device_name(0),'SageAttention OK')"
if ($LASTEXITCODE -ne 0) { throw 'CUDA/SageAttention verification failed' }
Write-Host "Restored to $rootPath"


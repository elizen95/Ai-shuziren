[CmdletBinding()]
param(
    [string]$Root = 'D:/Tset',
    [ValidateSet('half','full')][string]$Shot = 'half',
    [string]$Dialogue,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root)
$assets = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'
$wan = Join-Path $rootPath 'vendor/WanGP'
$runtime = Join-Path $rootPath 'runtime'
$python = Join-Path $runtime 'wan-env/Scripts/python.exe'
$ff = Join-Path $runtime 'ffmpeg/proxy/ffmpeg-9.0.2-essentials_build/bin'
foreach ($path in $python,"$ff/ffmpeg.exe","$wan/wgp.py") {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Run Restore-H3.ps1 first. Missing $path" }
}
$id = "$(Get-Date -Format yyyyMMdd-HHmmss-fff)-$Shot"
$result = Join-Path $rootPath "results/h3-fixed-$id"
New-Item -ItemType Directory -Path $result | Out-Null
$anchor = Join-Path $result 'anchor.png'
Copy-Item -LiteralPath "$assets/$Shot-1024x576.png" -Destination $anchor

$job = Get-Content -LiteralPath "$assets/fixed-shot.json" -Raw | ConvertFrom-Json -AsHashtable
$job.image_start = $anchor
$job.image_end = $anchor
if ($Shot -eq 'full') {
    $job.prompt = $job.prompt.Replace('medium shot', 'full-body shot').Replace('constant headroom', 'constant headroom and visible feet')
}
if ($Dialogue) {
    $line = $Dialogue.Trim()
    if ($line -match '[<>]') { throw 'Use plain dialogue text without angle brackets.' }
    $job.prompt = [regex]::Replace($job.prompt, '<d>.*?</d>', { param($match) "<d>[Chinese] $line</d>" })
}
$settings = Join-Path $result 'settings.json'
$job | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $settings -Encoding utf8NoBOM
$env:PATH = "$ff;$env:PATH"
$env:TRITON_CACHE_DIR = "$runtime/triton-cache"
$env:HF_HOME = "$runtime/huggingface"
$env:HF_HUB_OFFLINE = '1'
$env:PYTHONUTF8 = '1'
$env:PYTHONUNBUFFERED = '1'
$env:GRADIO_ANALYTICS_ENABLED = 'False'
$runArgs = @('wgp.py','--process',$settings,'--output-dir',$result,'--profile','4','--attention','sage2','--perc-reserved-mem-max','0.20','--verbose','1')
if ($DryRun) { $runArgs += '--dry-run' }

Push-Location $wan
try {
    & $python -u @runArgs 2>&1 | Tee-Object -FilePath "$result/run.log"
    if ($LASTEXITCODE -ne 0) { throw "WanGP failed. See $result/run.log" }
} finally { Pop-Location }
if ($DryRun) { return }

$raw = Get-ChildItem -LiteralPath $result -Filter '*.mp4' -File | Select-Object -First 1
if (!$raw) { throw 'WanGP did not create a video.' }
$mp4 = Join-Path $result 'avatar-15s.mp4'
& "$ff/ffmpeg.exe" -hide_banner -loglevel error -i $raw.FullName -map 0:v:0 -map 0:a:0 -t 15 -vf fps=30 -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $mp4
if ($LASTEXITCODE -ne 0) { throw 'MP4 export failed.' }
$probe = & "$ff/ffprobe.exe" -v error -show_entries 'format=duration:stream=codec_type,width,height,avg_frame_rate,duration' -of json $mp4
if ($LASTEXITCODE -ne 0) { throw 'Output verification failed.' }
$info = $probe | ConvertFrom-Json
$picture = $info.streams | Where-Object codec_type -eq video
$sound = $info.streams | Where-Object codec_type -eq audio
if ($picture.width -ne 1024 -or $picture.height -ne 576 -or $picture.avg_frame_rate -ne '30/1' -or
    !$sound -or [Math]::Abs([double]$picture.duration - 15) -gt 0.01 -or
    [Math]::Abs([double]$sound.duration - 15) -gt 0.05) { throw "Unexpected media properties: $($probe -join ' ')" }
& "$ff/ffmpeg.exe" -hide_banner -loglevel error -xerror -i $mp4 -f null NUL
if ($LASTEXITCODE -ne 0) { throw 'Final MP4 decode failed.' }
Write-Output $mp4


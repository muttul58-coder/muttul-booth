@echo off
chcp 65001 > nul
title muttul game - 부스 업데이트
rem ──────────────────────────────────────────────────────────────────────────────
rem  서버 노트북용 업데이트 — GitHub 의 최신 부스 묶음을 받아 C:\muttul-booth 를 바꿔 놓는다.
rem  ⚠️ 인터넷이 되는 곳(집·학교)에서 한다. 부스 현장에서는 이미 받아 둔 것을 그대로 쓴다(인터넷 불필요).
rem  이 파일 하나만 있으면 된다(Node·git 설치 불필요). 더블클릭하면 끝.
rem    옵션:  업데이트.bat "D:\다른폴더"   → 설치 위치를 바꾼다(기본 C:\muttul-booth)
rem  GitHub 주소(__REPO__)는 local/release.mjs 가 올릴 때 이 파일 안에 적어 넣는다.
rem ──────────────────────────────────────────────────────────────────────────────
set "BOOTH_SELF=%~f0"
set "BOOTH_ARGS=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:BOOTH_SELF,[Text.Encoding]::UTF8); $i=$s.LastIndexOf('#PS#'+'START'); Invoke-Expression $s.Substring($i)"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%

#PS#START
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo    = 'muttul58-coder/muttul-booth'
$Dir     = if ($env:BOOTH_ARGS) { $env:BOOTH_ARGS.TrimEnd('\') } else { 'C:\muttul-booth' }
$Base    = if ($env:BOOTH_BASE_URL) { $env:BOOTH_BASE_URL.TrimEnd('/') + '/' } else { "https://github.com/$Repo/releases/latest/download/" }
$Tmp     = Join-Path $env:TEMP 'muttul-booth-update'

function Say($m)  { Write-Host $m }
function Fail($m) { Write-Host ''; Write-Host "[오류] $m" -ForegroundColor Red; exit 1 }

Say '=================================================='
Say '  muttul game  부스 업데이트'
Say '=================================================='
if ($Repo -like '__REPO*' -and -not $env:BOOTH_BASE_URL) { Fail '이 파일에 GitHub 주소가 적혀 있지 않습니다. GitHub 저장소에서 받은 업데이트.bat 을 쓰세요.' }
Say "설치 위치: $Dir"
Say ''

New-Item -ItemType Directory -Force $Tmp | Out-Null

# 1) 최신 버전 표식 — 작은 파일 하나라 인터넷이 되는지도 여기서 가려진다
Say '1/5 최신 버전 확인 중...'
$verFile = Join-Path $Tmp 'booth-version.txt'
Remove-Item $verFile -ErrorAction SilentlyContinue
& curl.exe -L -s --fail --retry 2 --connect-timeout 15 -o $verFile ($Base + 'booth-version.txt')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $verFile)) { Fail '인터넷에 연결되어 있지 않거나 GitHub 에서 파일을 찾지 못했습니다. 인터넷이 되는 곳에서 다시 실행하세요.' }
$remoteVer = (Get-Content $verFile -Raw).Trim()
$localVerFile = Join-Path $Dir 'booth-version.txt'
$localVer = if (Test-Path $localVerFile) { (Get-Content $localVerFile -Raw).Trim() } else { '' }
Say "  GitHub 최신 : $remoteVer"
Say "  이 노트북   : $(if ($localVer) { $localVer } else { '(설치 안 됨)' })"
if ($localVer -eq $remoteVer) {
  Say ''
  Say '이미 최신입니다. 바꿀 것이 없습니다.'
  Say "부스를 시작하려면 $Dir\부스시작.bat 을 실행하세요."
  exit 0
}

# 2) 내려받기 — curl 은 끊겨도 이어받는다(-C -)
Say ''
Say '2/5 내려받는 중 (약 80MB — 몇 분 걸릴 수 있습니다)...'
$zip = Join-Path $Tmp 'muttul-booth.zip'
& curl.exe -L --fail --retry 5 --retry-delay 3 -C - --connect-timeout 20 -o $zip ($Base + 'muttul-booth.zip')
if ($LASTEXITCODE -ne 0) { Fail '내려받기에 실패했습니다. 인터넷 연결을 확인하고 다시 실행하세요(이어받기가 됩니다).' }

# 3) 무결성 — GitHub 에 같이 올라간 해시와 맞는지
Say ''
Say '3/5 파일 확인 중...'
$shaFile = Join-Path $Tmp 'muttul-booth.zip.sha256'
Remove-Item $shaFile -ErrorAction SilentlyContinue
& curl.exe -L -s --fail --retry 2 -o $shaFile ($Base + 'muttul-booth.zip.sha256')
if ($LASTEXITCODE -ne 0) { Fail '확인용 해시 파일을 받지 못했습니다.' }
$want = ((Get-Content $shaFile -Raw).Trim() -split '\s+')[0].ToLower()
$have = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($want -ne $have) {
  Remove-Item $zip -Force -ErrorAction SilentlyContinue   # 깨진 조각이 남아 다음에 이어받기로 또 깨지지 않게
  Fail '내려받은 파일이 깨졌습니다(해시 불일치). 다시 실행하세요.'
}
Say '  해시 일치'

# 4) 풀기 — 새 폴더에 먼저 풀고, 다 풀린 뒤에만 바꿔치기한다(풀다 끊겨도 쓰던 것은 안 망가진다)
Say ''
Say '4/5 압축 푸는 중 (파일 3천 개 — 1~2분)...'
$new = "$Dir.new"; $old = "$Dir.old"
if (Test-Path $new) { Remove-Item $new -Recurse -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $new)
foreach ($need in @('부스시작.bat', 'runtime\node.exe', 'backend\server.js', 'frontend\dist\index.html', 'booth-version.txt')) {
  if (-not (Test-Path (Join-Path $new $need))) { Remove-Item $new -Recurse -Force; Fail "묶음이 온전하지 않습니다($need 없음). 다시 실행하세요." }
}

# 5) 바꿔치기 — 돌고 있는 부스 서버가 있으면 먼저 끈다(파일을 잡고 있어 이름을 못 바꾼다)
Say ''
Say '5/5 교체 중...'
$mirrored = $false
if (Test-Path $Dir) {
  # 부스 서버(node) 와 그것을 띄운 검은 창(cmd — 부스시작.bat) 둘 다 끈다.
  # ⚠️ 검은 창은 그 폴더 안(backend)에 「서 있어서」 서버만 꺼도 폴더 이름을 못 바꾼다.
  $running = @(Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Dir + '\', [StringComparison]::OrdinalIgnoreCase) })
  $shells  = @(Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine -match '부스시작' -and $_.ProcessId -ne $PID })
  if ($running -or $shells) {
    Say '  돌고 있는 부스 서버와 그 창을 끕니다.'
    $shells  | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $running | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  }
  if (Test-Path $old) { Remove-Item $old -Recurse -Force }
  # 이름 바꾸기 — 바이러스 검사·탐색기가 잠깐 잡고 있을 수 있어 몇 번 다시 해 본다
  $renamed = $false
  for ($try = 1; $try -le 8 -and -not $renamed; $try++) {
    try { Rename-Item -LiteralPath $Dir -NewName (Split-Path $old -Leaf) -ErrorAction Stop; $renamed = $true }
    catch { Start-Sleep -Seconds 1 }
  }
  if (-not $renamed) {
    # 끝내 안 되면(탐색기 창이 그 폴더를 열어 두었거나 다른 창이 서 있는 경우) 폴더는 두고 안의 내용을 새것으로 맞춘다.
    # robocopy /MIR = 새 폴더와 똑같이 되도록 덮어쓰고, 새 쪽에 없는 옛 파일은 지운다. (이 경우 이전 버전 사본은 남지 않는다)
    Say '  폴더 이름을 바꾸지 못해 내용을 덮어씁니다.'
    & robocopy.exe $new $Dir /MIR /R:3 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Fail '기존 폴더를 갱신하지 못했습니다. 그 폴더를 쓰는 창(탐색기·부스 서버 검은 창)을 모두 닫고 다시 실행하세요.' }
    $mirrored = $true
  }
}
if ($mirrored) { Remove-Item $new -Recurse -Force -ErrorAction SilentlyContinue }
else { Rename-Item -LiteralPath $new -NewName (Split-Path $Dir -Leaf) }
Remove-Item $zip -Force -ErrorAction SilentlyContinue

Say ''
Say '=================================================='
Say '  업데이트 완료'
Say "  버전: $remoteVer"
if (Test-Path $old) { Say "  (이전 버전은 $old 에 남겨 두었습니다 — 문제가 없으면 지워도 됩니다)" }
Say '=================================================='
Say ''
Say "부스를 시작하려면  $Dir\부스시작.bat  을 더블클릭하세요."
exit 0

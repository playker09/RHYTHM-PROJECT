# 개발용: 헤드리스 Chrome 으로 UI 스크린샷. 사용: shot.ps1 -Out a.png -Query "cur=12000&tab=check"
param([string]$Out, [string]$Query = "", [string]$Root = "C:\Users\ADMIN\Downloads\RHYTHM-PROJECT")
$tool = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP "pt_shot"
New-Item -ItemType Directory -Force $tmp | Out-Null
$p = Start-Process python -ArgumentList (Join-Path $tool 'launcher.py'), '--no-browser', '--port', '0', '--root', $Root `
    -RedirectStandardOutput "$tmp\srv.txt" -PassThru -WindowStyle Hidden
Start-Sleep 2
$url = (Get-Content "$tmp\srv.txt" -TotalCount 1)
if ($Query) { $url = $url + "&" + $Query }
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
Start-Process $chrome -ArgumentList '--headless=new', '--disable-gpu', "--user-data-dir=$tmp\prof", '--window-size=1500,900', `
    '--virtual-time-budget=8000', "--screenshot=$Out", $url -Wait -RedirectStandardError "$tmp\chrome_err.txt" | Out-Null
Stop-Process $p.Id -Force

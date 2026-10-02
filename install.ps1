#Requires -Version 5.1
<#
.SYNOPSIS
    Didban CCTV Monitoring - Automated Interactive Windows Installer & Updater
.DESCRIPTION
    Installs or updates the standalone Didban application from the official release repository.
    Configures secure password hashing, .env configuration, and auto-start background service.
.EXAMPLE
    irm https://raw.githubusercontent.com/mehdichamani/didban-release/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("install", "update", "")]
    [string]$Action = "",

    [Parameter(Position=1)]
    [string]$InstallPath = "C:\Didban"
)

# تنظیم انکودینگ کنسول به UTF-8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$RepoRelease = "mehdichamani/didban-release"
$LatestZipUrl = "https://github.com/$RepoRelease/releases/latest/download/didban-windows-x86_64.zip"

# متغیر سراسری زبان (پیش‌فرض: en)
$global:LangMode = "en"

function Select-Language {
    Write-Host "`n  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        🛡️ Didban CCTV Monitoring System / سامانه دیدبان       ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Write-Host "  Persian rendering check / بررسی خوانایی فونت فارسی:" -ForegroundColor White
    Write-Host "  [ متن آزمایشی فارسی: دیدبان سیستم نظارت ]`n" -ForegroundColor Yellow

    Write-Host "  Press [Enter] to continue in English (Recommended for Windows terminal / PuTTY)" -ForegroundColor Green
    Write-Host "  Or type [F] then Enter for Persian (فارسی)`n" -ForegroundColor Yellow

    $choice = Read-Host "  Choice / انتخاب [English]"
    if ($choice -match '^[Ff]') {
        $global:LangMode = "fa"
    } else {
        $global:LangMode = "en"
    }
}

function Write-Header {
    Write-Host "`n  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    if ($global:LangMode -eq "fa") {
        Write-Host "  ║        🛡️ سامانه پایش و مانیتورینگ دوربین دیدبان (Didban)     ║" -ForegroundColor Cyan
        Write-Host "  ║       اسکریپت نصب و به‌روزرسانی خودکار و هوشمند ویندوز        ║" -ForegroundColor Cyan
    } else {
        Write-Host "  ║             🛡️ Didban CCTV Monitoring System                  ║" -ForegroundColor Cyan
        Write-Host "  ║       Fast & Automated Windows Installer & Updater            ║" -ForegroundColor Cyan
    }
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
}

function Write-LogInfo ($en, $fa) {
    $msg = if ($global:LangMode -eq "fa" -and $fa) { $fa } else { $en }
    Write-Host "  ● [INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host $msg -ForegroundColor White
}

function Write-LogOk ($en, $fa) {
    $msg = if ($global:LangMode -eq "fa" -and $fa) { $fa } else { $en }
    Write-Host "  ✔ [OK]   " -NoNewline -ForegroundColor Green
    Write-Host $msg -ForegroundColor White
}

function Write-LogWarn ($en, $fa) {
    $msg = if ($global:LangMode -eq "fa" -and $fa) { $fa } else { $en }
    Write-Host "  ▲ [WARN] " -NoNewline -ForegroundColor Yellow
    Write-Host $msg -ForegroundColor White
}

function Write-LogErr ($en, $fa) {
    $msg = if ($global:LangMode -eq "fa" -and $fa) { $fa } else { $en }
    Write-Host "  ✖ [ERR]  " -NoNewline -ForegroundColor Red
    Write-Host $msg -ForegroundColor White
}

function Prompt-UserText ($promptEn, $promptFa, $defaultVal) {
    $prompt = if ($global:LangMode -eq "fa" -and $promptFa) { $promptFa } else { $promptEn }
    if ($defaultVal) {
        $ans = Read-Host "  ? $prompt [$defaultVal]"
        if ([string]::IsNullOrWhiteSpace($ans)) { return $defaultVal }
        return $ans.Trim()
    } else {
        $ans = Read-Host "  ? $prompt"
        return $ans.Trim()
    }
}

function Stop-DidbanProcesses ($targetDir) {
    Write-LogInfo "Stopping any running Didban processes..." "در حال متوقف‌سازی پروسه‌های قبلی دیدبان..."
    $procs = Get-Process -Name "main" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try {
            $pPath = $p.Path
            if ($pPath -like "*$targetDir*") {
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                Write-LogOk "Stopped process PID $($p.Id)" "پروسه متوقف شد (PID: $($p.Id))"
            }
        } catch {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Setup-WindowsStartup ($targetDir, $port) {
    Write-LogInfo "Configuring Windows Auto-Start Background Service..." "در حال تنظیم سرویس خودکار استارت‌آپ ویندوز..."
    try {
        $StartupFolder = [Environment]::GetFolderPath("Startup")
        $StartupShortcut = Join-Path $StartupFolder "Didban.lnk"

        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($StartupShortcut)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetDir\didban.ps1`" -Action start-bg -Port $port"
        $shortcut.WorkingDirectory = $targetDir
        $shortcut.Description = "Didban CCTV Monitoring Background Service"
        $shortcut.Save()

        Write-LogOk "Windows Auto-Start configured successfully." "سرویس استارت‌آپ ویندوز با موفقیت فعال گردید."
    } catch {
        Write-LogWarn "Failed to configure Windows Startup: $_" "خطا در تنظیم استارت‌آپ خودکار: $_"
    }
}

function Suggest-InstallFFmpeg ($targetDir) {
    Write-Host ""
    if ($global:LangMode -eq "fa") {
        Write-Host "  قابلیت جانبی: پخش زنده تصاویر (Live RTSP Stream via FFmpeg)" -ForegroundColor White
    } else {
        Write-Host "  Optional Feature: Live Video Streaming (Live RTSP Stream via FFmpeg)" -ForegroundColor White
    }

    $ffmpegCmd = Get-Command "ffmpeg" -ErrorAction SilentlyContinue
    $localFfmpeg = Join-Path $targetDir "ffmpeg.exe"
    if ($ffmpegCmd -or (Test-Path $localFfmpeg)) {
        Write-LogOk "FFmpeg detected on system (Live Stream capability is active)." "ابزار FFmpeg روی سیستم شناسایی شد (پخش زنده فعال است)."
        return
    }

    Write-LogWarn "FFmpeg is not installed or not in PATH." "ابزار FFmpeg شناسایی نشد."
    Write-LogInfo "Didban works 100% without FFmpeg (Monitoring, DB, Web UI, and Snapshots are active)." "سامانه بدون FFmpeg کاملاً کار می‌کند (پایش، دیتابیس، پنل وب و اسنپ‌شات‌ها فعالند)."
    Write-LogInfo "FFmpeg is only needed for live browser video streaming." "ابزار FFmpeg صرفاً جهت پخش زنده جریان دوربین‌ها در مرورگر نیاز است."

    $wantFfmpeg = Prompt-UserText "Install FFmpeg automatically? (y/n)" "آیا مایل به نصب خودکار ابزار FFmpeg هستید؟ (y/n)" "n"
    if ($wantFfmpeg -notmatch '^[Yy]') {
        Write-LogInfo "Skipped FFmpeg installation." "از نصب FFmpeg صرف‌نظر شد."
        return
    }

    $installed = $false
    # 1. winget
    $wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-LogInfo "Attempting install via Windows Package Manager (winget)..." "تلاش برای نصب سریع با winget..."
        try {
            $p = Start-Process -FilePath "winget" -ArgumentList "install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements" -NoNewWindow -Wait -PassThru
            if ($p.ExitCode -eq 0) {
                $installed = $true
                Write-LogOk "FFmpeg installed successfully via winget." "ابزار FFmpeg با موفقیت از طریق winget نصب شد."
            }
        } catch {
            Write-LogWarn "Winget install failed." "نصب از طریق winget ناموفق بود."
        }
    }

    # 2. choco
    if (-not $installed) {
        $chocoCmd = Get-Command "choco" -ErrorAction SilentlyContinue
        if ($chocoCmd) {
            Write-LogInfo "Attempting install via Chocolatey (choco)..." "تلاش برای نصب با Chocolatey..."
            try {
                $p = Start-Process -FilePath "choco" -ArgumentList "install ffmpeg -y" -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -eq 0) {
                    $installed = $true
                    Write-LogOk "FFmpeg installed successfully via Chocolatey." "ابزار FFmpeg با چاکلتی نصب شد."
                }
            } catch {
                Write-LogWarn "Chocolatey install failed." "نصب با choco ناموفق بود."
            }
        }
    }

    # 3. scoop
    if (-not $installed) {
        $scoopCmd = Get-Command "scoop" -ErrorAction SilentlyContinue
        if ($scoopCmd) {
            Write-LogInfo "Attempting install via Scoop..." "تلاش برای نصب با Scoop..."
            try {
                $p = Start-Process -FilePath "scoop" -ArgumentList "install ffmpeg" -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -eq 0) {
                    $installed = $true
                    Write-LogOk "FFmpeg installed successfully via Scoop." "ابزار FFmpeg با Scoop نصب شد."
                }
            } catch {
                Write-LogWarn "Scoop install failed." "نصب با Scoop ناموفق بود."
            }
        }
    }

    if (-not $installed) {
        Write-LogWarn "Automatic installation not available for this Windows environment." "امکان نصب خودکار در این نسخه ویندوز مهیا نبود."
        Write-LogInfo "For Windows Server or older Windows, download ffmpeg.exe manually:" "برای ویندوز سرور، می‌توانید فایل باینری را دستی دانلود فرمایید:"
        Write-Host "     🔗 FFmpeg Official Download: https://ffmpeg.org/download.html" -ForegroundColor Cyan
        Write-Host "     💡 Place ffmpeg.exe inside ($targetDir) or system PATH." -ForegroundColor Yellow
    }
}

function Generate-ManagerScripts ($targetDir, $defaultPort) {
    $ps1Content = @'
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("start", "start-bg", "stop", "restart", "status", "enable-startup", "disable-startup", "update", "")]
    [string]$Action = "status",

    [Parameter(Position=1)]
    [int]$Port = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

if ($Port -eq 0) {
    $Port = 23456
    if (Test-Path ".env") {
        $envLines = Get-Content ".env" -ErrorAction SilentlyContinue
        foreach ($line in $envLines) {
            if ($line -match '^\s*PORT\s*=\s*(\d+)') {
                $Port = [int]$matches[1]
                break
            }
        }
    }
}

$PidFile = Join-Path $ScriptDir "data\didban.pid"
$StartupFolder = [Environment]::GetFolderPath("Startup")
$StartupShortcut = Join-Path $StartupFolder "Didban.lnk"

function Write-Msg ($icon, $color, $en) {
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$en" -ForegroundColor White
}

function Get-DidbanProcess {
    if (Test-Path $PidFile) {
        $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($savedPid) {
            $p = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
            if ($p -and $p.Path -like "*$ScriptDir*") { return $p }
        }
    }
    $all = Get-Process -Name "main" -ErrorAction SilentlyContinue
    foreach ($p in $all) {
        if ($p.Path -like "*$ScriptDir*") { return $p }
    }
    return $null
}

function Start-Foreground {
    $p = Get-DidbanProcess
    if ($p) {
        Write-Msg "▲" "Yellow" "Didban is already running (PID $($p.Id))"
        return
    }
    & "$ScriptDir\main.exe"
}

function Start-Background {
    $p = Get-DidbanProcess
    if ($p) {
        Write-Msg "▲" "Yellow" "Didban is already running in background (PID $($p.Id))"
        return
    }
    if (-not (Test-Path "data")) { New-Item -ItemType Directory -Path "data" -Force | Out-Null }
    if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }

    $logOut = Join-Path $ScriptDir "logs\didban.out.log"
    $logErr = Join-Path $ScriptDir "logs\didban.err.log"

    $proc = Start-Process -FilePath "$ScriptDir\main.exe" -WorkingDirectory $ScriptDir -WindowStyle Hidden -RedirectStandardOutput $logOut -RedirectStandardError $logErr -PassThru
    if ($proc -and -not $proc.HasExited) {
        $proc.Id | Out-File -FilePath $PidFile -Encoding utf8
        Write-Msg "✔" "Green" "Didban started in background (PID $($proc.Id))"
        Write-Host "  Panel URL: http://localhost:$Port" -ForegroundColor Cyan
    } else {
        Write-Msg "✖" "Red" "Failed to start Didban background process"
    }
}

function Stop-Background {
    $p = Get-DidbanProcess
    if ($p) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Msg "✔" "Green" "Didban service stopped (PID $($p.Id))"
    } else {
        Write-Msg "●" "Yellow" "Didban is not running"
    }
    if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
}

function Get-Status {
    $p = Get-DidbanProcess
    $auto = Test-Path $StartupShortcut
    Write-Host "`n  ╔════ Didban Service Status ═══════════════════════════════════╗" -ForegroundColor Green
    if ($p) {
        Write-Host "  ║  Service State: RUNNING (PID: $($p.Id))" -ForegroundColor Green
    } else {
        Write-Host "  ║  Service State: STOPPED" -ForegroundColor Red
    }
    Write-Host "  ║  Panel URL:     http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "  ║  Auto-Start:    $($auto ? 'ENABLED' : 'DISABLED')" -ForegroundColor ($auto ? 'Green' : 'DarkGray')
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
}

function Enable-AutoStart {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($StartupShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptDir\didban.ps1`" -Action start-bg -Port $Port"
    $shortcut.WorkingDirectory = $ScriptDir
    $shortcut.Description = "Didban CCTV Monitoring Background Service"
    $shortcut.Save()
    Write-Msg "✔" "Green" "Auto-Start enabled"
}

function Disable-AutoStart {
    if (Test-Path $StartupShortcut) {
        Remove-Item $StartupShortcut -Force
        Write-Msg "✔" "Green" "Auto-Start disabled"
    } else {
        Write-Msg "●" "Yellow" "Auto-Start was not enabled"
    }
}

switch ($Action) {
    "start"          { Start-Foreground }
    "start-bg"       { Start-Background }
    "stop"           { Stop-Background }
    "restart"        { Stop-Background; Start-Sleep -Seconds 1; Start-Background }
    "status"         { Get-Status }
    "enable-startup" { Enable-AutoStart }
    "disable-startup"{ Disable-AutoStart }
    "update"         {
        irm https://raw.githubusercontent.com/mehdichamani/didban-release/main/install.ps1 | iex
    }
    default {
        Get-Status
        Write-Host "Usage: .\didban.ps1 [start | start-bg | stop | restart | status | enable-startup | disable-startup | update]" -ForegroundColor Yellow
    }
}
'@

    Set-Content -Path (Join-Path $targetDir "didban.ps1") -Value $ps1Content -Encoding UTF8

    $batContent = @"
@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0didban.ps1" %*
"@
    Set-Content -Path (Join-Path $targetDir "didban.bat") -Value $batContent -Encoding UTF8
    Write-LogOk "Manager scripts (didban.ps1 / didban.bat) generated." "اسکریپت‌های مدیریت و راه‌اندازی سریع ایجاد شدند."
}

function Update-Didban ($targetDir) {
    Write-LogInfo "Starting Didban update routine..." "شروع عملیات به‌روزرسانی سامانه دیدبان..."
    Stop-DidbanProcesses $targetDir

    $tempZip = Join-Path $env:TEMP "didban-windows-update.zip"
    $tempDir = Join-Path $env:TEMP "didban-extract-$([Guid]::NewGuid().ToString().Substring(0,8))"

    try {
        Write-LogInfo "Downloading latest release package..." "در حال دریافت آخرین نسخه پکیج دیدبان..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $LatestZipUrl -OutFile $tempZip -UseBasicParsing

        Write-LogInfo "Extracting update bundle..." "در حال استخراج بسته جدید..."
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

        Get-ChildItem -Path $tempDir | ForEach-Object {
            if ($_.Name -ne ".env" -and $_.Name -ne "data" -and $_.Name -ne "monitor.db") {
                Copy-Item -Path $_.FullName -Destination $targetDir -Recurse -Force
            }
        }

        Generate-ManagerScripts $targetDir 23456
        Write-LogOk "Update completed successfully! 🎉" "سامانه دیدبان با موفقیت به آخرین نسخه به‌روزرسانی شد!"

        & (Join-Path $targetDir "didban.ps1") -Action start-bg
    } catch {
        Write-LogErr "Update failed: $_" "خطا در به‌روزرسانی سامانه: $_"
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Install-Didban {
    Select-Language
    Write-Header

    $defaultPath = $InstallPath
    if ($global:LangMode -eq "fa") {
        Write-Host "  مرحله ۱: تعیین مسیر نصب سامانه" -ForegroundColor White
    } else {
        Write-Host "  Step 1: Installation Directory" -ForegroundColor White
    }

    $targetDir = Prompt-UserText "Enter installation path" "مسیر نصب برنامه را وارد فرمایید" $defaultPath
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if (Test-Path (Join-Path $targetDir "main.exe")) {
        Write-Host ""
        Write-LogWarn "Didban is already installed in this directory." "سامانه دیدبان پیش‌تر در این مسیر نصب شده است."
        $doUpdate = Prompt-UserText "Update existing installation to latest version? (y/n)" "آیا می‌خواهید سامانه را به آخرین نسخه به‌روزرسانی (Update) کنید؟ (y/n)" "y"
        if ($doUpdate -match '^[Yy]') {
            Update-Didban $targetDir
            return
        }
    }

    Write-Host ""
    if ($global:LangMode -eq "fa") {
        Write-Host "  مرحله ۲: دانلود و استخراج بسته دیدبان" -ForegroundColor White
    } else {
        Write-Host "  Step 2: Download & Extract Package" -ForegroundColor White
    }

    $tempZip = Join-Path $env:TEMP "didban-windows-x86_64.zip"
    try {
        Write-LogInfo "Downloading official Windows standalone package..." "در حال دانلود بسته رسمی ویندوز..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $LatestZipUrl -OutFile $tempZip -UseBasicParsing
        Write-LogOk "Download completed." "دانلود با موفقیت انجام شد."

        Write-LogInfo "Extracting files to $targetDir..." "در حال استخراج فایل‌ها..."
        Expand-Archive -Path $tempZip -DestinationPath $targetDir -Force
        Write-LogOk "Extraction completed." "فایل‌ها با موفقیت استخراج شدند."
    } catch {
        Write-LogErr "Failed to download or extract package: $_" "خطا در دانلود یا استخراج بسته: $_"
        return
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    }

    $dataDir = Join-Path $targetDir "data"
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }

    Write-Host ""
    if ($global:LangMode -eq "fa") {
        Write-Host "  مرحله ۳: پیکربندی امنیتی و تعیین حساب مدیر" -ForegroundColor White
    } else {
        Write-Host "  Step 3: Security & Administrator Credentials" -ForegroundColor White
    }

    $adminUser = Prompt-UserText "Admin username" "نام کاربری مدیر سیستم" "admin"
    $webPort = Prompt-UserText "Web service port" "پورت سرویس وب دیدبان" "23456"

    $plainPass = ""
    while ($true) {
        $p1Msg = if ($global:LangMode -eq "fa") { "  🔒 کلمه عبور دلخواه مدیر را وارد فرمایید" } else { "  🔒 Enter admin password" }
        $p2Msg = if ($global:LangMode -eq "fa") { "  🔒 کلمه عبور را مجدداً تکرار فرمایید" } else { "  🔒 Confirm admin password" }

        $secPass1 = Read-Host $p1Msg -AsSecureString
        $secPass2 = Read-Host $p2Msg -AsSecureString

        $pass1 = [System.Net.NetworkCredential]::new("", $secPass1).Password
        $pass2 = [System.Net.NetworkCredential]::new("", $secPass2).Password

        if ([string]::IsNullOrWhiteSpace($pass1)) {
            Write-LogErr "Password cannot be empty!" "کلمه عبور نمی‌تواند خالی باشد!"
            continue
        }
        if ($pass1 -ne $pass2) {
            Write-LogErr "Passwords do not match. Please try again." "کلمه‌های عبور یکسان نیستند. دوباره امتحان کنید."
            continue
        }
        $plainPass = $pass1
        break
    }

    Write-LogInfo "Generating secure password hash via Didban core engine..." "تولید هش امن کلمه عبور با موتور برنامه..."
    $mainExe = Join-Path $targetDir "main.exe"
    $hashVal = ""

    if (Test-Path $mainExe) {
        try {
            $outLines = & $mainExe --hash-password "$plainPass"
            foreach ($line in $outLines) {
                if ($line -match '^\s*ADMIN_PASS\s*=\s*(.+)') {
                    $hashVal = $matches[1].Trim()
                    break
                }
            }
        } catch {
            Write-LogWarn "Could not run main.exe directly: $_" "اجرای مستقیم باینری مقدور نبود: $_"
        }
    }

    if ([string]::IsNullOrWhiteSpace($hashVal)) {
        Write-LogWarn "Using plain password in .env (hashed mode recommended)." "هش تولید نشد؛ از رمز مستقیم استفاده می‌گردد."
        $hashVal = $plainPass
    } else {
        Write-LogOk "Secure password hash generated." "هش امن با موفقیت ایجاد گردید."
    }

    $envContent = @"
ADMIN_USER=$adminUser
ADMIN_PASS=$hashVal
PORT=$webPort
HOST=0.0.0.0
"@
    Set-Content -Path (Join-Path $targetDir ".env") -Value $envContent -Encoding UTF8
    Write-LogOk "Configuration file (.env) saved." "فایل تنظیمات ذخیره شد."

    Generate-ManagerScripts $targetDir $webPort
    Suggest-InstallFFmpeg $targetDir

    Write-Host ""
    if ($global:LangMode -eq "fa") {
        Write-Host "  مرحله ۴: سرویس پس‌زمینه و راه‌اندازی خودکار" -ForegroundColor White
    } else {
        Write-Host "  Step 4: Background Service & Auto-Start" -ForegroundColor White
    }

    $enableStartup = Prompt-UserText "Enable auto-start on Windows boot? (y/n)" "آیا مایل به اجرای خودکار در هنگام روشن شدن ویندوز هستید؟ (y/n)" "y"
    if ($enableStartup -match '^[Yy]') {
        Setup-WindowsStartup $targetDir $webPort
    }

    & (Join-Path $targetDir "didban.ps1") -Action start-bg -Port [int]$webPort
    Start-Process "http://localhost:$webPort"

    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    if ($global:LangMode -eq "fa") {
        Write-Host "  🎉 نصب و راه‌اندازی سامانه دیدبان با موفقیت به پایان رسید!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Green
        Write-Host "  🌐 آدرس پنل تحت وب: http://localhost:$webPort" -ForegroundColor Cyan
        Write-Host "  👤 نام کاربری مدیر: $adminUser" -ForegroundColor Yellow
        Write-Host "  📁 مسیر برنامه:     $targetDir" -ForegroundColor White
        Write-Host "`n  ⚙️ مدیریت سامانه با دستورات زیر در خط فرمان یا پاورشل:" -ForegroundColor DarkCyan
        Write-Host "     .\didban.bat status          نمایش وضعیت سرویس" -ForegroundColor Gray
        Write-Host "     .\didban.bat stop            توقف سرویس پس‌زمینه" -ForegroundColor Gray
        Write-Host "     .\didban.bat start-bg        اجرای مجدد در پس‌زمینه" -ForegroundColor Gray
        Write-Host "     .\didban.bat update          به‌روزرسانی به آخرین نسخه" -ForegroundColor Gray
    } else {
        Write-Host "  🎉 Didban setup completed successfully!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Green
        Write-Host "  🌐 Web Dashboard: http://localhost:$webPort" -ForegroundColor Cyan
        Write-Host "  👤 Admin User:    $adminUser" -ForegroundColor Yellow
        Write-Host "  📁 Install Dir:   $targetDir" -ForegroundColor White
        Write-Host "`n  ⚙️ Service Management Commands (CMD or PowerShell):" -ForegroundColor DarkCyan
        Write-Host "     .\didban.bat status          Check service status" -ForegroundColor Gray
        Write-Host "     .\didban.bat stop            Stop background service" -ForegroundColor Gray
        Write-Host "     .\didban.bat start-bg        Start in background" -ForegroundColor Gray
        Write-Host "     .\didban.bat update          Update to latest release" -ForegroundColor Gray
    }
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Green
}

if ($Action -eq "update") {
    Update-Didban $InstallPath
} else {
    Install-Didban
}

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

# تنظیم انکودینگ خروجی ترمینال به UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRelease = "mehdichamani/didban-release"
$LatestZipUrl = "https://github.com/$RepoRelease/releases/latest/download/didban-windows-x86_64.zip"

function Write-Header {
    Write-Host "`n  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        🛡️ سامانه پایش و مانیتورینگ دوربین دیدبان (Didban)     ║" -ForegroundColor Cyan
    Write-Host "  ║       اسکریپت نصب و به‌روزرسانی خودکار و هوشمند ویندوز        ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
}

function Write-LogInfo ($en, $fa) {
    Write-Host "  ● [INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host "$en " -NoNewline -ForegroundColor White
    if ($fa) { Write-Host "│ $fa" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Write-LogOk ($en, $fa) {
    Write-Host "  ✔ [OK]   " -NoNewline -ForegroundColor Green
    Write-Host "$en " -NoNewline -ForegroundColor White
    if ($fa) { Write-Host "│ $fa" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Write-LogWarn ($en, $fa) {
    Write-Host "  ▲ [WARN] " -NoNewline -ForegroundColor Yellow
    Write-Host "$en " -NoNewline -ForegroundColor White
    if ($fa) { Write-Host "│ $fa" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Write-LogErr ($en, $fa) {
    Write-Host "  ✖ [ERR]  " -NoNewline -ForegroundColor Red
    Write-Host "$en " -NoNewline -ForegroundColor White
    if ($fa) { Write-Host "│ $fa" -ForegroundColor DarkGray } else { Write-Host "" }
}

# دریافت ورودی تعاملی با مقدار پیش‌فرض
function Prompt-UserText ($prompt, $defaultVal) {
    if ($defaultVal) {
        $ans = Read-Host "  ? $prompt [$defaultVal]"
        if ([string]::IsNullOrWhiteSpace($ans)) { return $defaultVal }
        return $ans.Trim()
    } else {
        $ans = Read-Host "  ? $prompt"
        return $ans.Trim()
    }
}

# توقف تمام پروسه‌های دیدبان در حال اجرا در ویندوز
function Stop-DidbanProcesses ($targetDir) {
    Write-LogInfo "Stopping any running Didban processes..." "در حال متوقف‌سازی پروسه‌های قبلی دیدبان..."
    $procs = Get-Process -Name "main" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try {
            $pPath = $p.Path
            if ($pPath -like "*$targetDir*") {
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                Write-LogOk "Stopped process PID $($p.Id)" "پروسه متوقف شد"
            }
        } catch {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

# تنظیم سرویس پس‌زمینه استارت‌آپ ویندوز (روش تست‌شده start.ps1)
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

        Write-LogOk "Windows Auto-Start configured successfully." "سرویس استارت‌آپ ویندوز فعال گردید."
    } catch {
        Write-LogWarn "Failed to configure Windows Startup: $_" "خطا در تنظیم استارت‌آپ خودکار"
    }
}

# ساخت اسکریپت کنترل دیدبان در پوشه نصب (didban.ps1 و didban.bat)
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

function Write-Msg ($icon, $color, $en, $fa) {
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$en " -NoNewline -ForegroundColor White
    if ($fa) { Write-Host "│ $fa" -ForegroundColor DarkGray } else { Write-Host "" }
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
        Write-Msg "▲" "Yellow" "Didban is already running (PID $($p.Id))" "دیدبان در حال اجراست"
        return
    }
    & "$ScriptDir\main.exe"
}

function Start-Background {
    $p = Get-DidbanProcess
    if ($p) {
        Write-Msg "▲" "Yellow" "Didban is already running (PID $($p.Id))" "دیدبان قبلاً در پس‌زمینه اجرا شده است"
        return
    }
    if (-not (Test-Path "data")) { New-Item -ItemType Directory -Path "data" -Force | Out-Null }
    if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }

    $logOut = Join-Path $ScriptDir "logs\didban.out.log"
    $logErr = Join-Path $ScriptDir "logs\didban.err.log"

    $proc = Start-Process -FilePath "$ScriptDir\main.exe" -WorkingDirectory $ScriptDir -WindowStyle Hidden -RedirectStandardOutput $logOut -RedirectStandardError $logErr -PassThru
    if ($proc -and -not $proc.HasExited) {
        $proc.Id | Out-File -FilePath $PidFile -Encoding utf8
        Write-Msg "✔" "Green" "Didban started in background (PID $($proc.Id))" "سرویس پس‌زمینه با موفقیت اجرا شد"
        Write-Host "  Panel URL: http://localhost:$Port" -ForegroundColor Cyan
    } else {
        Write-Msg "✖" "Red" "Failed to start Didban background process" "خطا در اجرای پروسه پس‌زمینه"
    }
}

function Stop-Background {
    $p = Get-DidbanProcess
    if ($p) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Msg "✔" "Green" "Didban service stopped (PID $($p.Id))" "سرویس دیدبان متوقف شد"
    } else {
        Write-Msg "●" "Yellow" "Didban is not running" "هیچ پروسه فعالی از دیدبان یافت نشد"
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
    Write-Msg "✔" "Green" "Auto-Start enabled" "اجرای خودکار فعال شد"
}

function Disable-AutoStart {
    if (Test-Path $StartupShortcut) {
        Remove-Item $StartupShortcut -Force
        Write-Msg "✔" "Green" "Auto-Start disabled" "اجرای خودکار غیرفعال شد"
    } else {
        Write-Msg "●" "Yellow" "Auto-Start was not enabled" "استارت‌آپ فعال نبود"
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

# تابع به‌روزرسانی سامانه به آخرین نسخه
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

        # کپی فایل‌های اجرایی به مسیر نصب (بدون دست‌زدن به .env و data\)
        Get-ChildItem -Path $tempDir | ForEach-Object {
            if ($_.Name -ne ".env" -and $_.Name -ne "data" -and $_.Name -ne "monitor.db") {
                Copy-Item -Path $_.FullName -Destination $targetDir -Recurse -Force
            }
        }

        # بازتولید اسکریپت‌های منیجر
        Generate-ManagerScripts $targetDir 23456

        Write-LogOk "Update completed successfully! 🎉" "سامانه دیدبان با موفقیت به آخرین نسخه به‌روزرسانی شد!"

        # راه‌اندازی مجدد در پس‌زمینه
        & (Join-Path $targetDir "didban.ps1") -Action start-bg
    } catch {
        Write-LogErr "Update failed: $_" "خطا در به‌روزرسانی سامانه"
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# تابع اصلی نصب
function Install-Didban {
    Write-Header

    $defaultPath = $InstallPath
    Write-Host "  مرحله ۱: تعیین مسیر نصب سامانه" -ForegroundColor White
    $targetDir = Prompt-UserText "مسیر نصب برنامه را وارد فرمایید" $defaultPath

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # بررسی اینکه آیا دیدبان قبلاً نصب شده است
    if (Test-Path (Join-Path $targetDir "main.exe")) {
        Write-Host ""
        Write-LogWarn "Didban is already installed in this directory." "سامانه دیدبان پیش‌تر در این مسیر نصب شده است."
        $doUpdate = Prompt-UserText "آیا می‌خواهید سامانه را به آخرین نسخه به‌روزرسانی (Update) کنید؟ (y/n)" "y"
        if ($doUpdate -match '^[Yy]') {
            Update-Didban $targetDir
            return
        }
    }

    Write-Host "`n  مرحله ۲: دانلود و استخراج بسته دیدبان" -ForegroundColor White
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
        Write-LogErr "Failed to download or extract package: $_" "خطا در دانلود یا استخراج بسته"
        return
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    }

    # ایجاد پوشه data
    $dataDir = Join-Path $targetDir "data"
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }

    Write-Host "`n  مرحله ۳: پیکربندی امنیتی و تعیین حساب مدیر" -ForegroundColor White
    $adminUser = Prompt-UserText "نام کاربری مدیر سیستم" "admin"
    $webPort = Prompt-UserText "پورت سرویس وب دیدبان" "23456"

    $plainPass = ""
    while ($true) {
        $secPass1 = Read-Host "  🔒 کلمه عبور دلخواه مدیر را وارد فرمایید" -AsSecureString
        $secPass2 = Read-Host "  🔒 کلمه عبور را مجدداً تکرار فرمایید" -AsSecureString

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

    Write-LogInfo "Generating secure password hash using Didban core engine..." "تولید هش امن کلمه عبور با موتور برنامه..."
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
            Write-LogWarn "Could not run main.exe directly: $_" "اجرای مستقیم باینری مقدور نبود."
        }
    }

    if ([string]::IsNullOrWhiteSpace($hashVal)) {
        Write-LogWarn "Using plain password in .env (hashed mode recommended)." "هش تولید نشد؛ از رمز مستقیم استفاده می‌گردد."
        $hashVal = $plainPass
    } else {
        Write-LogOk "Secure password hash generated." "هش امن با موفقیت ایجاد گردید."
    }

    # ایجاد فایل .env
    $envContent = @"
ADMIN_USER=$adminUser
ADMIN_PASS=$hashVal
PORT=$webPort
HOST=0.0.0.0
"@
    Set-Content -Path (Join-Path $targetDir ".env") -Value $envContent -Encoding UTF8
    Write-LogOk "Configuration file (.env) saved." "فایل تنظیمات ذخیره شد."

    # ساخت فایل‌های مدیریتی
    Generate-ManagerScripts $targetDir $webPort

    Write-Host "`n  مرحله ۴: سرویس پس‌زمینه و راه‌اندازی خودکار" -ForegroundColor White
    $enableStartup = Prompt-UserText "آیا مایل به اجرای خودکار در هنگام روشن شدن ویندوز هستید؟ (y/n)" "y"
    if ($enableStartup -match '^[Yy]') {
        Setup-WindowsStartup $targetDir $webPort
    }

    # شروع آنی سرویس پس‌زمینه
    & (Join-Path $targetDir "didban.ps1") -Action start-bg -Port [int]$webPort

    # باز کردن مرورگر
    Start-Process "http://localhost:$webPort"

    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Green
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
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Green
}

if ($Action -eq "update") {
    Update-Didban $InstallPath
} else {
    Install-Didban
}

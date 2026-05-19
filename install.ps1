
<#
.SYNOPSIS
    SmartGpuPref v1.0 Interactive Installer
.DESCRIPTION
    Guides user through setup choices, then downloads and configures SmartGpuPref.
    Creates scheduled tasks for login + weekly sync. Requires Administrator.
.LINK
    https://github.com/BibekG1/SmartGpuPref
#>

[CmdletBinding()]
param(
    [string]$RepoOwner = "BibekG1",
    [string]$RepoName  = "SmartGpuPref",
    [string]$Branch    = "main",
    [string]$InstallPath = "C:\Scripts\SmartGpuPref"
)

# === 🔐 Admin Check ===
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Please run as Administrator." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# === 🎮 Interactive Setup Questions ===
Write-Host "`n🎮 SmartGpuPref v1.0 Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Question 1: Scope
Write-Host "`n📍 Scope: Where to apply GPU preferences?" -ForegroundColor Yellow
Write-Host "  [1] Current user only (HKCU) — affects only your account" -ForegroundColor Gray
Write-Host "  [2] All users (HKLM + HKCU) — affects every account on this PC" -ForegroundColor Gray
$scopeChoice = Read-Host "Enter choice (1-2, default=1)"
$scope = if ($scopeChoice -eq "2") { "AllUsers" } else { "CurrentUser" }
Write-Host "✅ Selected: $scope" -ForegroundColor Green

# Question 2: Inclusion Level
Write-Host "`n📦 Process inclusion: Which apps to configure?" -ForegroundColor Yellow
Write-Host "  [1] Apps only — Win32 + UWP apps (safest, fastest)" -ForegroundColor Gray
Write-Host "  [2] Apps + Services — adds Windows services (more coverage)" -ForegroundColor Gray
Write-Host "  [3] Everything — includes system processes (maximum coverage, your original intent)" -ForegroundColor Gray
$inclusionChoice = Read-Host "Enter choice (1-3, default=3)"
$inclusionLevel = if ($inclusionChoice -match '^[1-3]$') { [int]$inclusionChoice } else { 3 }
Write-Host "✅ Selected: Level $inclusionLevel" -ForegroundColor Green

# Question 3: GPU Preference
Write-Host "`n⚡ GPU preference: Which performance mode?" -ForegroundColor Yellow
Write-Host "  [1] Power saving — use integrated GPU when possible" -ForegroundColor Gray
Write-Host "  [2] High performance — use dedicated GPU (recommended for CPU-heavy apps)" -ForegroundColor Gray
$prefChoice = Read-Host "Enter choice (1-2, default=2)"
$preference = if ($prefChoice -eq "1") { 1 } else { 2 }
Write-Host "✅ Selected: $(if($preference -eq 1){'Power saving'}else{'High performance'})" -ForegroundColor Green

# === 🌐 GitHub URL ===
$scriptUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/src/SmartGpuPref.ps1"
$scriptPath = Join-Path $InstallPath "SmartGpuPref.ps1"

# === 📥 Download Core Script ===
Write-Host "`n📥 Downloading SmartGpuPref v1.0..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Script downloaded: $scriptPath" -ForegroundColor Green
} catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# === ⚙️ Execution Policy ===
$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($policy -match 'Restricted|AllSigned') {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
}

# === 🗓️ Create Scheduled Tasks ===
Write-Host "`n🗓️ Creating Task Scheduler tasks..." -ForegroundColor Cyan
try {
    # Clean up existing
    Get-ScheduledTask -TaskName "SmartGpuPref" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    Get-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

    # Build argument string with user choices
    $args = "-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`" -Scope $scope -InclusionLevel $inclusionLevel -Preference $preference"

    # Task 1: Run at login (+2 min delay)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args
    $trigger1 = New-ScheduledTaskTrigger -AtLogOn
    $trigger1.Delay = "PT2M"
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 0)

    Register-ScheduledTask -TaskName "SmartGpuPref" -Action $action -Trigger $trigger1 -Principal $principal -Settings $settings -Force -ErrorAction Stop

    # Task 2: Weekly sync (Sundays @ 3 AM)
    $trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    Register-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -Action $action -Trigger $trigger2 -Principal $principal -Settings $settings -Force -ErrorAction Stop

    # Verify
    Start-Sleep 2
    $t1 = Get-ScheduledTask -TaskName "SmartGpuPref" -ErrorAction SilentlyContinue
    $t2 = Get-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -ErrorAction SilentlyContinue
    if ($t1.State -eq 'Ready' -and $t2.State -eq 'Ready') {
        Write-Host "✅ Both tasks registered and ready!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Task states: Login=$($t1.State), Weekly=$($t2.State)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Task creation failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# === ✅ Success Summary ===
Write-Host "`n🎉 Installation complete!" -ForegroundColor Green
Write-Host "📝 Logs: %TEMP%\SmartGpuPref.log" -ForegroundColor Gray
Write-Host "🔄 Runs at login + every Sunday 3 AM to catch new apps" -ForegroundColor Gray
Write-Host "⚙️  Your choices:" -ForegroundColor Cyan
Write-Host "   • Scope: $scope" -ForegroundColor Gray
Write-Host "   • Inclusion: Level $inclusionLevel" -ForegroundColor Gray
Write-Host "   • GPU Preference: $(if($preference -eq 1){'Power saving'}else{'High performance'})" -ForegroundColor Gray
Write-Host "`n💡 To reconfigure: Re-run this installer or edit $scriptPath manually" -ForegroundColor Gray
Read-Host "Press Enter to exit"

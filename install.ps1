<#
.SYNOPSIS
    SmartGpuPref v1.0 Interactive Installer
.DESCRIPTION
    Guides user through setup, runs visible initial scan, then creates hidden scheduled tasks for weekly sync.
    Requires Administrator.
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

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Please run as Administrator." -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1
}

Write-Host "`n🎮 SmartGpuPref v1.0 Setup" -ForegroundColor Cyan; Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

$scopeChoice = Read-Host "`n📍 Scope: [1] Current user | [2] All users (default=1)"
$scope = if ($scopeChoice -eq "2") { "AllUsers" } else { "CurrentUser" }

$inclusionChoice = Read-Host "📦 Inclusion: [1] Apps only | [2] Apps+Services | [3] Everything (default=3)"
$inclusionLevel = if ($inclusionChoice -match '^[1-3]$') { [int]$inclusionChoice } else { 3 }

$prefChoice = Read-Host "⚡ GPU Mode: [1] Power saving | [2] High performance (default=2)"
$preference = if ($prefChoice -eq "1") { 1 } else { 2 }

Write-Host "`n✅ Choices: Scope=$scope | Level=$inclusionLevel | Mode=$(if($preference -eq 1){'Power saving'}else{'High performance'})" -ForegroundColor Green

$scriptUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/src/SmartGpuPref.ps1"
$scriptPath = Join-Path $InstallPath "SmartGpuPref.ps1"

Write-Host "`n📥 Downloading SmartGpuPref..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Script downloaded" -ForegroundColor Green
} catch { Write-Host "❌ Download failed: $_" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($policy -match 'Restricted|AllSigned') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue }

Write-Host "`n🔍 Running initial scan (this will show on screen)..." -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Scope $scope -InclusionLevel $inclusionLevel -Preference $preference -Verbose

Write-Host "`n🗓️ Creating background sync tasks (hidden)..." -ForegroundColor Cyan
try {
    Get-ScheduledTask -TaskName "SmartGpuPref*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    
    $args = "-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`" -Scope $scope -InclusionLevel $inclusionLevel -Preference $preference"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args
    $trigger1 = New-ScheduledTaskTrigger -AtLogOn; $trigger1.Delay = "PT2M"
    $trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
    
    Register-ScheduledTask -TaskName "SmartGpuPref" -Action $action -Trigger $trigger1 -Principal $principal -Settings $settings -Force -ErrorAction Stop
    Register-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -Action $action -Trigger $trigger2 -Principal $principal -Settings $settings -Force -ErrorAction Stop
    Write-Host "✅ Tasks created" -ForegroundColor Green
} catch { Write-Host "❌ Task creation failed: $_" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

Write-Host "`n📊 VERIFICATION:" -ForegroundColor Cyan
Write-Host "• GUI: Settings > System > Display > Graphics > Scroll down to see apps" -ForegroundColor Gray
Write-Host "• PS: Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' | Format-Table Name, GpuPreference" -ForegroundColor Gray
Write-Host "• Log: notepad `"$env:TEMP\SmartGpuPref.log`"" -ForegroundColor Gray
Write-Host "`n🎉 Installation complete! Background sync runs Sundays @ 3 AM." -ForegroundColor Green
Read-Host "Press Enter to exit"

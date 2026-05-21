param(
    [string]$RepoOwner = "BibekG1",
    [string]$RepoName  = "SmartGpuPref",
    [string]$Branch    = "main",
    [string]$InstallPath = "C:\Scripts\SmartGpuPref"
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Please run as Administrator. Right-click PowerShell -> Run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n=== SmartGpuPref v1.2 Setup ===" -ForegroundColor Cyan
$scopeChoice = Read-Host "`n[1] Current User | [2] All Users (default=1)"
$scope = if ($scopeChoice -eq "2") { "AllUsers" } else { "CurrentUser" }

$inclusionChoice = Read-Host "[1] Apps only | [2] Apps+Services | [3] Everything (default=3)"
$inclusionLevel = if ($inclusionChoice -match '^[1-3]$') { [int]$inclusionChoice } else { 3 }

$prefChoice = Read-Host "[1] Power saving | [2] High performance (default=2)"
$preference = if ($prefChoice -eq "1") { 1 } else { 2 }

Write-Host "`n[INFO] Choices: Scope=$scope | Level=$inclusionLevel | Mode=$(if($preference -eq 1){'Power saving'}else{'High performance'})" -ForegroundColor Green

$scriptUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/src/SmartGpuPref.ps1"
$scriptPath = Join-Path $InstallPath "SmartGpuPref.ps1"

Write-Host "`n[INFO] Downloading core script..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] Downloaded to $scriptPath" -ForegroundColor Green
} catch { Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red; exit 1 }

$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($policy -match 'Restricted|AllSigned') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue }

Write-Host "`n[RUNNING] Initial scan (showing all output)..." -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Scope $scope -InclusionLevel $inclusionLevel -Preference $preference

Write-Host "`n[SETUP] Creating background sync tasks (hidden)..." -ForegroundColor Cyan
try {
    # Explicitly unregister both tasks to avoid wildcard issues
    Get-ScheduledTask -TaskName "SmartGpuPref" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    Get-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    
    # Create a tiny VBScript launcher to launch powershell.exe completely silent with SW_HIDE (0)
    $launcherPath = Join-Path $InstallPath "SmartGpuPref_Launcher.vbs"
    $vbsContent = @"
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$scriptPath"" -Scope $scope -InclusionLevel $inclusionLevel -Preference $preference", 0, False
"@
    Set-Content -Path $launcherPath -Value $vbsContent -Force -Encoding ASCII
    
    # Scheduled Task executes wscript.exe (GUI application, spawns no console) with the launcher argument
    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$launcherPath`""
    $trigger1 = New-ScheduledTaskTrigger -AtLogOn; $trigger1.Delay = "PT2M"
    $trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
    
    Register-ScheduledTask -TaskName "SmartGpuPref" -Action $action -Trigger $trigger1 -Principal $principal -Settings $settings -Force -ErrorAction Stop
    Register-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -Action $action -Trigger $trigger2 -Principal $principal -Settings $settings -Force -ErrorAction Stop
    Write-Host "[OK] Scheduled tasks created." -ForegroundColor Green
} catch { Write-Host "[ERROR] Task creation failed: $_" -ForegroundColor Red; exit 1 }

Write-Host "`n=== INSTALLATION COMPLETE ===" -ForegroundColor Green
Write-Host "Logs saved to: $env:TEMP\SmartGpuPref.log" -ForegroundColor Gray
Write-Host "Verify in: Settings > System > Display > Graphics" -ForegroundColor Gray
Read-Host "Press Enter to exit"

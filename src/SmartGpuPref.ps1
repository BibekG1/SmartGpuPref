# SmartGpuPref v1.1 - Auto-configure Windows Graphics GPU preference
# Based on your original logic + enhanced with parameters and reliable logging.
# NO EMOJIS INSIDE STRINGS to prevent PowerShell parser corruption.

[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser",
    [ValidateSet(1,2,3)]
    [int]$InclusionLevel = 3,
    [ValidateSet(1,2)]
    [int]$Preference = 2,
    [string]$LogFile = "$env:TEMP\SmartGpuPref.log",
    [switch]$DryRun,
    [switch]$Verbose
)

# Reliable logging function
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Type] $Message"
    try { Add-Content -Path $LogFile -Value $line -ErrorAction Stop } catch {}
    # Always print to console so you can see exactly what's happening
    Write-Host "[$Type] $Message"
}

# Core function: Add or skip GPU preference
function Add-GpuPreference {
    param(
        [string]$AppPath,
        [int]$Preference = 2,
        [string]$Scope = "CurrentUser"
    )
    if ($Scope -eq "AllUsers") {
        $regKey = "HKLM:\Software\Microsoft\DirectX\UserGpuPreferences"
    } else {
        $regKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    }
    $value = "GpuPreference=$Preference;"
    $AppPath = $AppPath -replace '/', '\'

    if (-not (Test-Path $regKey)) {
        New-Item -Path $regKey -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $existing = Get-ItemProperty -Path $regKey -Name $AppPath -ErrorAction SilentlyContinue
    if ($existing -and $existing.$AppPath -eq $value) {
        Write-Log "Already exists: $AppPath" "SKIPPED"
        return
    }

    if ($DryRun) {
        Write-Log "[DRY RUN] Would add: $AppPath" "INFO"
        return
    }

    try {
        Set-ItemProperty -Path $regKey -Name $AppPath -Value $value -Force -ErrorAction Stop
        Write-Log "Added: $AppPath" "ADDED"
    } catch {
        Write-Log "Failed: $AppPath | Error: $_" "ERROR"
    }
}

# === SCAN WIN32 APPS ===
Write-Log "Scanning Win32 apps..." "INFO"
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$win32Exes = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayIcon } |
    ForEach-Object {
        if ($_.DisplayIcon -match '^"?(.*?\.exe)"?(?:,\d+)?$') { $matches[1] }
    } | Where-Object { $_ } | Select-Object -Unique
Write-Log "Found $($win32Exes.Count) Win32 paths." "INFO"

# === SCAN SERVICES ===
$serviceExes = @()
if ($InclusionLevel -ge 2) {
    Write-Log "Scanning Services..." "INFO"
    $serviceExes = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Where-Object { $_.PathName } |
        ForEach-Object {
            if ($_.PathName -match '^"?(.*?\.exe)"?(?:\s.*)?$') { $matches[1] }
        } | Where-Object { $_ } | Select-Object -Unique
    Write-Log "Found $($serviceExes.Count) Service paths." "INFO"
}

# Apply to Win32 + Services
$desktopExes = ($win32Exes + $serviceExes) | Select-Object -Unique
foreach ($exe in $desktopExes) {
    if (Test-Path $exe -ErrorAction SilentlyContinue) {
        Add-GpuPreference -AppPath $exe -Preference $Preference -Scope $Scope
    } else {
        Write-Log "Path not found, skipping: $exe" "WARN"
    }
}

# === SCAN UWP APPS ===
Write-Log "Scanning UWP apps..." "INFO"
$packages = if ($Scope -eq "AllUsers") { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue } else { Get-AppxPackage -ErrorAction SilentlyContinue }

$uwpProcessed = 0
foreach ($pkg in $packages) {
    $manifestPath = Join-Path $pkg.InstallLocation "AppxManifest.xml"
    if (Test-Path $manifestPath) {
        try {
            [xml]$manifest = Get-Content $manifestPath -ErrorAction Stop
            $applications = $manifest.Package.Applications.Application
            if ($applications) {
                foreach ($app in @($applications)) {
                    if ($app.Executable) {
                        $exePath = Join-Path $pkg.InstallLocation $app.Executable
                        if (Test-Path $exePath -ErrorAction SilentlyContinue) {
                            Add-GpuPreference -AppPath $exePath -Preference $Preference -Scope $Scope
                            $uwpProcessed++
                        }
                    }
                }
            }
        } catch {
            Write-Log "Manifest error: $($pkg.Name)" "WARN"
        }
    }
}
Write-Log "Processed $uwpProcessed UWP executables." "INFO"

Write-Log "Script completed. Check Settings > System > Display > Graphics." "SUCCESS"

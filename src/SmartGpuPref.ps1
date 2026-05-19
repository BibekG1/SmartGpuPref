<#
.SYNOPSIS
    SmartGpuPref v1.0 - Auto-configure Windows Graphics GPU preference
.DESCRIPTION
    Scans installed apps/services → adds EXE paths to Windows Graphics settings.
    Supports interactive mode, user scope, inclusion levels, and verbose output.
.PARAMETER Scope
    "CurrentUser" (HKCU) or "AllUsers" (HKLM + HKCU). Default: CurrentUser
.PARAMETER InclusionLevel
    1 = Apps only | 2 = Apps + Services | 3 = Everything (including system processes)
.PARAMETER Preference
    1 = Power saving | 2 = High performance (default)
.PARAMETER DryRun
    Preview changes without applying
.PARAMETER Verbose
    Show detailed output on screen + log file
.LINK
    https://github.com/BibekG1/SmartGpuPref
#>

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

function Write-Log {
    param($Message, $Level = "INFO")
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $entry -ErrorAction Stop
        if ($Verbose) { Write-Host $entry }
    } catch {
        if ($Verbose) { Write-Host "⚠️ Log write failed: $_" -ForegroundColor Yellow }
    }
}

function Set-GpuPreference {
    param([string]$AppPath, [int]$Preference = 2, [string]$Scope = "CurrentUser")
    $regRoot = if ($Scope -eq "AllUsers") { "HKLM:\Software\Microsoft\DirectX" } else { "HKCU:\Software\Microsoft\DirectX" }
    $regKey = "$regRoot\UserGpuPreferences"
    $value = "GpuPreference=$Preference;"
    
    try { $AppPath = [System.IO.Path]::GetFullPath($AppPath) } catch { Write-Log "Invalid path: $AppPath" "WARN"; return $false }
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force -ErrorAction SilentlyContinue | Out-Null }
    
    $existing = Get-ItemProperty -Path $regKey -Name $AppPath -ErrorAction SilentlyContinue
    if ($existing -and $existing.$AppPath -eq $value) { Write-Log "✅ Exists: $AppPath" "DEBUG"; return $true }
    
    if ($DryRun) { Write-Log "🔍 [DRY RUN] Would add: $AppPath" "INFO"; return $true }
    
    try {
        Set-ItemProperty -Path $regKey -Name $AppPath -Value $value -Force -ErrorAction Stop
        Write-Log "✅ ADDED: $AppPath" "INFO"
        return $true
    } catch {
        Write-Log "❌ FAILED: $AppPath | $_" "ERROR"
        return $false
    }
}

# === Scanning ===
Write-Log "🔍 Scanning Win32 apps..." "INFO"
$uninstallPaths = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
$win32Exes = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.DisplayIcon } | ForEach-Object { if ($_.DisplayIcon -match '^"?(.*?\.exe)"?(?:,\d+)?$') { $matches[1] } } | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) } | Select-Object -Unique

$serviceExes = @()
if ($InclusionLevel -ge 2) {
    Write-Log "🔍 Scanning services..." "INFO"
    $serviceExes = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -and $_.PathName -match '\.exe' } | ForEach-Object { if ($_.PathName -match '^"?(.*?\.exe)"?(?:\s.*)?$') { $matches[1] } } | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) } | Select-Object -Unique
}

Write-Log "🔍 Scanning UWP apps..." "INFO"
$uwpExes = @()
$packages = if ($Scope -eq "AllUsers") { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue } else { Get-AppxPackage -ErrorAction SilentlyContinue }
foreach ($pkg in $packages) {
    $manifestPath = Join-Path $pkg.InstallLocation "AppxManifest.xml"
    if (Test-Path $manifestPath) {
        try {
            [xml]$manifest = Get-Content $manifestPath -ErrorAction Stop
            foreach ($app in @($manifest.Package.Applications.Application)) {
                if ($app.Executable) {
                    $exePath = Join-Path $pkg.InstallLocation $app.Executable
                    if (Test-Path $exePath -ErrorAction SilentlyContinue) { $uwpExes += $exePath }
                }
            }
        } catch { Write-Log "Manifest parse error: $($pkg.Name)" "WARN" }
    }
}

# === Combine & Apply ===
$allExes = if ($InclusionLevel -eq 1) { $win32Exes + $uwpExes } elseif ($InclusionLevel -eq 2) { $win32Exes + $serviceExes + $uwpExes } else { $win32Exes + $serviceExes + $uwpExes }
$allExes = $allExes | Where-Object { $_ } | Select-Object -Unique
Write-Log "📊 Found $($allExes.Count) eligible paths (Level $InclusionLevel, Scope: $Scope)" "INFO"

$added = 0; $skipped = 0; $failed = 0
foreach ($exe in $allExes) {
    if (Set-GpuPreference -AppPath $exe -Preference $Preference -Scope $Scope) { $added++ } else { $failed++ }
    if ($Verbose) { Start-Sleep -Milliseconds 10 } # Keep console readable
}

# === Summary ===
Write-Host "`n📊 SUMMARY:" -ForegroundColor Cyan
Write-Host "  ✅ Added/New:      $added" -ForegroundColor Green
Write-Host "  ⏭️  Already Existed: $($allExes.Count - $added - $failed)" -ForegroundColor Yellow
Write-Host "  ❌ Failed:         $failed" -ForegroundColor Red
if ($DryRun) { Write-Host "  🔍 DRY RUN: No registry changes made." -ForegroundColor Cyan }
Write-Log "🎉 Completed: Added=$added, Skipped=$($allExes.Count - $added - $failed), Failed=$failed" "INFO"

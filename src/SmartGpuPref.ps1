
<#
.SYNOPSIS
    SmartGpuPref v1.0 - Auto-configure Windows Graphics GPU preference
.DESCRIPTION
    Scans installed apps/services → adds EXE paths to Windows Graphics settings 
    with high-performance GPU preference. Supports interactive mode, user scope 
    selection, and inclusion levels. Registry changes are PERSISTENT.
.PARAMETER Scope
    "CurrentUser" (HKCU) or "AllUsers" (HKLM + HKCU). Default: CurrentUser
.PARAMETER InclusionLevel
    1 = Apps only | 2 = Apps + Services | 3 = Everything (including system processes)
.PARAMETER Preference
    1 = Power saving | 2 = High performance (default)
.PARAMETER DryRun
    Preview changes without applying
.PARAMETER Verbose
    Show detailed output
.LINK
    https://github.com/BibekG1/SmartGpuPref
#>

[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser",
    
    [ValidateSet(1,2,3)]
    [int]$InclusionLevel = 3,              # 1=Apps, 2=Apps+Services, 3=Everything
    
    [ValidateSet(1,2)]
    [int]$Preference = 2,                  # 1=Power saving, 2=High performance
    
    [string]$LogFile = "$env:TEMP\SmartGpuPref.log",
    [switch]$DryRun,
    [switch]$Verbose
)

# === 📝 Logging ===
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

# === 🔧 Add GPU Preference to Registry ===
function Set-GpuPreference {
    param(
        [string]$AppPath,
        [int]$Preference = 2,
        [string]$Scope = "CurrentUser"
    )
    
    # Determine registry root
    $regRoot = if ($Scope -eq "AllUsers") { "HKLM:\Software\Microsoft\DirectX" } else { "HKCU:\Software\Microsoft\DirectX" }
    $regKey = "$regRoot\UserGpuPreferences"
    $value = "GpuPreference=$Preference;"
    
    # Normalize path
    try {
        $AppPath = [System.IO.Path]::GetFullPath($AppPath)
    } catch {
        Write-Log "Invalid path format: $AppPath" "WARN"
        return $false
    }
    
    # Ensure registry key exists (create if needed)
    if (-not (Test-Path $regKey)) {
        New-Item -Path $regKey -Force -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Check if already set correctly
    $existing = Get-ItemProperty -Path $regKey -Name $AppPath -ErrorAction SilentlyContinue
    if ($existing -and $existing.$AppPath -eq $value) {
        Write-Log "Already configured: $AppPath" "DEBUG"
        return $true
    }
    
    # Apply (or preview)
    if ($DryRun) {
        Write-Log "[DRY RUN] Would add: $AppPath → $value (Scope: $Scope)" "INFO"
        return $true
    }
    
    try {
        Set-ItemProperty -Path $regKey -Name $AppPath -Value $value -Force -ErrorAction Stop
        Write-Log "✅ Added: $AppPath → High Performance GPU (Scope: $Scope)" "INFO"
        return $true
    } catch {
        Write-Log "❌ Failed to add $AppPath : $_" "ERROR"
        return $false
    }
}

# === 🔍 Collect Win32 App EXEs ===
Write-Log "🔍 Scanning Win32 apps..." "INFO"
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$win32Exes = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.DisplayIcon } |
    ForEach-Object {
        if ($_.DisplayIcon -match '^"?(.*?\.exe)"?(?:,\d+)?$') {
            $matches[1]
        }
    } | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) } |
    Select-Object -Unique

# === 🔍 Collect Service EXEs (if InclusionLevel >= 2) ===
$serviceExes = @()
if ($InclusionLevel -ge 2) {
    Write-Log "🔍 Scanning services..." "INFO"
    $serviceExes = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.PathName -and $_.PathName -match '\.exe' } |
        ForEach-Object {
            if ($_.PathName -match '^"?(.*?\.exe)"?(?:\s.*)?$') {
                $matches[1]
            }
        } | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) } |
        Select-Object -Unique
}

# === 🔍 Collect UWP App EXEs ===
Write-Log "🔍 Scanning UWP apps..." "INFO"
$uwpExes = @()
$packages = if ($Scope -eq "AllUsers") { 
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue 
} else { 
    Get-AppxPackage -ErrorAction SilentlyContinue 
}
foreach ($pkg in $packages) {
    $manifestPath = Join-Path $pkg.InstallLocation "AppxManifest.xml"
    if (Test-Path $manifestPath) {
        try {
            [xml]$manifest = Get-Content $manifestPath -ErrorAction Stop
            $applications = $manifest.Package.Applications.Application
            if ($applications) {
                foreach ($app in @($applications)) {
                    $executable = $app.Executable
                    if ($executable) {
                        $exePath = Join-Path $pkg.InstallLocation $executable
                        if (Test-Path $exePath -ErrorAction SilentlyContinue) {
                            $uwpExes += $exePath
                        }
                    }
                }
            }
        } catch {
            Write-Log "Could not parse manifest for $($pkg.Name): $_" "WARN"
        }
    }
}

# === 🔄 Combine Based on InclusionLevel ===
$allExes = @()
if ($InclusionLevel -eq 1) {
    $allExes = $win32Exes + $uwpExes
} elseif ($InclusionLevel -eq 2) {
    $allExes = $win32Exes + $serviceExes + $uwpExes
} else {
    # Level 3: Everything (no filtering)
    $allExes = $win32Exes + $serviceExes + $uwpExes
}

$allExes = $allExes | Where-Object { $_ } | Select-Object -Unique
Write-Log "📊 Found $($allExes.Count) eligible EXE paths (Level $InclusionLevel, Scope: $Scope)" "INFO"

# === ⚙️ Apply GPU Preference ===
$success = 0
$failed = 0
foreach ($exe in $allExes) {
    if (Set-GpuPreference -AppPath $exe -Preference $Preference -Scope $Scope) {
        $success++
    } else {
        $failed++
    }
}

# === 📈 Summary ===
Write-Log "🎉 Completed: $success added, $failed failed, $($allExes.Count - $success - $failed) skipped (already set)" "INFO"
if ($DryRun) {
    Write-Host "🔍 DRY RUN: No changes applied. Remove -DryRun to apply." -ForegroundColor Cyan
}

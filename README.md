
# 🎮 SmartGpuPref for Windows 11
**Auto-configure Windows Graphics GPU preference for installed apps**  
*Interactive installer lets you choose scope, inclusion level, and performance mode. Scans Win32 apps, UWP apps, and services → sets GPU preference → runs weekly to catch new installs.*

> ✨ **Features**: Interactive setup, user/all-users scope, 3 inclusion levels, persistent registry edits, verbose logging, dry-run mode, weekly auto-sync.

---

## ⚡ One-Click Interactive Install
Run in **Administrator PowerShell**:
```powershell
irm https://raw.githubusercontent.com/BibekG1/SmartGpuPref/main/install.ps1 | iex
```

### 🎮 What Happens:
1. Installer asks 3 simple questions:
   ```
   📍 Scope: [1] Current user only | [2] All users
   📦 Inclusion: [1] Apps only | [2] Apps+Services | [3] Everything (your choice)
   ⚡ GPU Mode: [1] Power saving | [2] High performance
   ```
2. Downloads and configures SmartGpuPref with your choices
3. Creates two scheduled tasks:
   - `SmartGpuPref`: Runs at login (+2 min delay)
   - `SmartGpuPref_WeeklySync`: Runs Sundays @ 3 AM
4. Verifies installation and shows summary

---

## ⚙️ Manual Usage (Advanced)
Run the core script directly with parameters:
```powershell
# Example: All users, everything included, high performance
C:\Scripts\SmartGpuPref\SmartGpuPref.ps1 -Scope AllUsers -InclusionLevel 3 -Preference 2 -Verbose

# Example: Dry run to preview changes
C:\Scripts\SmartGpuPref\SmartGpuPref.ps1 -DryRun -Verbose
```

### Parameters:
| Parameter | Options | Default | Description |
|-----------|---------|---------|-------------|
| `-Scope` | `CurrentUser`, `AllUsers` | `CurrentUser` | Registry scope: HKCU (current user) or HKLM+HKCU (all users) |
| `-InclusionLevel` | `1`=Apps, `2`=Apps+Services, `3`=Everything | `3` | Which processes to configure |
| `-Preference` | `1`=Power saving, `2`=High performance | `2` | GPU preference value to set |
| `-DryRun` | (switch) | Off | Preview changes without applying |
| `-Verbose` | (switch) | Off | Show detailed output |

---

## 🔍 How It Works (Persistence Clarification)
✅ **Registry edits are PERMANENT**: Once an EXE path is added to `HKCU\...\UserGpuPreferences` (or HKLM for AllUsers), it stays there forever — surviving reboots, updates, and reinstalls.

✅ **Scheduled tasks are for NEW apps only**: 
- `SmartGpuPref` (at login) and `SmartGpuPref_WeeklySync` (Sundays) re-scan for apps installed since last run → add them to the permanent registry list.
- They do NOT remove, refresh, or "cache" anything. Existing entries remain untouched.

🎯 **Analogy**: Registry = permanent guest list. Scheduled tasks = weekly headcount to add new guests.

---

## 🛡️ Transparency & Control
✅ **Path validation**: Only adds paths that exist on disk  
✅ **Idempotent**: Re-running won't duplicate registry entries  
✅ **Dry-run mode**: Test before applying (`-DryRun` flag)  
✅ **User-scoped or system-wide**: Choose HKCU or HKLM+HKCU at install  
✅ **No artificial exclusions**: Level 3 includes EVERYTHING — Windows safely ignores preference for non-GPU apps  

> 💡 **Technical note**: Windows only applies GPU preference to processes that actually use graphics APIs. Setting `GpuPreference=2` for CPU-only processes has no effect — it's harmless, just stored in the registry for potential future use.

---

## 🗓️ Scheduled Tasks
| Task Name | Trigger | Purpose |
|-----------|---------|---------|
| `SmartGpuPref` | At logon (+2 min delay) | Initial setup + catch apps installed since last run |
| `SmartGpuPref_WeeklySync` | Weekly, Sundays @ 3 AM | Auto-discover newly installed apps during the week |

Manage in Task Scheduler → Library → SmartGpuPref*

---

## 🛠️ Troubleshooting
| Issue | Fix |
|-------|-----|
| Script not running | Verify tasks are `Enabled` in Task Scheduler |
| No GPU preference applied | Check `%TEMP%\SmartGpuPref.log` for errors |
| Permission denied | Run PowerShell as Administrator |
| UWP apps not detected (AllUsers) | Ensure you're admin; `-AllUsers` requires elevation |
| Want to test first | Run manually with `-DryRun -Verbose` flags |

---

## 🗑️ Uninstall
```powershell
# Run in Admin PowerShell:
Unregister-ScheduledTask -TaskName "SmartGpuPref" -Confirm:$false
Unregister-ScheduledTask -TaskName "SmartGpuPref_WeeklySync" -Confirm:$false
Remove-Item "C:\Scripts\SmartGpuPref" -Recurse -Force

# Optional: Clear registry entries (careful!)
# Current user only:
Remove-Item "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Recurse -Force
# All users (requires admin):
Remove-Item "HKLM:\Software\Microsoft\DirectX\UserGpuPreferences" -Recurse -Force
```

---

## 📜 License & Credits
- MIT License — Free to use, modify, distribute
- Inspired by Windows Graphics settings automation needs
- Best paired with SmartDiskThrottle for full system optimization

🔗 Repo: `https://github.com/BibekG1/SmartGpuPref`  
🐛 Issues: Use GitHub Issues tab
```


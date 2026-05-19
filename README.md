
# 🎮 SmartGpuPref for Windows 11
**Auto-configure Windows Graphics GPU preference for installed apps**  
*Interactive installer lets you choose scope, inclusion level, and performance mode. Scans Win32 apps, UWP apps, and services → sets GPU preference → runs weekly to catch new installs.*

> ✨ **Features**: Interactive setup, user/all-users scope, 3 inclusion levels, persistent registry edits, verbose logging, dry-run mode, weekly auto-sync.

---

## ❓ Why Does This Exist? (The Real Reason)

### 🎯 The Problem: "My PC feels laggy even though I have a decent system"
Many Windows 11 users notice:
- High CPU usage from background apps (Chrome, Discord, OneDrive, system services)
- GPU sitting idle at 0-5% while CPU struggles at 80-100%
- Stutters, slow app launches, and general "heaviness" even on capable hardware

### 💡 The Discovery: Offloading to GPU Helps — Even for "CPU-Only" Apps
> *"I tested this extensively on my own PC. When I manually added EXE files — even ones that don't traditionally use graphics — to the Windows Graphics 'High Performance' list, something unexpected happened: CPU usage dropped, and the system felt noticeably snappier. funfact even works on older laptops or pc with integrated GPU."*

#### What's Likely Happening:
| Observation | Probable Explanation |
|-------------|---------------------|
| CPU usage drops after adding apps to GPU preference | Windows may offload certain rendering, compositing, or hardware-accelerated tasks to the GPU, freeing CPU cycles |
| System feels more responsive | Lower CPU contention = smoother foreground app performance |
| No negative side effects on iGPU-only systems | Windows gracefully uses available hardware; no conflicts |

> ✅ **This tool automates that discovery**. Instead of manually adding dozens of EXE paths in Settings → System → Display → Graphics, SmartGpuPref scans your entire system and configures them in seconds.

### 🚀 "Laggy PC? Not Anymore."
If you've ever:
- Wondered why your powerful PC still feels slow
- Wanted to squeeze extra performance without upgrading hardware
- Tried manual GPU preference tweaks but gave up due to the tedious process

→ **SmartGpuPref is for you**. It's the automation layer you've been waiting for.

> 🔬 **Tested by the author**: This isn't theory. I've run this script on my own Windows 11 laptops and even on laptops of few of my neighbours multiple times, monitored CPU/GPU usage in Task Manager, and consistently observed reduced CPU load and smoother performance after applying GPU preferences broadly. Your mileage may vary, but the potential upside is real — and the risk is near-zero.

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
C:\Scripts\SmartGpuPref\SmartGpuPref.ps1 -Scope AllUsers -InclusionLevel 3 -Preference 2

# Example: Dry run to preview changes
C:\Scripts\SmartGpuPref\SmartGpuPref.ps1 -DryRun
```

### Parameters:
| Parameter | Options | Default | Description |
|-----------|---------|---------|-------------|
| `-Scope` | `CurrentUser`, `AllUsers` | `CurrentUser` | Registry scope: HKCU (current user) or HKLM+HKCU (all users) |
| `-InclusionLevel` | `1`=Apps, `2`=Apps+Services, `3`=Everything | `3` | Which processes to configure |
| `-Preference` | `1`=Power saving, `2`=High performance | `2` | GPU preference value to set |
| `-DryRun` | (switch) | Off | Preview changes without applying |

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
✅ **No artificial exclusions**: Level 3 includes EVERYTHING — Windows safely handles preference for non-GPU apps  

> 💡 **Technical note**: Windows only applies GPU preference to processes that actually use graphics APIs. Setting `GpuPreference=2` for CPU-only processes is harmless — it's stored for potential future use, and may still yield performance benefits via hardware task offloading as observed in testing.

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
| Want to test first | Run manually with `-DryRun` flag |
| See `Join-Path` warnings about null paths | Harmless — some UWP packages aren't fully installed; script skips them safely |

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
- **Developed by**: BibekG1 — tested, refined, and shared based on real-world performance observations
- **License**: MIT — Free to use, modify, and distribute. No warranty.
- **Inspired by**: The simple idea that "if adding one app to GPU preference helps, why not automate it for all apps?"
- **Best paired with**: [SmartDiskThrottle](https://github.com/BibekG1/SmartDiskThrottle) for full system I/O + GPU optimization

### 🤝 Contributing
Found a bug? Want a feature?  
→ Open an issue or pull request on GitHub:  
🔗 `https://github.com/BibekG1/SmartGpuPref`

### 📧 Support
- 🐛 Bug reports: Use GitHub Issues
- 💡 Feature requests: Use GitHub Discussions or Issues
- ❓ General questions: Reply to this README or open a Discussion

---

> 💬 **Final Thought**: SmartGpuPref was born from a simple observation: *"What if I just add everything to high-performance GPU preference?"* The result was a faster, smoother PC — and this tool is my way of sharing that discovery. If it helps even one person squeeze extra performance from their hardware, it's worth it. 🎮✨
```


Let me know if you want to add a screenshot of Task Manager before/after, or a "Performance Tips" section next. 🎮✨

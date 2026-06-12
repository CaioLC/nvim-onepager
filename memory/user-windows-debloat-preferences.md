---
name: user-windows-debloat-preferences
description: User's standing preferences for debloating their Windows desktop
metadata:
  type: user
---

The user runs an 8+yr-old Windows 11 **desktop** and periodically debloats it with my help. Established preferences (2026-06):

- **Never touch the remote-access stack** — they use and accept the risk of: AnyDesk, Tailscale, SonicWall NetExtender, and **QuickAssist** (explicitly kept during the MSIX debloat). Don't flag these as bloat.
- **Cloud sync:** keep **Google Drive (FS)**, drop **OneDrive** (autostart off, stopped — files left on disk, not unlinked).
- **Power plan:** High Performance (it's a desktop, not a laptop — no battery tradeoff).
- Aggressive about Store/MSIX bloat: removed Bing/News/Office hub/Solitaire/3DViewer/MixedReality/GetHelp/Feedback/People/Todos/PowerAutomate and the Xbox overlay stack via `Remove-AppxPackage` + `Remove-AppxProvisionedPackage` (deprovision so they don't return on feature updates).
- Working style: **evidence-first** (scan registry/processes/services before recommending), **dry-run-first** scripts they can curate, then execute. Reusable scripts live in `C:\Users\c4ioc\` (`debloat-appx.ps1`, `cleanup-winget.ps1`, `procspy.ps1`).

**How to apply:** when asked to lighten Windows, scan startup keys / top-RAM procs / orphan services+tasks first, present a curated table grouped by safety, recommend, then act on the clear wins. When clearing `%TEMP%`, **exclude `%TEMP%\claude`** (Claude Code's own task-output dir — wiping it kills the running tool's output). See [[check-runtime-dependents-before-removal]].

---
name: check-runtime-dependents-before-removal
description: Before removing "stale" Python/conda runtimes, check what invisibly pins to them
metadata:
  type: feedback
---

When bulk-uninstalling software judged "stale" — old Python interpreters, base Anaconda/Miniconda — check what invisibly depends on them BEFORE calling them safe.

In the 2026-06 winget cleanup, two items labeled "stale runtimes" had live dependents:
- Removing **Anaconda3 2019.03** deleted `C:\ProgramData\Anaconda3` → killed the `conda` CLI itself (the env files in `~/.conda/envs/nvim` survived and molten still ran, but conda env management was gone) and broke the PowerShell `profile.ps1` conda-init block.
- Removing **Python 3.9.1** broke **Poetry** — it was `pip install --user`'d under `C:\Python39`, and `poetry.exe`'s console-script is hard-pinned to that interpreter path.

**Why:** interpreters and base distros look like dead cruft but are toolchain roots; console-script launchers (Poetry/pipx), the `conda` command, profile init blocks, and registered Jupyter kernels all silently point at a specific `python.exe`/distro.

**How to apply:** for each interpreter/distro slated for removal, check its `Scripts` dir for console scripts and grep profile/init files for its path. Flag as "has dependents — will break X" and warn loudly; never label it "safe" without that check. Related: [[user-python-workflow-conda-poetry]]

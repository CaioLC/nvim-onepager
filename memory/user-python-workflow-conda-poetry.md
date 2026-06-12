---
name: user-python-workflow-conda-poetry
description: User runs conda + Poetry in tandem for Python work
metadata:
  type: user
---

The user uses **conda and Poetry in tandem**: conda owns the environment + interpreter + native/system libs; Poetry manages project Python deps from PyPI. Standard integration is `poetry config virtualenvs.create false` so Poetry installs into the active conda env instead of making its own venv.

Poetry should be installed **isolated** (pipx or the official installer), NOT `pip install --user` into a specific Python — historically it was under `C:\Python39` and broke when that interpreter was removed. See [[check-runtime-dependents-before-removal]].

Platform note: this is the same Windows box as the nvim-onepager config; molten's python env lives at `~/.conda/envs/nvim`.

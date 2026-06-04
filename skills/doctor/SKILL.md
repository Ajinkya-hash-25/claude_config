---
name: doctor
description: Validate org Claude config install health. Check deps, symlinks, JSON files, shell scripts. Trigger on "doctor", "check install", "/doctor".
---

Run `python3 skills/doctor/doctor.py` from repo root.
Add `--deep` for external checks (uvx, code-review-graph, git).

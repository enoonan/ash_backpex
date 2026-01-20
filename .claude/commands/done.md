---
name: done
description: Run CI checks and close the current bead when a task is complete.
---

# Done - Finalize Task

Use this command to manually finalize a task. (Note: `/work` includes these steps automatically.)

## 1. Run CI checks

```bash
mix ci
```

If CI fails, fix the issues before proceeding.

## 2. Commit changes

Once CI passes, commit all changes:

```bash
git add -A && git commit -m "<type>: <description>"
```

Use conventional commit types: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`

## 3. Close the bead

```bash
bd close <id> && bd sync
```

Replace `<id>` with the bead ID (run `bd show` if needed).

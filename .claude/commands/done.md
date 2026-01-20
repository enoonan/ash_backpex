---
name: done
description: Run CI checks and close the current bead when a task is complete.
---

# Done - Finalize Task

When this skill is invoked, complete the following steps:

## 1. Run CI checks

Run the CI task to verify all tests and linting pass:

```bash
mix ci
```

If CI fails, fix the issues before proceeding.

## 2. Commit changes

Once CI passes, commit all changes with a good message using conventional commits format:

```bash
git add -A && git commit -m "<type>: <description>"
```

Use appropriate conventional commit types:
- `feat:` for new features
- `fix:` for bug fixes
- `chore:` for maintenance tasks
- `refactor:` for code refactoring
- `docs:` for documentation changes
- `test:` for test additions/changes

## 3. Close the bead

Once committed, close the current bead and sync:

```bash
bd close <id> && bd sync
```

Replace `<id>` with the bead ID you've been working on (e.g., `insi-xb3`).

## Notes

- Always ensure CI passes before closing a bead
- If you don't know the bead ID, run `bd show` to find it
- The bead ID should have been established at the start of the task
- **If invoked from /work**: After this skill completes, remember to run `/exit`

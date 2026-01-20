# Task: Complete One Bead

Complete ALL of the following steps in order:

## 1. Check for available beads

```bash
bd ready
```

If there are no open issues, say "No beads available" and stop.

## 2. Select the most important bead

Choose the bead to work on based on priority:
1. Highest priority number (priority 1 > priority 2 > priority 3)
2. If priorities are equal, prefer older beads (created earlier)
3. If a bead is already `in_progress`, continue with that one

Show which bead you're selecting and why.

## 3. Claim the bead

```bash
bd update <id> --status in_progress
bd show <id>
```

Read the full bead context including the design field to understand the implementation plan.

## 4. Implement the task

- Follow the design/plan in the bead
- If no design exists, implement based on the title and description
- Use TodoWrite to track progress on multi-step tasks

## 5. Run CI checks

```bash
mix ci
```

If CI fails, fix the issues and re-run until it passes.

## 6. Commit changes

Once CI passes, commit all changes:

```bash
git add -A && git commit -m "<type>: <description>"
```

Use conventional commit types: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`

## 7. Close the bead

```bash
bd close <id> && bd sync
```

## Done

Say "Bead <id> completed." when finished.

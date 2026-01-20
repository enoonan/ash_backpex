---
name: work
description: Pick the next bead, complete it, and run CI checks.
---

# Work - Autonomous Task Execution

When this skill is invoked, complete the following steps:

## 1. Check for available beads

```bash
bd ready
```

If there are no open issues, inform the user and stop.

## 2. Select the most important bead

Choose the bead to work on based on priority:
1. Highest priority number (priority 1 > priority 2 > priority 3)
2. If priorities are equal, prefer older beads (created earlier)
3. If a bead is already `in_progress`, continue with that one

Show the user which bead you're selecting and why.

## 3. Claim the bead

```bash
bd update <id> --status in_progress
bd show <id>
```

Read the full bead context including the `--design` field to understand the implementation plan.

## 4. Implement the task

- Follow the design/plan in the bead
- If no design exists, create a plan and get user approval before coding
- Use TodoWrite to track progress on multi-step tasks
- Ask clarifying questions if requirements are ambiguous

## 5. Run /done

Once the implementation is complete, invoke the `/done` skill.

## 6. Exit

After `/done` completes, run `/exit` to end the session and return control to the Ralph loop.

## Notes

- Always get approval before implementing if there's no design in the bead, unless you are running with --dangerously-skip-permissions
- If you encounter blockers, add a comment with `bd comments add <id> "description"` and ask the user for guidance
- If work reveals additional tasks, create new beads with `bd create`
- One bead at a time - finish the current one before starting another

---

## Beads Command Reference

**Querying work:**
```bash
bd ready                          # Show unblocked work
bd show <id>                      # Full bead context
bd blocked                        # Show blocked issues
bd epic status                    # Check epic progress
```

**Creating issues:**
```bash
bd create "Title" --type=feature|bug|task|epic --priority=1|2|3 \
  --design="Implementation plan" \
  --acceptance="Definition of done"

bd create "Subtask" --parent=<epic-id> --type=task
```

**Updating status:**
```bash
bd update <id> --status open|in_progress|closed
bd close <id>
```

**Progress tracking:**
```bash
bd comments add <id> "Progress update or findings"
```

**Dependencies:**
```bash
bd dep add <child> <parent>       # child depends on parent (child is blocked until parent closes)
```

**Syncing:**
```bash
bd sync                           # Push/pull changes - run at session end
```

**Key principles:**
1. Check `bd ready` first when looking for work
2. Store plans in `--design` field
3. Track progress with `bd comments add`
4. Create beads for discovered work - don't lose tasks in conversation

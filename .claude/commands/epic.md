---
name: epic
description: Collaboratively plan a feature and create beads for execution.
---

# Epic - Collaborative Feature Planning

When this skill is invoked, engage in a collaborative conversation to help the user break down a feature into an epic with subtasks.

## Philosophy

Epics are developed **together through conversation**, not generated in isolation. The user may start with a detailed spec or just a rough idea. Your job is to be a thought partner—asking questions, exploring the codebase, and helping shape the work into well-defined beads.

## Integration with Spec Kit

If the project has **spec-kit** initialized (`.specify/` directory exists), consider whether the feature warrants the full spec-kit workflow:

**Use spec-kit when:**
- The feature is complex with many unknowns
- Formal specification would reduce ambiguity
- The user wants structured documentation

**Spec-kit → Beads workflow:**
1. `/speckit.specify` - Create feature specification
2. `/speckit.plan` - Technical implementation plan
3. `/speckit.tasks` - Generate task breakdown
4. `/speckit.taskstoissues` - Convert to issues, OR manually create beads from tasks.md

**Skip spec-kit when:**
- The feature is straightforward
- The user just wants to talk through it and create beads directly
- Spec-kit isn't initialized in the project

Ask the user which approach they prefer if unclear.

## Workflow (Direct to Beads)

### 1. Understand the starting point

Ask the user to describe what they want to build. Accept whatever level of detail they have:
- A vague idea: *"I want better error handling"*
- A partial spec: *"Webhook retries with exponential backoff, maybe 3 attempts"*
- A detailed design: Full requirements doc

### 2. Explore and ask questions

- Use codebase exploration to understand the current state
- Ask clarifying questions about scope, constraints, and priorities
- Surface trade-offs and design decisions that need to be made
- Don't rush—some epics need multiple rounds of discussion

Good questions to consider:
- What problem does this solve? Who benefits?
- What's the minimum viable version vs. the ideal version?
- Are there existing patterns in the codebase we should follow?
- What are the dependencies or prerequisites?
- How will we know it's working? (acceptance criteria)

### 3. Iteratively draft the structure

As understanding develops, start sketching the epic structure:
- Propose a breakdown into subtasks
- Discuss whether tasks are the right size (not too big, not too small)
- Identify dependencies between tasks
- Refine based on user feedback

Present drafts in a readable format:
```
Epic: [Title]

  Task 1: [Title]
  - Design: [Brief implementation approach]
  - Acceptance: [Definition of done]
  - Depends on: (none)

  Task 2: [Title]
  - Design: [Brief implementation approach]
  - Acceptance: [Definition of done]
  - Depends on: Task 1
```

### 4. Get explicit approval

Before creating any beads, confirm:
- "Does this breakdown look right?"
- "Should I create these beads now?"

Never create beads without explicit approval.

### 5. Create the beads

Once approved, create the epic and all subtasks:

```bash
# Create the epic
bd create "Epic title" --type=epic --priority=N \
  --design="Overall approach" \
  --acceptance="Epic-level success criteria"

# Create subtasks with parent reference
bd create "Task 1" --type=task --parent=<epic-id> --priority=N \
  --design="Implementation plan" \
  --acceptance="Definition of done"

# Set up dependencies between tasks
bd dep add <child-id> <parent-id>

# Sync to persist
bd sync
```

Report the created bead IDs so the user can reference them.

## Converting Spec Kit Tasks to Beads

If using spec-kit, after `/speckit.tasks` generates `.specify/memory/tasks.md`:

1. Read the tasks file to understand the breakdown
2. Present the tasks to the user for review
3. On approval, create beads:

```bash
# For each task in tasks.md:
bd create "Task title" --type=task --parent=<epic-id> \
  --design="Copy relevant design from plan.md" \
  --acceptance="Copy acceptance criteria from tasks.md"

# Set up dependencies based on task ordering
bd dep add <later-task> <earlier-task>

bd sync
```

The spec-kit artifacts (spec.md, plan.md) become reference documentation; the beads become the execution tracking system.

## Notes

- **Conversation is the point.** Don't skip to bead creation. The discussion often reveals important details.
- **It's okay to pause.** If the user needs to think or research, the conversation can span multiple sessions.
- **Discovered complexity → more discussion.** If codebase exploration reveals the feature is harder than expected, discuss before expanding scope.
- **Keep tasks atomic.** Each task should be completable in one focused session with `/work`.
- **Dependencies matter.** Use `bd dep add` so `bd ready` surfaces tasks in the right order.

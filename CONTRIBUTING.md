 Contributing to Ash Backpex

This project uses AI-assisted development workflows with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Spec Kit](https://github.com/github/spec-kit), and [Beads](https://github.com/steveyegge/beads) for task management.

## Getting Started

### Dev Container Setup

The easiest way to contribute is using the provided dev container, which comes pre-configured with all dependencies.

**Prerequisites:**
- Docker
- VS Code with the Dev Containers extension (or GitHub Codespaces)
- Claude API credentials configured in `~/.claude`

**Starting the dev container:**

1. Clone the repository
2. Open in VS Code
3. When prompted, click "Reopen in Container" (or use Command Palette → "Dev Containers: Reopen in Container")
4. The container will automatically:
   - Install Claude Code CLI
   - Set up Elixir/Erlang with Hex and Rebar
   - Install project dependencies
   - Mount your Claude credentials from `~/.claude`

The dev container forwards ports 4000 (Phoenix app) and 5432 (PostgreSQL).

## Development Workflows

### Claude Commands

The project includes custom Claude commands for task management:

| Command | Description                                        |
| ------- | -------------------------------------------------- |
| `/work` | Pick the next available bead and implement it      |
| `/done` | Run CI, commit changes, and close the current bead |
| `/epic` | Collaboratively plan a feature and create beads    |

### [Spec Kit](https://github.com/github/spec-kit) Commands

For complex features, use the Spec Kit workflow (see also [speckit.org](https://speckit.org/)):

| Command                  | Description                                           |
| ------------------------ | ----------------------------------------------------- |
| `/speckit.specify`       | Create a feature specification from a description     |
| `/speckit.clarify`       | Identify and resolve underspecified areas in the spec |
| `/speckit.plan`          | Generate a technical implementation plan              |
| `/speckit.tasks`         | Generate actionable tasks from the plan               |
| `/speckit.taskstoissues` | Convert tasks to GitHub issues or beads               |
| `/speckit.analyze`       | Cross-artifact consistency check                      |
| `/speckit.checklist`     | Generate a custom checklist for the feature           |

**Typical Spec Kit workflow:**

1. `/speckit.specify Add support for custom field types` - Create the spec
2. `/speckit.clarify` - Resolve any ambiguities
3. `/speckit.plan` - Design the implementation
4. `/speckit.tasks` - Break down into tasks
5. `/speckit.taskstoissues` - Create beads for execution

### [Beads](https://github.com/steveyegge/beads) (Task Management)

Beads is a git-backed task tracker designed for AI agents. Common commands:

```bash
bd ready              # Show available work
bd show <id>          # View bead details
bd create "Title"     # Create a new bead
bd update <id> --status in_progress
bd close <id>         # Mark as complete
bd sync               # Push/pull changes
```

## Automated Development with Ralph

The `ralph.sh` script provides an automated loop for processing beads:

```bash
./ralph.sh
```

Ralph will:
1. Check for available beads via `bd ready`
2. Start a Claude session with `/work` to complete one bead
3. Automatically run CI, commit, and close the bead
4. Repeat until no beads remain

This is useful for processing multiple well-defined tasks autonomously.

**Requirements:**
- Claude Code CLI installed and authenticated
- `--dangerously-skip-permissions` flag is used (review beads before running)

## Manual Development

If you prefer manual control:

1. **Find work:** `bd ready`
2. **Start a Claude session:** `claude`
3. **Pick up a task:** `/work`
4. **When complete:** `/done`

Or work without Claude:

1. `bd ready` - Find a task
2. `bd update <id> --status in_progress` - Claim it
3. Implement the changes
4. `mix ci` - Run tests and linting
5. `git add -A && git commit -m "feat: description"` - Commit
6. `bd close <id> && bd sync` - Close and sync

## Code Quality

Before submitting:

```bash
mix ci          # Run credo --strict && sobelow
mix test        # Run all tests
mix format      # Format code
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `refactor:` - Code refactoring
- `docs:` - Documentation changes
- `test:` - Test additions/changes

Example: `feat: add support for custom field types`

## Questions?

- Check existing beads: `bd ready` and `bd blocked`
- Review the spec: `.specify/` directory (if using Spec Kit)
- Read the code: Start with `CLAUDE.md` for architecture overview

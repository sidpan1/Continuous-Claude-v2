---
name: github-orchestration
description: Recursive self-coordination via GitHub issues, labels, and workflows
allowed-tools: [Bash, Read, Write, Glob, Grep]
---

# GitHub Orchestration

Enable Claude to coordinate with itself recursively using GitHub as the orchestration layer. This pattern allows autonomous multi-agent workflows where Claude instances communicate via issues, labels, and comments.

## When to Use

- "Break this into parallel tasks"
- "Create sub-issues for this work"
- "Set up autonomous workflow"
- "Coordinate multiple Claude instances"
- "Self-improving system"
- "Recursive task decomposition"
- Large work items that benefit from parallelization
- Work that should continue without human intervention

## Core Concepts

### The Orchestration Pattern

```
Parent Issue (objective)
    ↓
Claude analyzes → creates sub-issues
    ↓
Labels trigger parallel Claude instances
    ↓
Each instance works independently
    ↓
Comments provide status/learnings
    ↓
Scheduled job checks completion
    ↓
Meta-analysis across all results
    ↓
Create next iteration (if applicable)
```

### Communication Primitives

| Primitive | GitHub Mechanism | Purpose |
|-----------|------------------|---------|
| Task definition | Issue body | What to do |
| Task state | Labels | ready, in-progress, done, failed, blocked |
| Task grouping | Labels | batch-N, epic-X |
| Progress update | Comments | Status, checkpoints |
| Handoff data | Comments (JSON) | Structured output |
| Trigger next | Label change | ready → triggers workflow |
| Aggregate | API query | Find all issues with label |

### Label State Machine

```
            ┌─────────────────────────────────────┐
            ↓                                     │
[new] → [ready] → [in-progress] → [done]         │
                        │             ↓           │
                        └──→ [failed] ──→ [retry] ┘
                        │
                        └──→ [blocked] (needs human)
```

## Instructions

### 1. Decompose Work into Sub-Issues

When you have a large task, break it into parallel sub-issues:

```python
# Use gh CLI to create issues
for task in tasks:
    gh issue create \
        --title "[SUBTASK] {task.title}" \
        --body "{task.description}" \
        --label "subtask,ready,parent-{parent_id}"
```

Or via GitHub API in Python:

```python
from github import Github

def create_subtasks(parent_issue_number: int, tasks: list[dict]):
    """Create sub-issues linked to parent."""
    g = Github(os.environ["GITHUB_TOKEN"])
    repo = g.get_repo(os.environ["GITHUB_REPOSITORY"])

    for task in tasks:
        body = f"""
## Parent Issue
#{parent_issue_number}

## Task
{task['description']}

## Acceptance Criteria
{task['criteria']}

## Output Format
Post results as JSON comment when complete.
"""
        issue = repo.create_issue(
            title=f"[SUBTASK] {task['title']}",
            body=body,
            labels=["subtask", "ready", f"parent-{parent_issue_number}"]
        )
        print(f"Created #{issue.number}: {task['title']}")
```

### 2. Set Up Workflow Triggers

Create `.github/workflows/subtask-worker.yml`:

```yaml
name: Subtask Worker
on:
  issues:
    types: [labeled]

jobs:
  work:
    # Trigger when 'ready' label is added to subtask
    if: |
      contains(github.event.issue.labels.*.name, 'subtask') &&
      github.event.label.name == 'ready'
    runs-on: ubuntu-latest
    timeout-minutes: 60

    steps:
      - uses: actions/checkout@v4

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Work on the task described in this issue.

            When complete:
            1. Post a comment with your results in JSON format
            2. Add the 'done' label

            If you cannot complete:
            1. Post a comment explaining why
            2. Add the 'blocked' or 'failed' label

      - name: Update labels
        uses: actions/github-script@v7
        with:
          script: |
            // Remove 'ready', add 'in-progress' at start
            // Add 'done' or 'failed' based on outcome
```

### 3. Monitor and Aggregate

Create scheduled workflow for coordination:

```yaml
name: Coordinator
on:
  schedule:
    - cron: '0 */2 * * *'  # Every 2 hours
  workflow_dispatch:

jobs:
  coordinate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check completion
        uses: actions/github-script@v7
        id: check
        with:
          script: |
            // Find parent issues with incomplete subtasks
            const parents = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: 'parent',
              state: 'open'
            });

            for (const parent of parents.data) {
              const subtasks = await github.rest.issues.listForRepo({
                owner: context.repo.owner,
                repo: context.repo.repo,
                labels: `parent-${parent.number}`,
                state: 'all'
              });

              const done = subtasks.data.filter(i =>
                i.labels.some(l => l.name === 'done')
              );

              if (done.length === subtasks.data.length) {
                core.setOutput(`complete_${parent.number}`, 'true');
              }
            }

      - uses: anthropics/claude-code-action@v1
        if: steps.check.outputs.complete_* == 'true'
        with:
          prompt: |
            A parent issue has all subtasks complete.
            1. Gather results from subtask comments
            2. Synthesize findings
            3. Post summary to parent issue
            4. Close parent issue
            5. Create next iteration if applicable
```

### 4. Post Structured Results

Always post results as parseable JSON:

```markdown
## Results

```json
{
  "status": "success",
  "outcome": {
    "summary": "Completed task X",
    "details": "..."
  },
  "learnings": [
    "Pattern A was effective",
    "Approach B failed because..."
  ],
  "metrics": {
    "duration_minutes": 15,
    "attempts": 2
  }
}
```
```

### 5. Recursive Decomposition

For multi-level decomposition:

```
Epic Issue (high-level goal)
  ↓ Claude creates
Story Issues (1-4 hour chunks)
  ↓ Each story's Claude creates
Task Issues (15-60 min atomic units)
  ↓ Each task's Claude executes
Results flow back up via comments
```

Each level uses the same pattern:
1. Analyze scope
2. Create sub-issues with appropriate labels
3. Wait for completion via scheduled check
4. Aggregate and report to parent

## Workflow Templates

### Basic Parallel Execution

```yaml
# .github/workflows/parallel-worker.yml
name: Parallel Worker
on:
  issues:
    types: [labeled]

jobs:
  execute:
    if: github.event.label.name == 'execute'
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Self-Improving Loop

```yaml
# .github/workflows/learning-loop.yml
name: Learning Loop
on:
  schedule:
    - cron: '0 0 * * *'  # Daily

jobs:
  learn:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          prompt: |
            1. Query all issues closed in last 24 hours
            2. Extract learnings from result comments
            3. Identify patterns (3+ occurrences)
            4. Create/update rules in .claude/rules/
            5. Post learning summary to tracking issue
```

## Anti-Patterns to Avoid

1. **Infinite loops**: Always check for existing issues before creating new ones
2. **Label storms**: Batch label changes, don't trigger cascades
3. **Missing timeouts**: Always set `timeout-minutes` on jobs
4. **No exit condition**: Define clear completion criteria
5. **Orphaned subtasks**: Always link to parent issue

## Integration with Existing Skills

- **compound-learnings**: Feed aggregated learnings to pattern extraction
- **continuity_ledger**: Persist coordination state across sessions
- **recall-reasoning**: Query past coordination outcomes
- **create_handoff**: Document multi-issue work for human review

## Required Setup

1. Install Claude GitHub App: `claude /install-github-app`
2. Set `ANTHROPIC_API_KEY` as repository secret
3. Create workflow files in `.github/workflows/`
4. Create required labels via GitHub UI or API

## Example: Research Parallelization

```markdown
# Parent Issue: Research Authentication Libraries

## Objective
Evaluate 5 authentication libraries for our use case.

## Subtasks to Create
1. Research Passport.js
2. Research Auth0 SDK
3. Research NextAuth
4. Research Clerk
5. Research custom JWT

## Completion Criteria
All subtasks have posted comparison JSON.
Parent synthesizes into recommendation.
```

This creates 5 parallel research tasks, each Claude instance evaluates one library, results aggregate into recommendation.

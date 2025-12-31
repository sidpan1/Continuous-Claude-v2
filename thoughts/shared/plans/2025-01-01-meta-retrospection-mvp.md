# Meta-Retrospection MVP: Experiment Design & Implementation Plan

## Overview

Use SWE-bench Lite as the **workload that drives self-improvement**. Each task provides verifiable ground truth (tests pass/fail) that feeds the learning loop. The system builds itself through iterative learning on real coding tasks.

**Core hypothesis**: Structured self-reflection + batch pattern analysis, trained on verifiable outcomes, reduces recurring failures and improves task success rates over time.

**Key insight**: SWE-bench isn't validation *after* building - it's the **feedback mechanism** that enables the system to learn and improve. Ground truth from test results creates a closed loop.

---

## Current State Analysis

### What Exists (67% complete)

| Component | Location | Status |
|-----------|----------|--------|
| **Continuity Ledger** | `thoughts/ledgers/` | Functional - survives /clear |
| **Handoffs with Post-Mortems** | `thoughts/shared/handoffs/` | Functional - captures What Worked/Failed |
| **Artifact Index (SQLite FTS5)** | `.claude/cache/artifact-index/context.db` | Functional - queryable with outcomes |
| **Compound Learnings Skill** | `.claude/skills/compound-learnings/` | Functional - manual pattern→artifact |
| **Recall Reasoning Skill** | `.claude/skills/recall-reasoning/` | Functional - queries past decisions |
| **Hooks Infrastructure** | `.claude/hooks/` | Functional - SessionEnd, PostToolUse |
| **Rules System** | `.claude/rules/` | Functional - 11 auto-loaded rules |
| **Braintrust Tracing** | `.claude/plugins/braintrust-tracing/` | Functional - requires API key |

### What's Missing (33% - MVP scope)

| Gap | Impact | Priority |
|-----|--------|----------|
| **Retrospection Capture** | No structured session reflection | P0 |
| **Intent File** | No north star for drift detection | P0 |
| **Meta-Retrospection Script** | No batch pattern analysis | P1 |
| **Outcome Inference** | Manual marking only | P2 |
| **Dashboard/Metrics** | No visibility into learning health | P2 |

---

## Desired End State

### MVP Definition of Done

1. **Intent file exists** and is loaded on SessionStart
2. **`/retrospect` command** captures structured JSON to `.claude/cache/retrospections/`
3. **SessionEnd hook** prompts for retrospection (optional, low-friction)
4. **Meta-retrospect script** analyzes N retrospections, outputs patterns + drift score
5. **Retrospections indexed** in artifact database for recall
6. **One full dogfood cycle** completed (MVP built using MVP)

### Verification

**Automated:**
- `ls .claude/cache/retrospections/*.json` returns files
- `python scripts/artifact_query.py --type retrospection` returns results
- `python scripts/meta_retrospect.py --batch 5` runs without error

**Manual:**
- Retrospection JSON contains required fields
- Meta-retrospection identifies at least one pattern from 5+ sessions
- Drift score correlates with human judgment (spot check 3 sessions)

---

## Key Discoveries

### From Infrastructure Analysis

1. **Handoffs already capture post-mortems** - Can bootstrap retrospections from existing handoff format
2. **Artifact index schema supports outcomes** - Just need to extend for retrospection type
3. **compound-learnings expects `.claude/cache/learnings/`** - Retrospections should feed this
4. **Hooks can match on tool patterns** - SessionEnd hook can trigger retrospection prompt

### From Experiment Design Review

1. **SWE-bench Lite is accessible** - `pip install datasets` + HuggingFace
2. **185 tasks is ambitious** - Start with 45 (15 per phase) for validation
3. **Within-subjects design is correct** - Matches compound learning hypothesis
4. **Cost estimate is reasonable** - ~$50-100 for full experiment

---

## What We're NOT Doing (MVP Scope)

1. **NOT building dashboard UI** - CLI commands only
2. **NOT implementing automatic rule creation** - Keep compound-learnings manual
3. **NOT integrating Braintrust traces** - Local-only, free components
4. **NOT building drift alerts** - Manual drift score review
5. **NOT implementing learning velocity metrics** - Simple pattern counts only

## Primary Target: Async Mode

**Async mode is built first** because:
1. SWE-bench tasks are ideal async workloads (bounded, isolated, verifiable)
2. Each task has clear completion criteria (tests pass)
3. Checkpoint reflections during async work enable mid-task learning
4. Escalation protocol develops naturally from hitting blockers
5. Self-correction emerges from test failure feedback

The learning system and async mode **co-evolve**: async work generates learnings, learnings improve async work.

## Execution Architecture: GitHub Actions (Cloud-First)

**Why GitHub over local SDK:**
- Unlimited parallelization (each workflow is isolated container)
- No local compute constraints
- Native coordination via issues, labels, comments
- Built-in logging and artifacts
- Cost effective: ~$0.02/session on Depot vs $0.35/min GitHub-hosted
- Human can @mention Claude for oversight when needed

**Official support**: `anthropics/claude-code-action` - install via `claude /install-github-app`

### GitHub-Based Orchestration

```
┌─────────────────────────────────────────────────────────────────┐
│  ORCHESTRATION FLOW                                              │
│                                                                  │
│  1. Create parent issue: "Run SWE-bench Batch 0"                │
│     └─ Label: 'batch-trigger'                                   │
│        ↓                                                         │
│  2. Workflow triggers → Claude analyzes → creates sub-issues    │
│     └─ Each sub-issue: task_id, repo, test command              │
│     └─ Label: 'swe-task', 'batch-0'                             │
│        ↓                                                         │
│  3. Sub-issue creation triggers parallel workflows              │
│     └─ Each runs independently in isolated container            │
│     └─ 5-10 tasks can run simultaneously                        │
│        ↓                                                         │
│  4. Per-task workflow:                                          │
│     ├─ Clone repo                                               │
│     ├─ Claude works on fix (max 30 min, 5 attempts)             │
│     ├─ Run tests → PASS/FAIL                                    │
│     ├─ Post retrospection as comment                            │
│     └─ Apply label: 'done' or 'failed'                          │
│        ↓                                                         │
│  5. Scheduled cron job (every 6 hours):                         │
│     ├─ Check: all sub-issues in batch labeled 'done'/'failed'?  │
│     ├─ If yes: run meta-retrospection                           │
│     ├─ Create summary issue with patterns                       │
│     └─ Auto-create next batch issue                             │
│        ↓                                                         │
│  6. Cycle continues → system improves autonomously              │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow Files

**`.github/workflows/batch-orchestrator.yml`**:
```yaml
name: Batch Orchestrator
on:
  issues:
    types: [opened, labeled]

jobs:
  create-subtasks:
    if: contains(github.event.issue.labels.*.name, 'batch-trigger')
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Analyze this batch request and create sub-issues for each SWE-bench task.
            For each task, create an issue with:
            - Title: [SWE-TASK] <task_id>
            - Body: Task details, repo URL, test command
            - Labels: swe-task, batch-N, priority
            Link back to parent issue #${{ github.event.issue.number }}
```

**`.github/workflows/swe-task-worker.yml`**:
```yaml
name: SWE Task Worker
on:
  issues:
    types: [labeled]

jobs:
  work-on-task:
    if: |
      contains(github.event.issue.labels.*.name, 'swe-task') &&
      github.event.label.name == 'ready'
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Edit,Bash,Glob,Grep"
          prompt: |
            Fix the issue described in this task.
            1. Clone the repository
            2. Understand the problem
            3. Implement the fix
            4. Run the test command to verify
            5. If tests pass: comment "COMPLETED" + retrospection JSON
            6. If tests fail after 5 attempts: comment "FAILED" + failure analysis

            Retrospection format:
            ```json
            {
              "outcome": "PASS|FAIL",
              "attempts": N,
              "what_worked": [...],
              "what_failed": [...],
              "learnings": [...]
            }
            ```

      - name: Update labels on completion
        uses: actions/github-script@v7
        with:
          script: |
            // Parse Claude's last comment for outcome
            // Apply 'done' or 'failed' label
```

**`.github/workflows/retrospective-scheduler.yml`**:
```yaml
name: Scheduled Retrospective
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:  # Manual trigger

jobs:
  check-and-retrospect:
    runs-on: ubuntu-latest
    steps:
      - name: Check batch completion
        uses: actions/github-script@v7
        id: check
        with:
          script: |
            // Find open batch issues
            // Check if all sub-tasks are done/failed
            // Return batch_id if complete

      - uses: anthropics/claude-code-action@v1
        if: steps.check.outputs.batch_complete == 'true'
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Run meta-retrospection on completed batch.
            1. Gather all retrospection comments from sub-issues
            2. Analyze patterns: recurring failures, successful approaches
            3. Calculate: success rate, avg attempts, common failure modes
            4. Generate learnings to apply to next batch
            5. Create summary issue with findings
            6. Create next batch trigger issue with learnings included
```

### State Management via Labels

```
Label State Machine:
  swe-task     → Task type identifier
  batch-N      → Batch grouping
  ready        → Triggers worker workflow
  in-progress  → Worker is active
  done         → Tests passed
  failed       → Max attempts exhausted
  blocked      → Needs human input
```

### Cost Estimate (GitHub Actions)

| Runner | Cost | 35 tasks × 30 min |
|--------|------|-------------------|
| GitHub-hosted | $0.35/min | ~$370 |
| Depot | $0.02/session | ~$0.70 |
| Self-hosted | $0 (your infra) | $0 |

**Recommendation**: Use Depot for 500x cost savings.

### Async Mode Architecture (SWE-bench Driven)

```
┌─────────────────────────────────────────────────────────────────┐
│  ASYNC SESSION                                                   │
│                                                                  │
│  Input: SWE-bench task (issue description, repo, tests)         │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Objective: Fix issue, make tests pass                       ││
│  │ Time limit: 30 min                                          ││
│  │ Constraints: From intent.yaml + prior learnings             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  Work loop:                                                      │
│  ├─ Analyze issue → form hypothesis                             │
│  ├─ Implement fix                                                │
│  ├─ Run tests → PASS/FAIL                                       │
│  │   ├─ PASS → complete, retrospect                             │
│  │   └─ FAIL → checkpoint reflection, retry (max 5)             │
│  │                                                               │
│  │  Every 10 min: checkpoint reflection                         │
│  │   ├─ Am I making progress?                                   │
│  │   ├─ Am I drifting from objective?                           │
│  │   └─ Should I try different approach?                        │
│  │                                                               │
│  └─ Max attempts or timeout → retrospect with failure modes     │
│                                                                  │
│  Output:                                                         │
│  ├─ Solution (if successful)                                    │
│  ├─ Structured retrospection (always)                           │
│  └─ Failure modes tagged (if failed)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Escalation Protocol (Learned from Failures)

```
Escalation triggers (pause for human input):
├─ Same approach fails 3 times
├─ Stuck for >15 min with no test progress
├─ Confidence drops below threshold
└─ Pattern matches known "need-human" failure modes

Self-correction triggers (no human needed):
├─ Test failure with clear error message
├─ Drift detected in checkpoint reflection
├─ Prior learning suggests alternative approach
└─ Time pressure forces hypothesis pruning
```

---

## Implementation Approach

### Strategy: SWE-bench as Learning Workload

SWE-bench tasks provide the **closed feedback loop** that trains the system. Each task has verifiable ground truth (tests pass or fail), enabling objective learning.

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE LEARNING LOOP                             │
│                                                                  │
│   SWE-bench task                                                 │
│        ↓                                                         │
│   Attempt solution                                               │
│        ↓                                                         │
│   Run tests → PASS/FAIL (ground truth)                          │
│        ↓                                                         │
│   Retrospect: what worked, what failed, why                     │
│        ↓                                                         │
│   Store structured learning                                      │
│        ↓                                                         │
│   Next task (apply prior learnings)                             │
│        ↓                                                         │
│   Every N tasks: meta-retrospect                                │
│        ↓                                                         │
│   Extract patterns, update approach                             │
│        ↓                                                         │
│   Continue with improved patterns                               │
│        ↓                                                         │
│   [Success rate should increase over batches]                   │
└─────────────────────────────────────────────────────────────────┘
```

### Bootstrap Sequence

The learning infrastructure is minimal to start - it grows as we learn what's needed:

```
Batch 0 (5 tasks):
  └─ Basic async runner + manual retrospection
  └─ Learn: what to capture, common failure modes
  └─ Build: retrospection schema, checkpoint format

Batch 1 (10 tasks):
  └─ Async with checkpoints + structured retrospection
  └─ Learn: when to escalate, what patterns emerge
  └─ Build: escalation triggers, pattern detection

Batch 2 (10 tasks):
  └─ + Meta-retrospection after batch
  └─ Learn: which learnings transfer, which are noise
  └─ Build: learning application mechanism

Batch 3 (10 tasks):
  └─ + Automated learning loading + self-correction
  └─ Learn: does success rate improve?
  └─ Build: full async loop with learning integration

Batch 4+ (N tasks):
  └─ Full system, iterate based on metrics
  └─ Measure: success rate trend, recurring issue reduction
```

**The system builds itself**: Each batch reveals what's missing, which gets built for the next batch. SWE-bench provides the ground truth that validates each iteration.

---

## Phase 0: GitHub Actions Setup

**Goal**: Set up GitHub-based orchestration for autonomous SWE-bench execution.

### 0.1 Install Claude GitHub App

```bash
# In repository root
claude /install-github-app

# This will:
# 1. Guide GitHub App installation
# 2. Set up ANTHROPIC_API_KEY secret
# 3. Create initial workflow file
```

### 0.2 Create Workflow Files

**File**: `.github/workflows/batch-orchestrator.yml`
- Triggers on issue with `batch-trigger` label
- Claude analyzes batch request
- Creates sub-issues for each SWE-bench task

**File**: `.github/workflows/swe-task-worker.yml`
- Triggers on `swe-task` + `ready` labels
- Clones target repo
- Claude works on fix (45 min timeout)
- Posts retrospection as comment
- Applies `done` or `failed` label

**File**: `.github/workflows/retrospective-scheduler.yml`
- Cron: every 6 hours
- Checks batch completion via GitHub API
- Runs meta-retrospection on completed batches
- Creates next batch trigger issue

### 0.3 Create Helper Scripts

**File**: `scripts/create_batch_issue.py`

```python
"""
Create a batch trigger issue with SWE-bench tasks.

USAGE:
    # Create batch with 5 random tasks
    python scripts/create_batch_issue.py --batch 0 --size 5

    # Create batch with specific tasks
    python scripts/create_batch_issue.py --batch 1 --tasks django__django-11583,pandas__pandas-25678
"""
import argparse
from github import Github
from datasets import load_dataset

def create_batch_issue(batch_num: int, task_ids: list[str], learnings: str = ""):
    """Create GitHub issue that triggers batch orchestration."""
    g = Github(os.environ["GITHUB_TOKEN"])
    repo = g.get_repo("owner/repo")

    body = f"""
## SWE-bench Batch {batch_num}

### Tasks
{chr(10).join(f'- [ ] {tid}' for tid in task_ids)}

### Prior Learnings
{learnings or 'None (baseline batch)'}

### Instructions
This issue will trigger the batch orchestrator workflow.
Sub-issues will be created for each task above.
"""

    issue = repo.create_issue(
        title=f"[BATCH-{batch_num}] Run SWE-bench ({len(task_ids)} tasks)",
        body=body,
        labels=["batch-trigger", f"batch-{batch_num}"]
    )
    return issue.number
```

**File**: `scripts/collect_retrospections.py`

```python
"""
Collect retrospection comments from completed batch.

USAGE:
    python scripts/collect_retrospections.py --batch 0 --output retrospections/batch-0.json
"""
# Queries GitHub API for all issues with batch-N label
# Extracts retrospection JSON from comments
# Aggregates into single file for meta-analysis
```

### 0.4 Set Up Labels

Create these labels in the repository:
- `batch-trigger` - Triggers orchestrator
- `swe-task` - Identifies SWE-bench task issues
- `batch-0`, `batch-1`, ... - Batch grouping
- `ready` - Task ready for worker
- `in-progress` - Worker active
- `done` - Tests passed
- `failed` - Max attempts exhausted
- `blocked` - Needs human review

### 0.5 Configure Depot (Optional, Recommended)

For 500x cost reduction:

```yaml
# .github/workflows/swe-task-worker.yml
jobs:
  work-on-task:
    runs-on: depot-ubuntu-22.04  # Instead of ubuntu-latest
```

Sign up at depot.dev, connect to GitHub.

### 0.6 Checkpoint Reflection (In-Task)

During async work, after each test failure:
```
Checkpoint:
- Attempt N of 5
- Test result: FAIL (specific error)
- Time elapsed: X min
- Hypothesis: what I thought would work
- Observation: what actually happened
- Next approach: what I'll try next
```

Stored in task working directory, aggregated into final retrospection.

### Success Criteria (Phase 0)

**Automated:**
- [ ] `scripts/swebench_loader.py --list` shows tasks
- [ ] `scripts/async_runner.py --task X` completes (pass or fail)
- [ ] Checkpoint files created during execution
- [ ] Final result (success/failure) recorded

**Manual:**
- [ ] Claude attempts reasonable solutions
- [ ] Checkpoints capture useful information
- [ ] Timeout/max-attempts enforced

---

## Phase 1: Retrospection Capture

**Goal**: Capture structured session reflections.

### 1.1 Create Intent File

**File**: `.claude/intent.yaml`

```yaml
# Project intent - North star for drift detection
version: 1

goals:
  - "Produce correct, working code on first attempt"
  - "Learn from failures to prevent recurrence"
  - "Minimize human debugging time"

anti_goals:
  - "Optimize for token efficiency at cost of correctness"
  - "Over-engineer simple solutions"
  - "Create artifacts without clear purpose"

success_signals:
  - "Tests pass without retry"
  - "No rework needed after review"
  - "Learnings from past sessions applied"

priorities:
  - correctness
  - maintainability
  - simplicity
```

### 1.2 Create Retrospection Schema

**File**: `src/schemas/retrospection.py`

```python
from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from enum import Enum

class OutcomeLevel(str, Enum):
    SUCCEEDED = "SUCCEEDED"
    PARTIAL_PLUS = "PARTIAL_PLUS"
    PARTIAL_MINUS = "PARTIAL_MINUS"
    FAILED = "FAILED"
    UNKNOWN = "UNKNOWN"

class Retrospection(BaseModel):
    # Metadata
    session_id: str
    created_at: datetime
    duration_minutes: Optional[int]

    # Context
    task_summary: str
    files_modified: list[str]

    # Reflection
    what_worked: list[str]
    what_failed: list[str]
    key_decisions: list[str]
    learnings: list[str]

    # Outcome
    self_assessed_outcome: OutcomeLevel
    human_marked_outcome: Optional[OutcomeLevel] = None
    confidence: str = "INFERRED"

    # Patterns (for meta-analysis)
    failure_modes: list[str] = []
    applied_learnings: list[str] = []  # From prior sessions
```

### 1.3 Create Retrospection Capture Script

**File**: `scripts/retrospect.py`

```python
"""
Capture structured session retrospection.

USAGE:
    # Interactive mode (prompts for reflection)
    uv run python -m runtime.harness scripts/retrospect.py

    # With pre-filled data (from hook)
    uv run python -m runtime.harness scripts/retrospect.py \
        --session-id "abc123" \
        --task "Implement feature X" \
        --outcome "SUCCEEDED"
"""
```

Core logic:
1. Gather session context (modified files from git, duration from timestamps)
2. Prompt Claude for structured reflection (what_worked, what_failed, etc.)
3. Save to `.claude/cache/retrospections/YYYY-MM-DD_HH-MM-SS_<session-id>.json`
4. Index in artifact database
5. Extract learnings to `.claude/cache/learnings/`

### 1.4 Create Retrospect Skill

**File**: `.claude/skills/retrospect/SKILL.md`

```markdown
# Retrospect Skill

## Use When
- End of coding session
- After completing a significant task
- When user says "let's reflect" or "what did we learn"

## Instructions
1. Summarize what was accomplished
2. Identify what worked well
3. Identify what failed or required retry
4. Extract key decisions made
5. Formulate learnings for future sessions
6. Run: `uv run python -m runtime.harness scripts/retrospect.py`
```

### 1.5 Add SessionEnd Hook (Optional Prompt)

**File**: `.claude/hooks/session-end-retrospect.sh`

```bash
#!/bin/bash
# Prompt for retrospection at session end (non-blocking)
echo '{"result": "Tip: Run /retrospect to capture learnings from this session."}'
```

Register in `.claude/settings.json`.

### Success Criteria (Phase 1)

**Automated:**
- [ ] `.claude/intent.yaml` exists and is valid YAML
- [ ] `scripts/retrospect.py` runs without error
- [ ] JSON file created in `.claude/cache/retrospections/`
- [ ] Retrospection indexed (query returns result)

**Manual:**
- [ ] Retrospection captures meaningful what_worked/what_failed
- [ ] Learnings are specific and actionable
- [ ] Self-assessed outcome matches human judgment

---

## Phase 2: Meta-Retrospection

**Goal**: Batch analysis of retrospections to detect patterns.

### 2.1 Create Meta-Retrospection Script

**File**: `scripts/meta_retrospect.py`

```python
"""
Analyze batch of retrospections to detect patterns.

USAGE:
    # Analyze last 5 retrospections
    uv run python -m runtime.harness scripts/meta_retrospect.py --batch 5

    # Analyze specific date range
    uv run python -m runtime.harness scripts/meta_retrospect.py \
        --from "2025-01-01" --to "2025-01-07"

    # Output format
    uv run python -m runtime.harness scripts/meta_retrospect.py \
        --batch 10 --format json
"""
```

Core logic:
1. Load N retrospections from `.claude/cache/retrospections/`
2. Aggregate failure_modes, learnings, outcomes
3. Detect recurring patterns (3+ occurrences)
4. Calculate drift score vs intent file
5. Generate recommendations
6. Output report to `.claude/cache/meta-retrospections/`

### 2.2 Pattern Detection Algorithm

```python
def detect_patterns(retrospections: list[Retrospection]) -> PatternReport:
    # Count failure modes
    failure_counts = Counter()
    for r in retrospections:
        for mode in r.failure_modes:
            failure_counts[mode] += 1

    # Recurring = 3+ occurrences
    recurring = {k: v for k, v in failure_counts.items() if v >= 3}

    # Learning application rate
    total_learnings = sum(len(r.learnings) for r in retrospections)
    applied = sum(len(r.applied_learnings) for r in retrospections)
    application_rate = applied / total_learnings if total_learnings > 0 else 0

    # Success rate
    successes = sum(1 for r in retrospections
                    if r.self_assessed_outcome == OutcomeLevel.SUCCEEDED)
    success_rate = successes / len(retrospections)

    return PatternReport(
        recurring_issues=recurring,
        learning_application_rate=application_rate,
        success_rate=success_rate,
        total_sessions=len(retrospections)
    )
```

### 2.3 Drift Scoring

```python
def calculate_drift(retrospections: list[Retrospection],
                    intent: Intent) -> float:
    """
    Score 0.0 (aligned) to 1.0 (completely drifted).

    Factors:
    - Are learnings aligned with goals?
    - Are failure modes related to anti-goals?
    - Is success rate improving toward success_signals?
    """
    # Simple v1: keyword overlap
    goal_keywords = extract_keywords(intent.goals)
    learning_keywords = extract_keywords([l for r in retrospections
                                          for l in r.learnings])

    overlap = len(goal_keywords & learning_keywords)
    max_possible = len(goal_keywords)

    alignment = overlap / max_possible if max_possible > 0 else 0
    drift = 1.0 - alignment

    return drift
```

### 2.4 Create Meta-Retrospect Skill

**File**: `.claude/skills/meta-retrospect/SKILL.md`

### Success Criteria (Phase 2)

**Automated:**
- [ ] `scripts/meta_retrospect.py --batch 5` runs on 5 retrospections
- [ ] Output includes recurring_issues, success_rate, drift_score
- [ ] Report saved to `.claude/cache/meta-retrospections/`

**Manual:**
- [ ] Detected patterns are meaningful (not noise)
- [ ] Drift score > 0.5 when learnings diverge from intent
- [ ] Recommendations are actionable

---

## Phase 3: Integration & Dogfood Cycle

**Goal**: Complete learning loop, validate by building the system.

### 3.1 Connect to Compound Learnings

Update compound-learnings skill to consume meta-retrospection output:

```markdown
## Updated Source Priority

1. Meta-retrospection reports (highest signal)
2. Individual retrospections
3. Handoff post-mortems
4. Raw learnings files
```

### 3.2 Add to Artifact Index

Extend `scripts/artifact_schema.sql`:

```sql
-- Add retrospections table
CREATE TABLE IF NOT EXISTS retrospections (
    id INTEGER PRIMARY KEY,
    session_id TEXT UNIQUE,
    created_at TEXT,
    task_summary TEXT,
    outcome TEXT,
    content TEXT,  -- Full JSON
    embedding BLOB  -- For similarity search
);

CREATE VIRTUAL TABLE IF NOT EXISTS retrospections_fts USING fts5(
    task_summary, content,
    content='retrospections',
    content_rowid='id',
    tokenize='porter unicode61'
);
```

### 3.3 Dogfood Cycle

Execute one complete cycle while building:

```
1. Build Phase 1 (retrospection capture)
2. /retrospect → capture learnings about building Phase 1
3. Build Phase 2 (meta-retrospection)
4. /retrospect → capture learnings about building Phase 2
5. Run /meta-retrospect on both retrospections
6. Apply any patterns detected to Phase 3
7. Complete Phase 3 with learnings applied
8. Final /meta-retrospect on all 3 phases
```

### Success Criteria (Phase 3)

**Automated:**
- [ ] 3+ retrospections captured during MVP build
- [ ] Meta-retrospection runs on dogfood retrospections
- [ ] At least one pattern detected from dogfood sessions

**Manual:**
- [ ] Learnings from Phase 1 visible in Phase 3 work
- [ ] Fewer retries in later phases
- [ ] Developer reports reduced friction

---

## Phase 4: SWE-bench Validation

**Goal**: Validate improvement on public benchmark.

### 4.1 Minimal Experiment (Recommended Start)

| Phase | Tasks | Learning Condition |
|-------|-------|-------------------|
| Baseline | 15 | None |
| Retrospection | 15 | After each task |
| Meta-Retrospection | 15 | After each task + batch every 5 |

**Total**: 45 tasks, ~$15-30, ~1-2 days

### 4.2 Task Selection

```python
from datasets import load_dataset

swebench = load_dataset('princeton-nlp/SWE-bench_Lite', split='test')

# Stratified sample: 45 tasks
# - 25 bug fixes (9 easy, 10 medium, 6 hard)
# - 12 features (4 easy, 5 medium, 3 hard)
# - 8 refactors (3 easy, 3 medium, 2 hard)
```

### 4.3 Experiment Script

**File**: `scripts/run_experiment.py`

```python
"""
Run meta-retrospection experiment on SWE-bench.

USAGE:
    # Minimal experiment (45 tasks)
    uv run python -m runtime.harness scripts/run_experiment.py \
        --size minimal --output experiments/exp-001/

    # Full experiment (185 tasks)
    uv run python -m runtime.harness scripts/run_experiment.py \
        --size full --output experiments/exp-002/
"""
```

### 4.4 Metrics Collection

Per task:
- `success`: bool (tests pass)
- `attempts`: int (retries needed)
- `time_to_solution`: float (minutes)
- `failure_mode`: str (if failed)
- `learnings_applied`: list[str]

Per phase:
- `success_rate`: float
- `avg_attempts`: float
- `recurring_issue_rate`: float

### 4.5 Analysis

```python
# Primary: Success rate by condition
from scipy.stats import cochrans_q
q_stat, p_value = cochrans_q([baseline, retrospection, meta])

# Secondary: Recurring issue reduction
baseline_recurring = recurring_issue_rate(baseline_failures)
meta_recurring = recurring_issue_rate(meta_failures)
reduction = (baseline_recurring - meta_recurring) / baseline_recurring
```

### Success Criteria (Phase 4)

**Quantitative:**
- [ ] Success rate increases: Baseline < Retrospection < Meta-Retrospection
- [ ] Recurring issue rate decreases: >20% reduction from baseline to meta
- [ ] Learning application rate: >40% of prior learnings used

**Statistical:**
- [ ] Cochran's Q test p < 0.05 for success rate difference
- [ ] Effect size (Cohen's h) > 0.3

---

## Experiment Design: Self-Improving Batches

### Design: Iterative Learning on SWE-bench

Not "baseline vs treatment" - instead, **continuous improvement measured over batches**:

```
Batch 0:  5 tasks  │ Async runner only, manual notes
          ─────────┼─────────────────────────────────
          Measure: baseline success rate, common failures
          Build:   retrospection capture

Batch 1: 10 tasks  │ + Structured retrospection
          ─────────┼─────────────────────────────────
          Measure: are retrospections useful?
          Build:   checkpoint reflections, escalation

Batch 2: 10 tasks  │ + Meta-retrospection, learning loading
          ─────────┼─────────────────────────────────
          Measure: success rate delta from Batch 0/1
          Build:   pattern detection, self-correction

Batch 3: 10 tasks  │ + Full learning loop
          ─────────┼─────────────────────────────────
          Measure: recurring issue reduction
          Build:   automated learning application

Batch 4+: N tasks  │ Iterate based on metrics
          ─────────┼─────────────────────────────────
          Measure: success rate trend over time
          Build:   whatever's needed
───────────────────────────────────────────────────────
Total: 35+ tasks, ~$30-60, system improves as it runs
```

### Success Metric: Improvement Trend

Instead of comparing discrete phases, measure:
- **Success rate per batch** (should trend upward)
- **Recurring issue rate per batch** (should trend downward)
- **Learning application rate** (should trend upward)

```
Expected trajectory:

Success rate:
Batch 0: 15-20% (baseline)
Batch 1: 20-25% (retrospection helps)
Batch 2: 25-35% (meta-patterns applied)
Batch 3: 35-45% (full loop working)
Batch 4: 40-50% (continued improvement)
```

### Why This Design?

1. **No artificial separation** - learning is continuous, not phased
2. **Each batch builds on previous** - matches compound learning hypothesis
3. **Ground truth every task** - tests pass/fail, no ambiguity
4. **System improves while running** - not "build then test"
5. **Natural stopping point** - stop when improvement plateaus

---

## Timeline

### Integrated Build-and-Learn Approach (GitHub-Based)

Build and learn happen together. Each batch builds what's needed for the next.
**Parallelization via GitHub Actions enables faster iteration.**

| Day | Activity | Build | Learn |
|-----|----------|-------|-------|
| 1 | Setup | Install GitHub App, create workflows, set up labels | - |
| 2 | Batch 0 | Create batch issue (5 tasks) → runs in parallel | Baseline failures |
| 3 | Analysis | Collect retrospections, create meta-retrospect workflow | What to capture |
| 4 | Batch 1 | Create batch with learnings (10 tasks) → parallel | Patterns emerge |
| 5 | Meta | Scheduled job runs, creates summary issue | Pattern detection |
| 6 | Batch 2 | Create batch with patterns (10 tasks) → parallel | Transfer test |
| 7 | Full loop | Verify auto-cycle: batch complete → meta → next batch | Autonomy works |
| 8 | Batch 3 | System creates batch autonomously (10 tasks) | Self-improvement |
| 9 | Analysis | Measure success rate trend across batches | - |

**Total**: ~9 days, 35 tasks, ~$1-5 (Depot) or ~$370 (GitHub-hosted)

### Critical Path

```
Day 1: GitHub Action installed and working
       └─ Can trigger Claude from issue comment
Day 2: Batch 0 completes (5 tasks run in parallel)
       └─ Retrospection comments on each task issue
Day 5: Meta-retrospection runs automatically
       └─ Scheduled job creates summary + next batch
Day 7: Full autonomous loop verified
       └─ No human intervention needed for batch cycle
Day 9: Improvement measured
       └─ Batch 3 success rate > Batch 0
```

### Parallelization Advantage

```
Local SDK (sequential):
  Task 1 (30 min) → Task 2 (30 min) → Task 3 (30 min)
  Total: 90 min for 3 tasks

GitHub Actions (parallel):
  Task 1 ─┐
  Task 2 ─┼─→ All complete in ~30 min
  Task 3 ─┘
  Total: 30 min for 3 tasks (3x faster)

With 5 parallel workers:
  Batch of 10 tasks: 2 rounds × 30 min = 60 min (vs 300 min sequential)
```

---

## File Structure (Final)

```
.github/
├── workflows/
│   ├── batch-orchestrator.yml           # NEW: Issue → sub-issues
│   ├── swe-task-worker.yml              # NEW: Work on individual task
│   └── retrospective-scheduler.yml      # NEW: Cron meta-retrospection
└── ISSUE_TEMPLATE/
    └── swe-batch.md                     # NEW: Batch trigger template

.claude/
├── intent.yaml                          # NEW: Project goals (drift detection)
├── cache/
│   ├── retrospections/                  # NEW: Aggregated from GitHub
│   │   └── batch-N.json
│   ├── meta-retrospections/             # NEW: Batch analyses
│   │   └── batch-N-meta.json
│   └── learnings/                        # NEW: Extracted patterns
│       └── <pattern-hash>.md
├── skills/
│   ├── retrospect/SKILL.md              # NEW
│   └── meta-retrospect/SKILL.md         # NEW
└── hooks/
    └── session-end-retrospect.sh        # OPTIONAL (for local dev)

scripts/
├── create_batch_issue.py                # NEW: Create batch trigger issue
├── collect_retrospections.py            # NEW: Gather from GitHub comments
├── meta_retrospect.py                   # NEW: Batch analysis
└── artifact_schema.sql                  # UPDATED: Add retrospections

docs/meta-learning/
├── concept-note.md                      # Existing
├── product-spec.md                      # Existing
└── experiment-results.md                # NEW: After batches complete
```

**Note**: GitHub Issues serve as the primary data store during execution.
Retrospections are posted as comments, aggregated by scripts after batch completion.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Retrospections too vague | Structured prompts with required fields |
| Meta-retrospection finds noise | Threshold at 3+ occurrences |
| SWE-bench tasks too hard | Start with "easy" subset |
| Cost overrun | Stop after minimal, expand if signal |
| Dogfood reveals major issues | Time-boxed fixes, document for v2 |

---

## References

- [Concept Note](../../../docs/meta-learning/concept-note.md)
- [Product Spec](../../../docs/meta-learning/product-spec.md)
- [SWE-bench Lite](https://huggingface.co/datasets/princeton-nlp/SWE-bench_Lite)
- [Artifact Index Schema](../../scripts/artifact_schema.sql)
- [Compound Learnings Skill](../../.claude/skills/compound-learnings/SKILL.md)

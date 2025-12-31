# Meta-Retrospection MVP: Experiment Design & Implementation Plan

## Overview

Build a meta-retrospection system that enables Claude Code to learn from sessions and improve over time. Validate through dogfooding (building the system) then benchmark against SWE-bench Lite.

**Core hypothesis**: Structured self-reflection + batch pattern analysis reduces recurring failures and improves task success rates.

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

1. **NOT building async mode** - Sync retrospection only
2. **NOT building dashboard UI** - CLI commands only
3. **NOT implementing automatic rule creation** - Keep compound-learnings manual
4. **NOT integrating Braintrust traces** - Local-only, free components
5. **NOT building drift alerts** - Manual drift score review
6. **NOT implementing learning velocity metrics** - Simple pattern counts only

---

## Implementation Approach

### Strategy: Dogfood-First Development

Build MVP in phases, using retrospection after each phase to capture learnings. This validates the system while building it.

```
Phase 1: Build retrospection capture
  └─ Manual retrospection after phase
Phase 2: Build meta-retrospection
  └─ Run meta-retrospect on Phase 1 retrospection
Phase 3: Integration & dogfood cycle
  └─ Full loop: work → retrospect → meta-retrospect → apply
Phase 4: SWE-bench validation
  └─ Run experiment on benchmark
```

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

## Revised Experiment Design

### Design: Minimal Within-Subjects (Recommended)

```
Phase 0: Warmup (5 tasks, discarded)
Phase 1: Baseline (15 tasks, no learning)
Phase 2: Retrospection (15 tasks, +retrospect after each)
Phase 3: Meta-Retrospection (15 tasks, +meta every 5)
---
Total: 50 tasks (~$20-40)
```

### Why Minimal First?

1. **Validate infrastructure** before committing to 185 tasks
2. **Iterate on retrospection prompts** based on early results
3. **Confirm signal exists** before scaling up
4. **Lower cost/risk** for initial validation

### Expansion Path

If minimal shows signal (success rate delta > 10%):
1. Run full experiment (185 tasks)
2. Add Phase 4: Human Policy Tuning (25 tasks)
3. Publish results with statistical analysis

### Key Changes from Original Design

| Original | Revised | Rationale |
|----------|---------|-----------|
| 185 tasks | 45 tasks (minimal) | Validate first |
| 4 phases | 3 phases (skip human policy for MVP) | Focus on automated learning |
| External drift scoring | Keyword-based drift | Simpler, no embeddings needed |
| Braintrust integration | Local-only | Free, self-contained |

---

## Timeline

### Week 1: Foundation (Phase 1-2)

| Day | Activity |
|-----|----------|
| Day 1 | Create intent file, retrospection schema |
| Day 2 | Build retrospect.py script |
| Day 3 | Build meta_retrospect.py script |
| Day 4 | Integration, artifact indexing |
| Day 5 | Dogfood: retrospect on Days 1-4 |

### Week 2: Validation (Phase 3-4)

| Day | Activity |
|-----|----------|
| Day 1 | Complete dogfood cycle, fix issues |
| Day 2 | Set up SWE-bench, run warmup |
| Day 3-4 | Run minimal experiment (45 tasks) |
| Day 5 | Analysis, write results |

---

## File Structure (Final)

```
.claude/
├── intent.yaml                          # NEW: Project goals
├── cache/
│   ├── retrospections/                  # NEW: Session reflections
│   │   └── YYYY-MM-DD_HH-MM-SS_<id>.json
│   ├── meta-retrospections/             # NEW: Batch analyses
│   │   └── YYYY-MM-DD_batch-N.json
│   └── learnings/                        # NEW: Extracted patterns
│       └── <pattern-hash>.md
├── skills/
│   ├── retrospect/SKILL.md              # NEW
│   └── meta-retrospect/SKILL.md         # NEW
└── hooks/
    └── session-end-retrospect.sh        # NEW (optional)

scripts/
├── retrospect.py                        # NEW: Capture reflections
├── meta_retrospect.py                   # NEW: Batch analysis
├── run_experiment.py                    # NEW: SWE-bench runner
└── artifact_schema.sql                  # UPDATED: Add retrospections

docs/meta-learning/
├── concept-note.md                      # Existing
├── product-spec.md                      # Existing
└── experiment-results.md                # NEW: After Phase 4

experiments/
└── exp-001/                             # NEW: Experiment data
    ├── config.json
    ├── tasks/
    ├── retrospections/
    └── analysis/
```

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

# Meta-Learning System: Product Specification

## Overview

This specification defines the meta-learning system for Continuous-Claude-v2. The system enables Claude Code to learn from past sessions through structured retrospection and batch analysis.

**Scope:** Local-only implementation using existing free infrastructure. No external paid services (Braintrust, etc.).

**Integration Principle:** Extend existing components rather than create parallel systems.

## Architecture Summary

```
┌──────────────────────────────────────────────────────────────────┐
│ HUMAN LAYER                                                       │
│ .claude/intent.yaml (goals) + policy thresholds                   │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ META-RETROSPECTOR                                                 │
│ scripts/meta_retrospect.py → .claude/cache/meta/                  │
│ Trigger: manual /meta-retrospect or every N sessions              │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ RETROSPECTOR                                                      │
│ /retrospect skill → .claude/cache/retrospections/                 │
│ Trigger: manual or SessionEnd hook                                │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ WORKER (existing Claude Code session)                             │
│ Influenced by: .claude/rules/, .claude/skills/, ledgers           │
└──────────────────────────────────────────────────────────────────┘
```

---

## Epic 1: Structured Retrospection (P0 - Foundation)

### Story 1.1: Retrospection Schema

**As a** system designer
**I want** a well-defined schema for retrospection data
**So that** downstream tools can process retrospections programmatically

#### Schema Definition

```python
# src/schemas/retrospection.py

from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from enum import Enum

class OutcomeLevel(str, Enum):
    SUCCEEDED = "succeeded"
    PARTIAL_PLUS = "partial_plus"    # More worked than failed
    PARTIAL_MINUS = "partial_minus"  # More failed than worked
    FAILED = "failed"
    UNKNOWN = "unknown"

class Learning(BaseModel):
    """A single actionable insight from the session."""
    category: str                    # "approach", "tool_usage", "pattern", "anti_pattern"
    description: str                 # What was learned
    evidence: str                    # Specific example from session
    actionable: bool                 # Can this become a rule/skill?
    related_files: list[str] = []   # Files involved

class Decision(BaseModel):
    """A significant choice made during the session."""
    description: str                 # What was decided
    alternatives: list[str]          # What else was considered
    rationale: str                   # Why this choice
    confidence: str                  # "high", "medium", "low"

class Retrospection(BaseModel):
    """Structured output from session retrospection."""
    # Identity
    id: str                          # UUID
    session_id: Optional[str]        # Links to handoff if exists
    timestamp: datetime

    # Context
    task_summary: str                # What was the session trying to do
    intent_alignment: str            # How well did this align with .claude/intent.yaml

    # Assessment
    outcome: OutcomeLevel
    outcome_rationale: str           # Why this outcome level

    # Learnings
    what_worked: list[Learning]
    what_failed: list[Learning]
    key_decisions: list[Decision]

    # Patterns (for compound-learnings consumption)
    patterns: list[str]              # Reusable techniques identified
    anti_patterns: list[str]         # Things to avoid

    # Metadata
    duration_minutes: Optional[int]
    files_modified: list[str]
    tools_used: list[str]

    # Linking
    handoff_id: Optional[str]        # If handoff was created
    ledger_id: Optional[str]         # Active ledger during session
    parent_meta_batch: Optional[str] # Set when processed by meta-retrospect
```

#### Tasks
- [ ] Create `src/schemas/retrospection.py` with Pydantic models
- [ ] Create `src/schemas/meta_retrospection.py` for batch analysis output
- [ ] Add schema validation tests
- [ ] Document schema in `docs/meta-learning/schemas.md`

#### Acceptance Criteria
- [ ] Schema handles all fields from existing learnings format
- [ ] Schema validates with Pydantic (type safety)
- [ ] Schema is extensible (new fields don't break old data)
- [ ] Example retrospection JSON passes validation

#### Integration Points
- **Extends:** Current unstructured `.claude/cache/learnings/*.md` concept
- **Consumed by:** `compound-learnings` skill, `meta_retrospect.py`, artifact index

**Complexity:** Low (1-2 days)

---

### Story 1.2: Retrospection Storage

**As a** system
**I want** retrospections stored in queryable format
**So that** batch analysis can efficiently process them

#### Storage Design

```
.claude/cache/retrospections/
├── 2024-01-15_session-abc123.json    # Individual retrospections
├── 2024-01-16_session-def456.json
├── ...
└── index.db                           # SQLite index
```

#### SQLite Schema (extends existing artifact-index)

```sql
-- Add to existing .claude/cache/artifact-index/context.db

CREATE TABLE IF NOT EXISTS retrospections (
    id TEXT PRIMARY KEY,
    session_id TEXT,
    timestamp TEXT,
    task_summary TEXT,
    outcome TEXT,
    patterns TEXT,              -- JSON array
    anti_patterns TEXT,         -- JSON array
    handoff_id TEXT,
    ledger_id TEXT,
    meta_batch_id TEXT,         -- Set when processed
    file_path TEXT,             -- Path to full JSON
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (handoff_id) REFERENCES handoffs(id)
);

CREATE INDEX idx_retro_outcome ON retrospections(outcome);
CREATE INDEX idx_retro_timestamp ON retrospections(timestamp);
CREATE INDEX idx_retro_meta_batch ON retrospections(meta_batch_id);

-- FTS5 for searching retrospection content
CREATE VIRTUAL TABLE IF NOT EXISTS retrospections_fts USING fts5(
    task_summary,
    patterns,
    anti_patterns,
    content='retrospections',
    content_rowid='rowid'
);
```

#### Tasks
- [ ] Add retrospections table to `scripts/artifact_index.py`
- [ ] Create `scripts/retrospection_store.py` for CRUD operations
- [ ] Add migration script for existing installations
- [ ] Create index rebuild utility

#### Acceptance Criteria
- [ ] Retrospections indexed on save (not batch)
- [ ] FTS5 search returns relevant retrospections
- [ ] Can query by outcome, date range, pattern keywords
- [ ] Storage handles 1000+ retrospections without degradation

#### Integration Points
- **Extends:** Existing `artifact-index/context.db`
- **Pattern:** Matches handoffs table structure

**Complexity:** Medium (2-3 days)

---

### Story 1.3: Retrospect Skill

**As a** Claude Code user
**I want** a `/retrospect` command
**So that** I can capture structured learnings before ending a session

#### Skill Design

The retrospect skill triggers Claude's self-reflection and outputs structured JSON.

**Key insight:** This is self-reflection, not external analysis. Claude reviews its own session while context is fresh.

#### Skill File

```markdown
# .claude/skills/retrospect/SKILL.md

---
name: retrospect
description: Capture structured learnings from current session via self-reflection
allowed-tools: [Read, Write, Glob]
---

# Retrospect

Reflect on the current session and capture structured learnings.

## When to Use

- Before ending a significant work session
- After completing a task (success or failure)
- When asked to "capture learnings" or "what did we learn"
- Automatically via SessionEnd hook (if enabled)

## Process

### Step 1: Load Context

Read the intent file to understand alignment goals:

```bash
cat $CLAUDE_PROJECT_DIR/.claude/intent.yaml
```

Read the active ledger (if any) to understand session goals:

```bash
ls -t $CLAUDE_PROJECT_DIR/thoughts/ledgers/*.md | head -1 | xargs cat
```

### Step 2: Self-Reflect

Consider the following questions:

**Task Summary:**
- What was this session trying to accomplish?
- How well did it align with the project intent?

**Outcome Assessment:**
- Did the task succeed, partially succeed, or fail?
- What's the evidence for this assessment?

**What Worked:**
- Which approaches led to progress?
- What tool usage was effective?
- What patterns emerged that could be reused?

**What Failed:**
- Which approaches were abandoned? Why?
- What blockers were encountered?
- What would you do differently?

**Key Decisions:**
- What significant choices were made?
- What alternatives were considered?
- Why was this path chosen?

**Patterns:**
- What reusable techniques emerged?
- What anti-patterns should be avoided?

### Step 3: Generate Structured Output

Create a JSON file following the Retrospection schema:

```bash
# Generate filename
TIMESTAMP=$(date +%Y-%m-%d)
SESSION_ID=$(echo $RANDOM | md5sum | head -c 8)
OUTPUT_FILE="$CLAUDE_PROJECT_DIR/.claude/cache/retrospections/${TIMESTAMP}_session-${SESSION_ID}.json"
```

Write the retrospection JSON to this file.

### Step 4: Index for Search

```bash
uv run python $CLAUDE_PROJECT_DIR/scripts/retrospection_store.py \
    --index "$OUTPUT_FILE"
```

### Step 5: Report

Summarize what was captured:

```markdown
## Retrospection Captured

**File:** `.claude/cache/retrospections/YYYY-MM-DD_session-XXX.json`
**Outcome:** [succeeded/partial/failed]
**Patterns identified:** N
**Anti-patterns identified:** M

Key learnings:
1. [First learning]
2. [Second learning]
...
```

## Quality Guidelines

- Be specific: Reference actual files, tools, errors
- Be honest: Don't inflate successes or hide failures
- Be actionable: Patterns should be applicable to future sessions
- Be concise: Each learning should be 1-2 sentences
```

#### Tasks
- [ ] Create `.claude/skills/retrospect/SKILL.md`
- [ ] Add triggers to `skill-rules.json` ("retrospect", "capture learnings", "what did we learn")
- [ ] Create `scripts/retrospection_store.py` for indexing
- [ ] Test skill produces valid schema output

#### Acceptance Criteria
- [ ] `/retrospect` command discoverable in Claude Code
- [ ] Produces valid JSON matching schema
- [ ] Indexes to SQLite on completion
- [ ] Works without active ledger or handoff (graceful handling)
- [ ] Self-reflection captures context external tools would miss

#### Integration Points
- **Uses:** Intent file (`.claude/intent.yaml`), active ledger
- **Produces:** JSON in `.claude/cache/retrospections/`
- **Indexes to:** `artifact-index/context.db`
- **Consumed by:** `compound-learnings`, `meta-retrospect`

**Complexity:** Medium (2-3 days)

---

### Story 1.4: Outcome Tracking Integration

**As a** system
**I want** retrospection outcomes linked to handoffs
**So that** we can correlate learnings with actual success/failure

#### Design

Outcomes can come from two sources:
1. **Self-assessed:** Claude's judgment during retrospection
2. **Human-marked:** User override via existing `artifact_mark.py`

When a handoff exists, link the retrospection to it:

```json
{
  "outcome": "partial_plus",
  "outcome_source": "self_assessed",
  "handoff_id": "task-implement-feature-2024-01-15",
  "human_override": null
}
```

When human marks handoff outcome, propagate to linked retrospection:

```bash
# Existing command
python scripts/artifact_mark.py --handoff task-xyz --outcome SUCCEEDED

# Also updates linked retrospection if exists
```

#### Tasks
- [ ] Add `handoff_id` foreign key to retrospections table
- [ ] Modify `artifact_mark.py` to update linked retrospection
- [ ] Add outcome reconciliation logic (human > self-assessed)
- [ ] Create query: "retrospections with mismatched self vs human outcome"

#### Acceptance Criteria
- [ ] Retrospection links to handoff when one exists
- [ ] Human outcome marking updates retrospection
- [ ] Can query for calibration data (self vs human disagreements)
- [ ] No orphan retrospections (always linkable to session context)

#### Integration Points
- **Extends:** Existing `artifact_mark.py` and handoffs table
- **Enables:** Calibration of self-assessment over time

**Complexity:** Low (1-2 days)

---

## Epic 2: Meta-Retrospection (P1 - Core)

### Story 2.1: Meta-Retrospection Script

**As a** system
**I want** to analyze batches of retrospections
**So that** I can detect trends and recurring issues

#### Script Design

```python
# scripts/meta_retrospect.py

"""
Meta-retrospection: Batch analysis of retrospections.

Usage:
    # Analyze last 10 retrospections
    uv run python scripts/meta_retrospect.py --batch 10

    # Analyze specific date range
    uv run python scripts/meta_retrospect.py --from 2024-01-01 --to 2024-01-15

    # Output format
    uv run python scripts/meta_retrospect.py --batch 10 --format json
    uv run python scripts/meta_retrospect.py --batch 10 --format markdown
"""
```

#### Analysis Components

**1. Trend Detection**
```python
def detect_trends(retrospections: list[Retrospection]) -> TrendAnalysis:
    """
    Analyze outcome trends over time.

    Returns:
        - outcome_distribution: {succeeded: N, partial: M, failed: K}
        - trend_direction: "improving" | "stable" | "degrading"
        - trend_confidence: float (statistical significance)
    """
```

**2. Recurring Issue Detection**
```python
def find_recurring_issues(retrospections: list[Retrospection]) -> list[RecurringIssue]:
    """
    Find patterns that appear in multiple failed/partial sessions.

    Returns issues with:
        - pattern: str (the recurring problem)
        - frequency: int (how many sessions)
        - session_ids: list[str] (which sessions)
        - suggested_action: str (rule? skill? process change?)
    """
```

**3. Learning Application Rate**
```python
def calculate_application_rate(retrospections: list[Retrospection]) -> float:
    """
    Measure if previous learnings are being applied.

    Method:
        1. Get patterns from retrospection N
        2. Check if patterns addressed in N+1, N+2, ... (via rules/skills created)
        3. Rate = (patterns that led to artifacts) / (total actionable patterns)
    """
```

**4. Effectiveness Correlation**
```python
def correlate_effectiveness(
    retrospections: list[Retrospection],
    rules: list[str],
    skills: list[str]
) -> list[EffectivenessScore]:
    """
    Which rules/skills correlate with successful outcomes?

    Returns:
        - artifact: str (rule or skill name)
        - sessions_active: int
        - success_rate_when_active: float
        - success_rate_baseline: float
    """
```

#### Output Schema

```python
class MetaRetrospection(BaseModel):
    id: str
    batch_id: str
    timestamp: datetime

    # Scope
    retrospection_ids: list[str]
    date_range: tuple[datetime, datetime]

    # Analysis
    outcome_distribution: dict[str, int]
    trend: TrendAnalysis
    recurring_issues: list[RecurringIssue]
    application_rate: float
    effectiveness_scores: list[EffectivenessScore]

    # Recommendations
    recommendations: list[Recommendation]

    # Drift (if intent file exists)
    drift_score: Optional[float]
    drift_details: Optional[str]

    # For compound-learnings
    prioritized_patterns: list[PrioritizedPattern]
```

#### Tasks
- [ ] Create `scripts/meta_retrospect.py` with CLI interface
- [ ] Implement trend detection algorithm
- [ ] Implement recurring issue detection (fuzzy matching on patterns)
- [ ] Implement application rate calculation
- [ ] Implement effectiveness correlation
- [ ] Create `src/schemas/meta_retrospection.py`
- [ ] Add unit tests for each analysis component

#### Acceptance Criteria
- [ ] Processes batch of N retrospections in <30 seconds
- [ ] Correctly identifies issues appearing 3+ times
- [ ] Application rate matches manual verification on 5 samples
- [ ] Outputs valid JSON matching schema
- [ ] Handles edge cases (0 retrospections, all same outcome, etc.)

#### Integration Points
- **Consumes:** `.claude/cache/retrospections/*.json`
- **Produces:** `.claude/cache/meta/<batch-id>.json`
- **Feeds:** `compound-learnings` with prioritized patterns

**Complexity:** High (5-7 days)

---

### Story 2.2: Meta-Retrospect Skill

**As a** Claude Code user
**I want** a `/meta-retrospect` command
**So that** I can trigger batch analysis and see recommendations

#### Skill File

```markdown
# .claude/skills/meta-retrospect/SKILL.md

---
name: meta-retrospect
description: Analyze batches of past retrospections to detect trends and recurring issues
allowed-tools: [Read, Bash, Glob]
---

# Meta-Retrospect

Batch analysis of retrospections to detect patterns in learning effectiveness.

## When to Use

- "How is the system learning?"
- "What patterns keep recurring?"
- "Are my rules/skills effective?"
- "Run meta-analysis"
- Weekly/monthly review of learning health

## Process

### Step 1: Check Data Availability

```bash
# Count available retrospections
ls $CLAUDE_PROJECT_DIR/.claude/cache/retrospections/*.json 2>/dev/null | wc -l
```

Minimum 5 retrospections recommended for meaningful analysis.

### Step 2: Run Analysis

```bash
uv run python $CLAUDE_PROJECT_DIR/scripts/meta_retrospect.py \
    --batch 10 \
    --format markdown
```

### Step 3: Review Output

The script produces:

1. **Trend Analysis**: Is learning improving, stable, or degrading?
2. **Recurring Issues**: Problems appearing 3+ times
3. **Application Rate**: Are learnings being applied?
4. **Effectiveness Scores**: Which rules/skills correlate with success?
5. **Recommendations**: Suggested actions

### Step 4: Act on Recommendations

For each recommendation:
- **Create rule**: Use compound-learnings skill
- **Create skill**: Use skill-developer skill
- **Update existing**: Edit the artifact directly
- **Dismiss**: Mark as not applicable

### Step 5: Save Report

```bash
# Report saved to
$CLAUDE_PROJECT_DIR/.claude/cache/meta/<batch-id>.json
$CLAUDE_PROJECT_DIR/.claude/cache/meta/<batch-id>.md  # Human-readable
```

## Integration with Compound Learnings

After meta-retrospect, run compound-learnings with prioritized input:

```bash
# Meta-retrospect outputs prioritized_patterns.json
# Compound-learnings can consume this instead of raw learnings
```
```

#### Tasks
- [ ] Create `.claude/skills/meta-retrospect/SKILL.md`
- [ ] Add triggers to `skill-rules.json`
- [ ] Create human-readable markdown output format
- [ ] Test integration with compound-learnings

#### Acceptance Criteria
- [ ] `/meta-retrospect` command works
- [ ] Produces both JSON and markdown output
- [ ] Recommendations are actionable (not vague)
- [ ] Handles <5 retrospections gracefully (warns, still runs)

**Complexity:** Medium (2-3 days)

---

### Story 2.3: Compound-Learnings Integration

**As a** system
**I want** compound-learnings to consume meta-retrospect output
**So that** pattern → artifact conversion is more targeted

#### Integration Design

Current compound-learnings reads raw learnings files and builds frequency tables.

New flow:
1. If `prioritized_patterns.json` exists (from meta-retrospect), use it
2. Otherwise, fall back to existing behavior (read raw files)

```python
# In compound-learnings process
prioritized = Path(".claude/cache/meta/prioritized_patterns.json")
if prioritized.exists():
    patterns = load_prioritized_patterns(prioritized)
    # Patterns already have frequency, category, recommendation
else:
    patterns = extract_from_raw_learnings()
    # Existing behavior
```

#### Tasks
- [ ] Add `prioritized_patterns.json` output to meta-retrospect
- [ ] Modify compound-learnings skill to check for prioritized input
- [ ] Ensure backward compatibility (works without meta-retrospect)
- [ ] Document the integration in both skills

#### Acceptance Criteria
- [ ] Compound-learnings prefers prioritized input when available
- [ ] Falls back gracefully to raw learnings
- [ ] Prioritized patterns include recommendation type (rule/skill/hook)
- [ ] No breaking changes to existing compound-learnings usage

**Complexity:** Low (1-2 days)

---

## Epic 3: Human Layer (P2)

### Story 3.1: Intent Configuration

**As a** human operator
**I want** to define my intent in a configuration file
**So that** the system knows what success looks like and can detect drift

#### File Design

```yaml
# .claude/intent.yaml

# What success looks like for this project
goals:
  - "Produce correct, well-tested code"
  - "Maintain clear documentation"
  - "Minimize debugging cycles"

# What we're explicitly NOT optimizing for
anti_goals:
  - "Token efficiency at cost of correctness"
  - "Speed at cost of quality"
  - "Complexity for its own sake"

# Observable signals of success
success_signals:
  - "Tests pass on first CI run"
  - "PRs approved without major revisions"
  - "No production incidents from changes"

# Observable signals of failure
failure_signals:
  - "Same bug fixed multiple times"
  - "Rework requested after review"
  - "Tests added after bug found"

# Keywords that indicate alignment (for pattern matching)
alignment_keywords:
  - "test first"
  - "verified"
  - "validated"
  - "documented"

# Keywords that indicate drift (for pattern matching)
drift_keywords:
  - "skipped tests"
  - "workaround"
  - "technical debt"
  - "will fix later"
```

#### Tasks
- [ ] Create `.claude/intent.yaml` template
- [ ] Add intent loading to retrospect skill
- [ ] Add intent loading to meta-retrospect script
- [ ] Document intent file format

#### Acceptance Criteria
- [ ] Intent file is human-editable YAML
- [ ] Missing intent file doesn't break retrospection (graceful)
- [ ] Intent loaded and referenced in retrospection output
- [ ] Keywords used for drift detection

**Complexity:** Low (1 day)

---

### Story 3.2: Policy Thresholds

**As a** human operator
**I want** to configure alerting thresholds
**So that** I'm notified only when metrics exceed acceptable levels

#### Policy Section (in intent.yaml)

```yaml
# .claude/intent.yaml (continued)

policy:
  # When to alert human
  thresholds:
    drift_score: 0.3           # Alert if drift exceeds this
    recurring_issue_count: 3   # Alert if same issue appears N+ times
    failed_session_streak: 2   # Alert after N consecutive failures
    application_rate_min: 0.5  # Alert if rate drops below

  # Meta-retrospection schedule
  meta_retrospect:
    trigger: "manual"          # "manual" | "every_n_sessions" | "weekly"
    batch_size: 10
    every_n_sessions: 10       # If trigger is "every_n_sessions"

  # What to do with recommendations
  recommendations:
    auto_create: false         # Never auto-create artifacts
    require_approval: true     # Always ask before creating
```

#### Tasks
- [ ] Add policy section to intent schema
- [ ] Implement threshold checking in meta-retrospect
- [ ] Create alert output format (what triggered, current value, threshold)
- [ ] Add policy validation on load

#### Acceptance Criteria
- [ ] Invalid policy produces clear error message
- [ ] Threshold breaches clearly indicated in output
- [ ] Default thresholds used if policy section missing
- [ ] Alerts are actionable (include what to do)

**Complexity:** Low (1-2 days)

---

### Story 3.3: Drift Detection

**As a** meta-retrospector
**I want** to measure how far learnings have drifted from intent
**So that** I can alert when the system optimizes for wrong goals

#### Drift Scoring Algorithm

```python
def calculate_drift_score(
    retrospections: list[Retrospection],
    intent: Intent
) -> DriftAnalysis:
    """
    Measure alignment between recent learnings and stated intent.

    Method:
    1. Extract all patterns from retrospections
    2. Count alignment_keywords vs drift_keywords in patterns
    3. Check if patterns address goals vs anti_goals
    4. Compute drift score: 0.0 (aligned) to 1.0 (drifted)

    Returns:
        - drift_score: float
        - alignment_evidence: list[str]  # Patterns aligned with goals
        - drift_evidence: list[str]      # Patterns drifting toward anti-goals
        - trend: "improving" | "stable" | "worsening"
    """
```

**Scoring breakdown:**
- 0.0-0.2: Well aligned
- 0.2-0.4: Minor drift (acceptable)
- 0.4-0.6: Moderate drift (review recommended)
- 0.6-0.8: Significant drift (action needed)
- 0.8-1.0: Severe drift (urgent attention)

#### Tasks
- [ ] Implement keyword-based drift detection
- [ ] Add drift analysis to meta-retrospect output
- [ ] Create drift trend tracking (compare across batches)
- [ ] Add drift visualization to markdown report

#### Acceptance Criteria
- [ ] Drift score is 0.0-1.0 range
- [ ] Score explainable (shows evidence)
- [ ] Handles missing intent file (skip drift analysis)
- [ ] Drift trend tracked across meta-retrospections

#### Design Decision: Why Not Embeddings?

Embedding-based semantic similarity was considered but rejected:
- Adds dependency (sentence-transformers)
- Keyword matching is interpretable
- Can add embeddings later if keyword approach insufficient

**Complexity:** Medium (2-3 days)

---

## Epic 4: Automation & Observability (P3)

### Story 4.1: Automatic Meta-Retrospection Trigger

**As a** system
**I want** meta-retrospection to run automatically
**So that** trends are detected without manual intervention

#### Trigger Mechanism

Add session counter to retrospection storage:

```python
# In retrospection_store.py

def increment_session_counter() -> int:
    counter_file = Path(".claude/cache/session_counter.txt")
    count = int(counter_file.read_text()) if counter_file.exists() else 0
    count += 1
    counter_file.write_text(str(count))
    return count

def should_trigger_meta(policy: Policy) -> bool:
    if policy.meta_retrospect.trigger != "every_n_sessions":
        return False
    count = get_session_counter()
    return count % policy.meta_retrospect.every_n_sessions == 0
```

Integrate with SessionEnd hook:

```typescript
// In session-end hook
// After retrospection completes, check trigger
if (shouldTriggerMeta()) {
    spawnDetached('meta_retrospect.py', ['--batch', config.batchSize]);
}
```

#### Tasks
- [ ] Add session counter to retrospection store
- [ ] Add trigger check to SessionEnd hook
- [ ] Implement quiet mode (no output if all thresholds OK)
- [ ] Add enable/disable flag in policy

#### Acceptance Criteria
- [ ] Counter persists across sessions
- [ ] Meta-retrospect runs after configured N sessions
- [ ] Can be disabled via policy
- [ ] Non-blocking (doesn't delay session end)

**Complexity:** Medium (2-3 days)

---

### Story 4.2: Dashboard Report

**As a** human operator
**I want** a readable summary of learning health
**So that** I can quickly understand system status

#### Report Format

```markdown
# Learning Health Dashboard
Generated: 2024-01-15 14:30:00

## Summary
- **Sessions analyzed:** 10
- **Date range:** 2024-01-05 to 2024-01-15
- **Overall health:** Good (no alerts)

## Outcomes
| Outcome | Count | Percentage |
|---------|-------|------------|
| Succeeded | 6 | 60% |
| Partial+ | 2 | 20% |
| Partial- | 1 | 10% |
| Failed | 1 | 10% |

**Trend:** Improving (up from 50% success last batch)

## Learning Metrics
- **Application rate:** 65% (target: >50%)
- **Recurring issues:** 2 (threshold: <3)
- **Drift score:** 0.15 (threshold: <0.3)

## Top Recurring Issues
1. **"Forgot to run tests before commit"** (3 sessions)
   - Recommendation: Create pre-commit hook
2. **"Wrong file path assumptions"** (2 sessions)
   - Recommendation: Add path validation rule

## Most Effective Rules
1. `explicit-identity.md` - 80% success when active (vs 55% baseline)
2. `observe-before-editing.md` - 75% success when active

## Alerts
None - all thresholds OK

## Recommended Actions
- [ ] Create pre-commit hook for test running
- [ ] Review "wrong file path" pattern for rule creation
```

#### Tasks
- [ ] Create `scripts/learning_dashboard.py`
- [ ] Implement markdown report generation
- [ ] Add ASCII charts for trends (optional)
- [ ] Create dashboard skill for easy access

#### Acceptance Criteria
- [ ] Report is <100 lines (scannable in 2 minutes)
- [ ] Includes all key metrics
- [ ] Highlights actionable items
- [ ] Works with partial data (some metrics may be unavailable)

**Complexity:** Medium (2-3 days)

---

### Story 4.3: Decision Trace

**As a** human operator
**I want** to trace any artifact back to its origin
**So that** I can understand why rules/skills exist

#### Trace Query

```bash
# Trace a rule back to its origin
uv run python scripts/trace_decision.py --artifact .claude/rules/explicit-identity.md

# Output:
# Artifact: explicit-identity.md
# Created: 2024-01-10
#
# Origin Chain:
# 1. Retrospection session-abc (2024-01-05)
#    Pattern: "IDs lost across agent boundaries"
#    Outcome: FAILED
#
# 2. Retrospection session-def (2024-01-07)
#    Pattern: "Explicit ID passing succeeded"
#    Outcome: SUCCEEDED
#
# 3. Meta-retrospection batch-001 (2024-01-08)
#    Recurring issue detected (2 sessions)
#    Recommendation: Create rule
#
# 4. Compound-learnings (2024-01-10)
#    Pattern approved by user
#    Rule created
```

#### Tasks
- [ ] Add `created_from` metadata to rules/skills
- [ ] Create `scripts/trace_decision.py`
- [ ] Link retrospections → meta-batch → artifacts
- [ ] Store creation provenance in artifact index

#### Acceptance Criteria
- [ ] Can trace any artifact to source retrospections
- [ ] Shows full chain (retrospection → meta → artifact)
- [ ] Handles artifacts created before system (shows "legacy")
- [ ] Useful for debugging unexpected rules

**Complexity:** Medium (2-3 days)

---

## Dependency Graph

```
Story 1.1 (Schema)
    ↓
Story 1.2 (Storage) ──→ Story 2.1 (Meta-Script)
    ↓                        ↓
Story 1.3 (Skill) ────→ Story 2.2 (Meta-Skill)
    ↓                        ↓
Story 1.4 (Outcomes) ──→ Story 2.3 (Integration)
                             ↓
Story 3.1 (Intent) ────→ Story 3.3 (Drift)
    ↓                        ↓
Story 3.2 (Policy) ────→ Story 4.1 (Auto-Trigger)
                             ↓
                        Story 4.2 (Dashboard)
                             ↓
                        Story 4.3 (Trace)
```

## Priority Summary

| Priority | Epic | Stories | Rationale |
|----------|------|---------|-----------|
| **P0** | Structured Retrospection | 1.1, 1.2, 1.3, 1.4 | Foundation - enables all downstream |
| **P1** | Meta-Retrospection | 2.1, 2.2, 2.3 | Core value - batch analysis |
| **P2** | Human Layer | 3.1, 3.2, 3.3 | Alignment - drift detection |
| **P3** | Automation | 4.1, 4.2, 4.3 | Polish - observability |

## Estimated Timeline

| Phase | Stories | Complexity | Estimate |
|-------|---------|------------|----------|
| P0 | 1.1-1.4 | Low-Medium | 6-9 days |
| P1 | 2.1-2.3 | Medium-High | 8-12 days |
| P2 | 3.1-3.3 | Low-Medium | 4-6 days |
| P3 | 4.1-4.3 | Medium | 7-9 days |

**Total:** 25-36 days (5-7 weeks)

## Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Recurring issue rate | ~40% | <20% | % of patterns appearing 3+ times |
| Learning application rate | Unknown | >60% | % of actionable patterns → artifacts |
| Drift score | Unmeasured | <0.3 | Keyword-based alignment score |
| Human execution-fix time | High | <20% | Self-reported time allocation |

## Out of Scope

1. **External services** - No Braintrust, no paid APIs
2. **Cross-project learning** - Single project only
3. **Real-time analysis** - Batch only, not per-turn
4. **Embedding models** - Keyword-based drift (may add later)
5. **Auto-creation of artifacts** - Always requires human approval

## Open Questions

1. **Retrospection timing:** Should retrospection be required before session end, or optional?
   - Recommendation: Optional but strongly encouraged (hook prompts but doesn't block)

2. **Minimum batch size:** What's the minimum for meaningful meta-analysis?
   - Recommendation: 5 retrospections, warn below this

3. **Pattern deduplication:** How to handle near-duplicate patterns across sessions?
   - Recommendation: Fuzzy matching with configurable threshold

4. **Legacy migration:** Import existing `.claude/cache/learnings/*.md` files?
   - Recommendation: Yes, with best-effort parsing into new schema

# Feature Request: Hierarchical Meta-Retrospection System

## Summary

Extend Continuous Claude with a **three-layer learning architecture** where humans operate at the highest abstraction level (intent/policy), and two automated layers handle retrospection and meta-retrospection to create a compounding improvement flywheel.

## Motivation

### The Calculus Analogy

| Physics | System Layer | Measures |
|---------|--------------|----------|
| Position | Worker | Current output (where we are) |
| Velocity (dx/dt) | Retrospector | Rate of improvement |
| Acceleration (d²x/dt²) | Meta-Retrospector | Is improvement speeding up or slowing down? |

Each derivative provides insight the layer below cannot see:
- Worker can't see patterns across sessions
- Retrospector can't see trends in its own effectiveness
- Meta-Retrospector detects drift, fatigue, and stale patterns

### Human Leverage

Humans should invest time at the highest-leverage point:
- **Current state**: Humans fix individual worker outputs (low leverage)
- **Target state**: Humans tune meta-retrospector policies (high leverage)

Small adjustments at meta-layer cascade through retrospection → worker with amplified effect.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  HUMAN LAYER                                                │
│  ─────────────────────────────────────────────────────────  │
│  Input: Intent / Job-to-be-Done ("I want reliable auth")   │
│  Action: Tune meta-retrospector policies                    │
│  Frequency: Periodic review (weekly/monthly)                │
│  Output: Policy adjustments, goal refinements               │
└─────────────────────────────────────────────────────────────┘
                           ↓ policies
┌─────────────────────────────────────────────────────────────┐
│  META-RETROSPECTOR LAYER                                    │
│  ─────────────────────────────────────────────────────────  │
│  Input: Batch of retrospection outputs (5-10 sessions)      │
│  Questions:                                                 │
│    - Are learnings improving in quality?                    │
│    - Are the same issues being flagged repeatedly?          │
│    - Is retrospection drifting from human intent?           │
│    - Are learnings actually being applied?                  │
│  Output: Adjustments to retrospector prompts/focus          │
│  Frequency: Every N sessions (batch operation)              │
└─────────────────────────────────────────────────────────────┘
                           ↓ improves
┌─────────────────────────────────────────────────────────────┐
│  RETROSPECTOR LAYER                                         │
│  ─────────────────────────────────────────────────────────  │
│  Input: Single session worker output                        │
│  Questions:                                                 │
│    - What worked well?                                      │
│    - What failed and why?                                   │
│    - What should be done differently next time?             │
│  Output: Learnings written to .claude/rules/ or CLAUDE.md   │
│  Frequency: End of each session                             │
└─────────────────────────────────────────────────────────────┘
                           ↓ guides
┌─────────────────────────────────────────────────────────────┐
│  WORKER LAYER                                               │
│  ─────────────────────────────────────────────────────────  │
│  Input: Task + learnings from retrospector                  │
│  Action: Execute development tasks                          │
│  Output: Artifacts, code, outcomes                          │
│  Frequency: Continuous                                      │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Enhance Retrospector Layer

**Current state:** `braintrust_analyze.py --learn` extracts learnings, SessionEnd hooks trigger cleanup.

**Required changes:**

1. **Create `/retrospect` skill** (`.claude/skills/retrospect/`)
   ```
   SKILL.md - Trigger end-of-session retrospection
   ```
   - Analyzes session via Braintrust traces
   - Compares intent vs. outcome
   - Writes structured learnings to `.claude/cache/retrospections/<session>.json`

2. **Structured retrospection output format:**
   ```json
   {
     "session_id": "abc-123",
     "timestamp": "2025-01-15T10:30:00Z",
     "intent": "Implement user authentication",
     "outcome": "partial",
     "learnings": [
       {
         "category": "architecture",
         "insight": "JWT refresh tokens needed for long sessions",
         "confidence": 0.8,
         "applied": false
       }
     ],
     "failures": [
       {
         "description": "Forgot to handle token expiry",
         "root_cause": "No explicit requirement",
         "prevention": "Add token lifecycle to auth checklist"
       }
     ],
     "time_spent_minutes": 45
   }
   ```

3. **Add retrospection tracking table:**
   - Store in SQLite alongside artifact index
   - Enable querying across sessions

### Phase 2: Build Meta-Retrospector Layer

1. **Create `/meta-retrospect` skill** (`.claude/skills/meta-retrospect/`)
   - Runs on batch of 5-10 retrospection outputs
   - Detects patterns across sessions

2. **Meta-retrospection analysis:**
   ```python
   # scripts/meta_retrospect.py

   def analyze_retrospection_batch(retrospections: list[Retrospection]) -> MetaAnalysis:
       """
       Analyze batch of retrospections to detect trends.

       Returns:
         - learning_quality_trend: improving | stable | degrading
         - recurring_issues: issues flagged 3+ times without resolution
         - drift_score: how far learnings have drifted from stated intent
         - application_rate: % of learnings actually applied in subsequent sessions
         - recommendations: adjustments to retrospector prompts
       """
   ```

3. **Meta-retrospector outputs:**
   - Adjustments to retrospection prompts (stored in `.claude/meta/retrospector-config.json`)
   - Alerts for human review when drift detected
   - Recommendations for rule updates

4. **Trigger mechanism:**
   - Hook: After every 5th session, trigger meta-retrospection
   - Or: Manual via `/meta-retrospect` command

### Phase 3: Human Policy Layer

1. **Create policy configuration file:**
   ```yaml
   # .claude/meta/human-policy.yaml

   intent:
     primary_goals:
       - "Produce reliable, maintainable code"
       - "Minimize production bugs"
       - "Learn transferable patterns"

     constraints:
       - "Prefer simplicity over cleverness"
       - "Test before commit"

   thresholds:
     alert_on_drift_score: 0.3
     alert_on_recurring_issues: 3
     min_learning_application_rate: 0.6

   review_frequency: "weekly"
   ```

2. **Human dashboard/report:**
   - Summary of meta-retrospection findings
   - Trends over time (improving/degrading)
   - Suggested policy adjustments
   - One-click approval for rule updates

3. **Feedback loop:**
   - Human approves/rejects meta-retrospector recommendations
   - Approval/rejection feeds back into meta-retrospector training

### Phase 4: Observability & Safeguards

1. **Sampling mechanism:**
   - Random spot-check of worker outputs by human
   - Configurable sampling rate (e.g., 5% of sessions)

2. **Intent-level metrics:**
   - Track actual production bugs (not proxy metrics)
   - Track time-to-completion trends
   - Track learning application success rate

3. **Escape hatches:**
   - Worker can escalate uncertainty to human
   - Meta-retrospector can request human review
   - Kill switch to disable automated learning

4. **Audit trail:**
   - Every layer logs reasoning
   - Human can trace any decision back through layers

## File Structure

```
.claude/
├── skills/
│   ├── retrospect/
│   │   └── SKILL.md           # End-of-session retrospection
│   └── meta-retrospect/
│       └── SKILL.md           # Batch meta-analysis
├── meta/
│   ├── human-policy.yaml      # Human intent & thresholds
│   ├── retrospector-config.json  # Meta-tuned retrospector settings
│   └── metrics/
│       └── dashboard.json     # Aggregated metrics for human review
├── cache/
│   ├── retrospections/
│   │   └── <session>.json     # Individual retrospection outputs
│   └── meta-retrospections/
│       └── <batch>.json       # Batch analysis outputs

scripts/
├── retrospect.py              # Retrospection logic
├── meta_retrospect.py         # Meta-retrospection logic
└── human_dashboard.py         # Generate human-readable reports

src/
└── meta/
    ├── retrospection_schema.py   # Pydantic models
    ├── trend_detection.py        # Statistical trend analysis
    └── drift_detection.py        # Intent vs. learning drift
```

## Risks & Mitigations

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Alignment drift** | Meta-layer optimizes for proxy metrics | Intent-level metrics, human sampling |
| **Noise amplification** | Each derivative is noisier | Batch operations, statistical smoothing |
| **Complexity overhead** | Three layers add cognitive load | Clear separation, good observability |
| **Stale policies** | Human policies become outdated | Periodic review reminders |
| **Over-automation** | Humans disengage entirely | Required human approval for major changes |

## Success Criteria

1. **Quantitative:**
   - 50% reduction in recurring issues (same issue flagged ≤2 times)
   - 70%+ learning application rate
   - Drift score stays below 0.3

2. **Qualitative:**
   - Humans spend <10% of time on execution-level fixes
   - Humans spend >50% of time on intent/policy refinement
   - Learnings become more actionable over time

## Dependencies

- Existing: Braintrust tracing, artifact index, SessionEnd hooks
- New: Statistical trend analysis, structured retrospection format

## Open Questions

1. How many sessions should a meta-retrospection batch contain? (Proposed: 5-10)
2. Should meta-retrospector run automatically or require human trigger?
3. How to handle contradictory learnings across sessions?
4. Should learnings have expiration dates?

---

# Epic Breakdown: User Stories

## Story 1: Structured Retrospection Output

**As a** system operator
**I want** retrospection to produce structured JSON output
**So that** downstream analysis can process learnings programmatically

### Tasks
- [ ] Create Pydantic schema for retrospection output (`src/meta/retrospection_schema.py`)
- [ ] Update `scripts/braintrust_analyze.py` to output structured JSON
- [ ] Create storage directory `.claude/cache/retrospections/`
- [ ] Add SQLite table for retrospection index

### Definition of Done
- [ ] Retrospection outputs valid JSON matching schema
- [ ] JSON includes: session_id, timestamp, intent, outcome, learnings[], failures[]
- [ ] Retrospections are queryable via SQLite
- [ ] Unit tests pass for schema validation
- [ ] Integration test: run retrospection on sample session, verify output

### Estimated Complexity: Medium (2-3 days)

---

## Story 2: Retrospect Skill

**As a** Claude Code user
**I want** a `/retrospect` command
**So that** I can trigger end-of-session analysis manually

### Tasks
- [ ] Create `.claude/skills/retrospect/SKILL.md`
- [ ] Create `scripts/retrospect.py` with CLI interface
- [ ] Integrate with Braintrust trace fetching
- [ ] Add intent extraction from session start

### Definition of Done
- [ ] `/retrospect` command is discoverable in Claude Code
- [ ] Command produces structured JSON in `.claude/cache/retrospections/`
- [ ] Works with and without Braintrust (graceful degradation)
- [ ] Skill description accurately triggers on "analyze session" type queries

### Estimated Complexity: Medium (2-3 days)

---

## Story 3: Meta-Retrospection Script

**As a** system
**I want** to analyze batches of retrospections
**So that** I can detect trends in learning effectiveness

### Tasks
- [ ] Create `scripts/meta_retrospect.py`
- [ ] Implement trend detection (improving/stable/degrading)
- [ ] Implement recurring issue detection
- [ ] Implement learning application rate calculation
- [ ] Output recommendations as structured JSON

### Definition of Done
- [ ] Script accepts `--batch-size N` parameter
- [ ] Correctly identifies issues flagged 3+ times
- [ ] Calculates learning application rate from subsequent sessions
- [ ] Outputs to `.claude/cache/meta-retrospections/<batch>.json`
- [ ] Unit tests for each detection algorithm

### Estimated Complexity: High (4-5 days)

---

## Story 4: Meta-Retrospect Skill

**As a** Claude Code user
**I want** a `/meta-retrospect` command
**So that** I can trigger batch analysis of past retrospections

### Tasks
- [ ] Create `.claude/skills/meta-retrospect/SKILL.md`
- [ ] Wire skill to `scripts/meta_retrospect.py`
- [ ] Add human-readable summary output
- [ ] Generate recommendations for retrospector prompt adjustments

### Definition of Done
- [ ] `/meta-retrospect` command works
- [ ] Produces both JSON and human-readable summary
- [ ] Recommendations are actionable (specific prompt changes)
- [ ] Works on minimum of 5 retrospections

### Estimated Complexity: Medium (2-3 days)

---

## Story 5: Human Policy Configuration

**As a** human operator
**I want** to define my intent and thresholds in a config file
**So that** the system knows when to alert me

### Tasks
- [ ] Create `.claude/meta/human-policy.yaml` schema
- [ ] Add policy loading to meta-retrospector
- [ ] Implement threshold-based alerting
- [ ] Create policy validation on load

### Definition of Done
- [ ] Policy file is human-editable YAML
- [ ] System alerts when drift_score exceeds threshold
- [ ] System alerts when recurring_issues exceeds threshold
- [ ] Invalid policy produces clear error message

### Estimated Complexity: Low (1-2 days)

---

## Story 6: Drift Detection Algorithm

**As a** meta-retrospector
**I want** to measure how far learnings have drifted from stated intent
**So that** I can alert humans when the system is optimizing for wrong goals

### Tasks
- [ ] Define drift scoring algorithm
- [ ] Implement semantic similarity between learnings and intent
- [ ] Add drift score to meta-retrospection output
- [ ] Create visualization of drift over time

### Definition of Done
- [ ] Drift score is 0.0-1.0 (0 = aligned, 1 = completely drifted)
- [ ] Algorithm uses embedding similarity or keyword overlap
- [ ] Drift score correlates with human judgment (manual validation on 10 samples)
- [ ] Historical drift scores stored for trend analysis

### Estimated Complexity: High (4-5 days)

---

## Story 7: Automatic Meta-Retrospection Trigger

**As a** system
**I want** meta-retrospection to run automatically every N sessions
**So that** trends are detected without manual intervention

### Tasks
- [ ] Add session counter to retrospection storage
- [ ] Create hook or cron-like trigger for meta-retrospection
- [ ] Add configuration for trigger frequency
- [ ] Implement quiet mode (no alerts if all thresholds OK)

### Definition of Done
- [ ] Meta-retrospection runs automatically after configured N sessions
- [ ] Produces alerts only when thresholds exceeded
- [ ] Can be disabled via policy config
- [ ] Logs execution in `.claude/cache/meta-retrospections/`

### Estimated Complexity: Medium (2-3 days)

---

## Story 8: Human Dashboard Report

**As a** human operator
**I want** a readable report of system health
**So that** I can quickly understand what needs attention

### Tasks
- [ ] Create `scripts/human_dashboard.py`
- [ ] Generate markdown report from meta-retrospection data
- [ ] Include trend charts (ASCII or linked images)
- [ ] Highlight actionable recommendations

### Definition of Done
- [ ] Report is generated as markdown file
- [ ] Includes: summary stats, trend direction, top issues, recommendations
- [ ] Can be generated on-demand via CLI
- [ ] Report is under 100 lines (scannable in 2 minutes)

### Estimated Complexity: Medium (2-3 days)

---

## Story 9: Observability & Audit Trail

**As a** human operator
**I want** to trace any decision back through all layers
**So that** I can debug unexpected behavior

### Tasks
- [ ] Add reasoning field to all layer outputs
- [ ] Create trace viewer script
- [ ] Link retrospections to meta-retrospections to policy
- [ ] Add timestamps and version info to all outputs

### Definition of Done
- [ ] Given any learning, can trace back to: which session, which meta-batch, which policy
- [ ] `scripts/trace_decision.py --learning-id X` shows full chain
- [ ] All outputs include `_meta` field with timestamps

### Estimated Complexity: Medium (2-3 days)

---

# Testing Strategy

## Benchmark Selection

We will use publicly available benchmarks to test the Worker layer and measure improvement over time.

### Primary Benchmark: SWE-bench Lite

**Source:** [SWE-bench GitHub](https://github.com/SWE-bench/SWE-bench)
**Dataset:** [princeton-nlp/SWE-bench_Lite](https://huggingface.co/datasets/princeton-nlp/SWE-bench_Lite)

**Why:**
- 300 real GitHub issues from popular Python repos
- Industry standard for coding agents
- Clear pass/fail via test execution
- Downloadable and runnable locally

**Setup:**
```bash
pip install swebench
from datasets import load_dataset
swebench_lite = load_dataset('princeton-nlp/SWE-bench_Lite', split='test')
```

**Metrics:**
- % Resolved (primary)
- Time to resolution
- Number of attempts before success

### Secondary Benchmark: DABstep (Multi-step Reasoning)

**Source:** [DABstep on Hugging Face](https://huggingface.co/blog/dabstep)

**Why:**
- 450+ real-world multi-step tasks
- Cannot be solved in 1-shot (requires iterative problem-solving)
- Tests planning and execution loops
- Built from actual analyst workloads

**Metrics:**
- Task completion rate
- Steps required vs. optimal
- Learning transfer (does solving task N improve task N+1?)

### Tertiary Benchmark: AgentBench (General Agent Capabilities)

**Source:** [AgentBench GitHub](https://github.com/THUDM/AgentBench)

**Why:**
- Tests 8 different environment types
- Measures planning, reasoning, tool use
- Multi-turn, open-ended generation
- Published at ICLR'24

**Metrics:**
- Success rate per environment
- Generalization across domains

## Testing Protocol

### Phase 1: Baseline (Before Meta-Retrospection)

1. **Run SWE-bench Lite sample (50 issues)**
   - Record: % resolved, avg time, failure modes
   - Worker operates without retrospection learnings

2. **Record baseline metrics:**
   - Recurring issue rate: how often same failure mode appears
   - Learning application: N/A (no learnings yet)

### Phase 2: Retrospection Only

1. **Run 50 more SWE-bench issues with retrospection enabled**
   - After each session, run `/retrospect`
   - Learnings stored but meta-retrospection not yet active

2. **Measure:**
   - % resolved (compare to baseline)
   - Are learnings being applied? (manual audit)
   - Recurring issue rate

### Phase 3: Full System (Meta-Retrospection Active)

1. **Run 50 more SWE-bench issues**
   - Meta-retrospection runs after every 5 sessions
   - System adjusts retrospector prompts based on meta-analysis

2. **Measure:**
   - % resolved (compare to Phase 1 and 2)
   - Recurring issue rate (expect 50% reduction)
   - Learning application rate (expect 70%+)
   - Drift score (expect <0.3)

### Phase 4: Human Policy Tuning

1. **Human reviews dashboard, adjusts policy**
2. **Run 25 more issues**
3. **Measure improvement from policy tuning**

## Sample Tasks for Initial Development

Before running full benchmarks, use these representative tasks for development testing:

### Task Set A: Bug Fixes (SWE-bench style)
1. **Django ORM bug** - Incorrect query generation with nested filters
2. **Flask routing issue** - URL parameters not decoded correctly
3. **Pandas merge bug** - Memory leak on large dataframe joins

### Task Set B: Feature Implementation (DABstep style)
1. **Add pagination to REST API** - Multi-step: schema, endpoint, tests
2. **Implement retry logic with exponential backoff** - Requires understanding failure modes
3. **Add caching layer to database queries** - Architecture decision + implementation

### Task Set C: Refactoring
1. **Extract method from 200-line function** - Requires understanding intent
2. **Convert callbacks to async/await** - Pattern recognition
3. **Add type hints to module** - Systematic, measurable

## Success Metrics Summary

| Metric | Baseline Target | With Retrospection | With Meta-Retrospection |
|--------|-----------------|-------------------|------------------------|
| SWE-bench Lite % Resolved | 15-20% | 25-30% | 35-40% |
| Recurring Issue Rate | 40% | 25% | 15% |
| Learning Application Rate | N/A | 50% | 70% |
| Drift Score | N/A | N/A | <0.3 |
| Human Time on Execution | 80% | 50% | <20% |

## References

- [SWE-bench GitHub](https://github.com/SWE-bench/SWE-bench)
- [SWE-bench Leaderboard](https://www.swebench.com/)
- [DABstep Benchmark](https://huggingface.co/blog/dabstep)
- [AgentBench](https://github.com/THUDM/AgentBench)
- [LLM Benchmarks Overview](https://runloop.ai/blog/understanding-llm-code-benchmarks-from-humaneval-to-swe-bench)
- [Top Coding Agents 2025](https://benched.ai/guides/top-coding-agents-2025)

---

## Implementation Priority

| Priority | Story | Rationale |
|----------|-------|-----------|
| P0 | Story 1: Structured Retrospection Output | Foundation for all other stories |
| P0 | Story 2: Retrospect Skill | Enables data collection |
| P1 | Story 3: Meta-Retrospection Script | Core meta-layer logic |
| P1 | Story 4: Meta-Retrospect Skill | User-facing meta-layer |
| P2 | Story 5: Human Policy Configuration | Enables human layer |
| P2 | Story 6: Drift Detection | Key insight for meta-layer |
| P3 | Story 7: Automatic Trigger | Removes manual overhead |
| P3 | Story 8: Human Dashboard | Human usability |
| P3 | Story 9: Observability | Debugging capability |

---

# Experiment Design

## Overview

This experiment tests whether the hierarchical meta-retrospection system improves coding agent performance compared to baseline (no learning) and single-layer retrospection.

### Research Questions

1. **RQ1**: Does retrospection improve task success rate compared to no learning?
2. **RQ2**: Does meta-retrospection improve success rate beyond retrospection alone?
3. **RQ3**: Does the system reduce recurring failure modes over time?
4. **RQ4**: Does human policy tuning provide additional improvement?
5. **RQ5**: Do learnings transfer across different task types?

## Experimental Design

### Design Type: Within-Subjects Longitudinal Study

We use a **within-subjects** design where the same system progresses through conditions sequentially. This mirrors real-world usage where learnings accumulate over time.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXPERIMENT TIMELINE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Phase 0        Phase 1         Phase 2         Phase 3        Phase 4  │
│  (Warmup)       (Baseline)      (Retro)         (Meta)         (Human)  │
│                                                                          │
│  ──────────     ──────────      ──────────      ──────────     ──────── │
│  10 tasks       50 tasks        50 tasks        50 tasks       25 tasks │
│  (discard)      No learning     +Retrospect     +Meta-Retro    +Policy  │
│                                                                          │
│                 ↓               ↓               ↓              ↓        │
│                 Measure         Measure         Measure        Measure  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why Not Between-Subjects?

Between-subjects (parallel groups) would require:
- Multiple identical agent instances
- Ensuring no cross-contamination of learnings
- Much larger sample sizes for statistical power

Within-subjects is more practical and matches the "compound learning" hypothesis we're testing.

## Variables

### Independent Variables (Manipulated)

| Variable | Levels | Description |
|----------|--------|-------------|
| **Learning Condition** | 4 | None, Retrospection, Meta-Retrospection, Human-Tuned |
| **Task Type** | 3 | Bug fix, Feature, Refactor |
| **Task Difficulty** | 3 | Easy, Medium, Hard (per SWE-bench labels) |

### Dependent Variables (Measured)

| Variable | Type | Measurement |
|----------|------|-------------|
| **Success Rate** | Binary | Task passes all tests (0/1) |
| **Partial Success** | Ordinal | 0=fail, 1=partial, 2=full |
| **Time to Solution** | Continuous | Minutes from start to first passing attempt |
| **Attempts Required** | Count | Number of code submissions before success |
| **Recurring Issues** | Count | Same failure mode appearing across tasks |
| **Learning Application** | Binary | Was a prior learning used? (manual audit) |
| **Drift Score** | Continuous | 0.0-1.0 (meta-retrospector output) |

### Control Variables (Held Constant)

| Variable | Value | Rationale |
|----------|-------|-----------|
| Model | Claude Opus 4.5 | Consistency |
| Temperature | 0.0 | Reproducibility |
| Max tokens | 16K | Prevent truncation |
| Timeout per task | 30 min | Practical limit |
| Repository state | Fresh clone per task | No contamination |

## Task Selection

### Source: SWE-bench Lite (Stratified Sample)

From 300 tasks, select 185 tasks stratified by:

```
Task Distribution:
├── Bug Fixes (100 tasks)
│   ├── Easy: 35
│   ├── Medium: 40
│   └── Hard: 25
├── Features (50 tasks)
│   ├── Easy: 15
│   ├── Medium: 20
│   └── Hard: 15
└── Refactors (35 tasks)
    ├── Easy: 10
    ├── Medium: 15
    └── Hard: 10
```

### Task Assignment to Phases

```python
# Randomized block assignment
import random

def assign_tasks(tasks, phases):
    """
    Assign tasks to phases ensuring balanced difficulty/type per phase.
    """
    # Group by (type, difficulty)
    groups = defaultdict(list)
    for task in tasks:
        groups[(task.type, task.difficulty)].append(task)

    # Shuffle within groups
    for group in groups.values():
        random.shuffle(group)

    # Distribute evenly across phases
    phase_tasks = {p: [] for p in phases}
    for group_tasks in groups.values():
        for i, task in enumerate(group_tasks):
            phase = phases[i % len(phases)]
            phase_tasks[phase].append(task)

    return phase_tasks
```

### Task Ordering Within Phases

**Within each phase**, tasks are ordered to test learning transfer:

```
Phase N task order:
├── Block 1: 5 bug fixes (similar domain)
├── Block 2: 5 features (similar domain)
├── Block 3: 5 mixed tasks
├── Block 4: 5 bug fixes (different domain)
├── Block 5: 5 features (different domain)
└── ... (repeat pattern)
```

This tests both **within-domain transfer** (learning from bug fix → applying to similar bug fix) and **cross-domain transfer** (learning from Django → applying to Flask).

## Procedure

### Phase 0: Warmup (Discarded)

**Purpose**: Establish baseline agent behavior, catch setup issues.

```
Tasks: 10 random tasks (not counted in analysis)
Learning: Disabled
Output: Verify infrastructure works
```

### Phase 1: Baseline (No Learning)

**Purpose**: Measure unassisted agent performance.

```
Tasks: 50 tasks (stratified sample)
Learning: Disabled (no retrospection)
Data collected:
  - Success rate per task
  - Time to solution
  - Failure mode categorization (manual)
  - Attempts per task
```

**Procedure per task:**
1. Clone fresh repository
2. Present issue description to agent
3. Agent attempts solution (max 30 min, max 5 attempts)
4. Run test suite
5. Record outcome
6. **No retrospection performed**

### Phase 2: Retrospection Only

**Purpose**: Measure impact of single-session learning.

```
Tasks: 50 tasks (stratified sample)
Learning: Retrospection enabled, meta-retrospection disabled
Data collected:
  - All baseline metrics
  - Retrospection outputs (JSON)
  - Learning application audit (did prior learning help?)
```

**Procedure per task:**
1. Load learnings from prior retrospections into context
2. Present issue description
3. Agent attempts solution
4. Run test suite
5. Record outcome
6. **Run retrospection** → store structured output
7. Annotator reviews: "Was a prior learning applied? Which one?"

### Phase 3: Meta-Retrospection Active

**Purpose**: Measure impact of trend detection and retrospector tuning.

```
Tasks: 50 tasks (stratified sample)
Learning: Full system (retrospection + meta-retrospection)
Meta-retro frequency: Every 5 tasks
Data collected:
  - All prior metrics
  - Meta-retrospection outputs
  - Retrospector prompt adjustments made
  - Drift scores
```

**Procedure:**
1. Tasks 1-5: Normal retrospection
2. After task 5: Run meta-retrospection
   - Analyze learnings 1-5
   - Identify recurring issues
   - Adjust retrospector prompts if needed
3. Tasks 6-10: Retrospection with adjusted prompts
4. After task 10: Run meta-retrospection
5. ... continue pattern

**Key measurement**: Do recurring issues decrease after meta-retrospection runs?

### Phase 4: Human Policy Tuning

**Purpose**: Measure marginal value of human-in-the-loop.

```
Tasks: 25 tasks (stratified sample)
Learning: Full system + human policy review
Human intervention: After task 10, review dashboard and adjust policy
Data collected:
  - All prior metrics
  - Human time spent reviewing
  - Policy changes made
  - Performance before/after intervention
```

**Procedure:**
1. Tasks 1-10: Run with existing policies
2. Human reviews dashboard:
   - Time recorded
   - Changes documented
3. Tasks 11-25: Run with updated policies
4. Compare pre/post intervention

## Analysis Plan

### Primary Analysis: Success Rate by Condition

**Hypothesis**: Success rate increases with each learning layer.

```
H0: μ_baseline = μ_retro = μ_meta = μ_human
H1: μ_baseline < μ_retro < μ_meta < μ_human
```

**Statistical test**: Cochran's Q test (repeated measures on binary outcome), followed by pairwise McNemar tests with Bonferroni correction.

**Required sample size**: With α=0.05, power=0.80, expected effect size (Cohen's h=0.3), n≈44 per condition. We use n=50 for safety margin.

### Secondary Analyses

#### 1. Recurring Issue Reduction

**Metric**: Count of failure modes appearing 3+ times within a phase.

```python
def recurring_issue_rate(phase_failures):
    """
    Calculate % of failures that are recurring.
    """
    mode_counts = Counter(f.failure_mode for f in phase_failures)
    recurring = sum(1 for f in phase_failures if mode_counts[f.failure_mode] >= 3)
    return recurring / len(phase_failures) if phase_failures else 0
```

**Expected**:
- Phase 1: ~40% recurring
- Phase 2: ~25% recurring
- Phase 3: ~15% recurring

**Test**: Chi-square test for trend across phases.

#### 2. Learning Transfer Analysis

**Within-domain transfer**: Compare success rate on task N+1 when task N was same type/domain.

**Cross-domain transfer**: Compare success rate on task N+1 when task N was different type/domain.

```python
def transfer_analysis(tasks_with_outcomes):
    """
    Analyze whether prior learnings transfer.
    """
    within_domain = []
    cross_domain = []

    for i in range(1, len(tasks)):
        current = tasks[i]
        prior = tasks[i-1]

        if current.domain == prior.domain:
            within_domain.append(current.success)
        else:
            cross_domain.append(current.success)

    return {
        'within_domain_rate': mean(within_domain),
        'cross_domain_rate': mean(cross_domain),
    }
```

#### 3. Time-to-Solution Trend

**Hypothesis**: Time decreases as learnings accumulate.

**Analysis**: Linear regression of time vs. task number within each phase, controlling for difficulty.

```python
# Model: time ~ task_number + difficulty + (1|task_type)
import statsmodels.formula.api as smf

model = smf.mixedlm(
    "time ~ task_number + difficulty",
    data=phase_data,
    groups=phase_data["task_type"]
)
```

#### 4. Drift Detection Validation

**Metric**: Correlation between drift score and human judgment.

**Procedure**:
1. Meta-retrospector outputs drift scores
2. Human annotator rates each learning batch: "How aligned with original intent?" (1-5)
3. Compute Spearman correlation

**Threshold**: r > 0.6 indicates drift score is meaningful.

### Failure Mode Taxonomy

For consistent categorization, use this taxonomy:

```yaml
failure_modes:
  understanding:
    - misread_requirements: "Solved wrong problem"
    - missed_edge_case: "Didn't handle boundary condition"
    - wrong_scope: "Changed too much or too little"

  implementation:
    - syntax_error: "Code doesn't parse"
    - type_error: "Type mismatch"
    - logic_error: "Code runs but wrong output"
    - import_error: "Missing or wrong imports"

  environment:
    - test_flakiness: "Test passes/fails intermittently"
    - setup_failure: "Couldn't configure environment"
    - timeout: "Exceeded time limit"

  process:
    - premature_commit: "Submitted before testing"
    - incomplete_fix: "Partial solution"
    - regression: "Fixed one thing, broke another"
```

## Data Collection Infrastructure

### Logging Schema

```python
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class TaskAttempt(BaseModel):
    task_id: str
    phase: int  # 1-4
    condition: str  # baseline|retro|meta|human

    # Timing
    started_at: datetime
    completed_at: datetime

    # Outcome
    success: bool
    partial_success: int  # 0, 1, 2
    attempts: int

    # Failure analysis (if failed)
    failure_mode: Optional[str]
    failure_details: Optional[str]

    # Learning data (phases 2+)
    learnings_loaded: list[str]  # IDs of learnings in context
    learning_applied: Optional[str]  # ID of learning that helped

    # Meta data (phases 3+)
    meta_batch_id: Optional[str]
    drift_score: Optional[float]

    # Traces
    braintrust_trace_id: str
    session_id: str

class ExperimentRun(BaseModel):
    experiment_id: str
    started_at: datetime
    model: str
    temperature: float

    phases: dict[int, list[TaskAttempt]]

    # Aggregates (computed)
    success_rates: dict[int, float]
    recurring_issue_rates: dict[int, float]
```

### Storage

```
.claude/cache/experiments/
├── <experiment_id>/
│   ├── config.json           # Experiment parameters
│   ├── task_assignments.json # Which tasks in which phase
│   ├── attempts/
│   │   └── <task_id>.json    # Per-task attempt data
│   ├── retrospections/
│   │   └── <task_id>.json    # Retrospection outputs
│   ├── meta_retrospections/
│   │   └── batch_<n>.json    # Meta outputs
│   └── analysis/
│       ├── phase_1_summary.json
│       ├── phase_2_summary.json
│       └── final_report.md
```

## Execution Timeline

### Pre-Experiment (1 week)

| Day | Activity |
|-----|----------|
| 1-2 | Finalize task selection, verify SWE-bench setup |
| 3-4 | Build logging infrastructure, test on 5 tasks |
| 5 | Recruit human annotator for failure mode coding |
| 6 | Dry run: Phase 0 (warmup) |
| 7 | Review warmup results, fix any issues |

### Experiment Execution (2 weeks)

| Day | Phase | Tasks | Notes |
|-----|-------|-------|-------|
| 1-2 | Phase 1 | 50 | Baseline, no learning |
| 3-4 | Phase 2 | 50 | Retrospection enabled |
| 5 | Analysis checkpoint | - | Verify data quality, adjust if needed |
| 6-8 | Phase 3 | 50 | Meta-retrospection every 5 tasks |
| 9 | Human review | - | Dashboard review, policy tuning |
| 10 | Phase 4 | 25 | Human-tuned policies |

### Post-Experiment (1 week)

| Day | Activity |
|-----|----------|
| 1-2 | Human annotation of failure modes (100 failures) |
| 3-4 | Statistical analysis |
| 5 | Draft report |
| 6-7 | Review, revise, publish |

## Expected Results

### Optimistic Scenario

| Phase | Success Rate | Recurring Issues | Learning Application |
|-------|--------------|------------------|---------------------|
| 1 (Baseline) | 20% | 40% | N/A |
| 2 (Retro) | 35% | 25% | 50% |
| 3 (Meta) | 45% | 12% | 75% |
| 4 (Human) | 52% | 8% | 85% |

### Conservative Scenario

| Phase | Success Rate | Recurring Issues | Learning Application |
|-------|--------------|------------------|---------------------|
| 1 (Baseline) | 18% | 42% | N/A |
| 2 (Retro) | 24% | 35% | 30% |
| 3 (Meta) | 30% | 25% | 50% |
| 4 (Human) | 33% | 20% | 60% |

### Null Scenario (System Doesn't Work)

| Phase | Success Rate | Recurring Issues | Learning Application |
|-------|--------------|------------------|---------------------|
| All | ~20% | ~40% | <20% or not applied |

If null scenario occurs, investigate:
1. Are learnings being loaded into context?
2. Are learnings actionable (specific enough)?
3. Is context window sufficient to hold learnings?
4. Is drift score detecting real drift?

## Threats to Validity

### Internal Validity

| Threat | Mitigation |
|--------|------------|
| **Order effects** | Randomize task order within phases |
| **Learning contamination** | Fresh repo clone per task |
| **Annotator bias** | Blind annotation (annotator doesn't know phase) |
| **Model drift** | Use fixed model version, temp=0 |

### External Validity

| Threat | Mitigation |
|--------|------------|
| **Task representativeness** | Use real GitHub issues (SWE-bench) |
| **Model specificity** | Document model version; repeat with other models in future |
| **Domain specificity** | Include multiple repos (Django, Flask, Pandas, etc.) |

### Construct Validity

| Threat | Mitigation |
|--------|------------|
| **Success metric validity** | Use test suite as ground truth (standard practice) |
| **Learning application measurement** | Human audit with inter-rater reliability check |
| **Drift score validity** | Validate against human judgment (correlation analysis) |

## Deliverables

1. **Raw data**: All task attempts, retrospections, meta-retrospections (anonymized)
2. **Analysis scripts**: Python notebooks reproducing all analyses
3. **Final report**:
   - Executive summary (1 page)
   - Detailed results by research question
   - Failure mode analysis
   - Recommendations for system improvement
4. **Learnings database**: All extracted learnings with effectiveness ratings

---

# Zero External Dependencies Variant

This section describes how to run the full experiment using only free, open-source components and the existing repository infrastructure.

## Dependency Analysis

| Component | Original | Zero-Cost Alternative |
|-----------|----------|----------------------|
| **Benchmarks** | SWE-bench Lite | ✅ Free (Hugging Face) |
| **Tracing** | Braintrust ($) | Local SQLite + JSON logs |
| **Annotations** | Human annotator ($) | Agent-as-judge (Claude Code self-evaluates) |
| **Judge LLM** | Separate API calls ($) | Agent-as-judge (same session) |
| **Embeddings** | OpenAI/external ($) | Local sentence-transformers |
| **Claude Code** | Required | ✅ Only cost (~$50-100 full, ~$15-30 minimal) |

**Key architecture decision**: Claude Code performs ALL roles (worker, retrospector, meta-retrospector). No separate LLM calls.

## Alternative Architecture

### 1. Local Tracing (Replace Braintrust)

Use the existing artifact index infrastructure with extended schema:

```python
# src/meta/local_tracing.py

import sqlite3
import json
from datetime import datetime
from pathlib import Path

class LocalTracer:
    """
    Zero-dependency tracing using SQLite.
    Replaces Braintrust for experiment logging.
    """

    def __init__(self, db_path: str = ".claude/cache/experiments/traces.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id TEXT PRIMARY KEY,
                    experiment_id TEXT,
                    phase INTEGER,
                    task_id TEXT,
                    started_at TEXT,
                    completed_at TEXT,
                    success INTEGER,
                    metadata TEXT
                );

                CREATE TABLE IF NOT EXISTS turns (
                    turn_id TEXT PRIMARY KEY,
                    session_id TEXT,
                    turn_number INTEGER,
                    role TEXT,
                    content TEXT,
                    timestamp TEXT,
                    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
                );

                CREATE TABLE IF NOT EXISTS tool_calls (
                    call_id TEXT PRIMARY KEY,
                    turn_id TEXT,
                    tool_name TEXT,
                    input TEXT,
                    output TEXT,
                    duration_ms INTEGER,
                    timestamp TEXT,
                    FOREIGN KEY (turn_id) REFERENCES turns(turn_id)
                );

                CREATE INDEX IF NOT EXISTS idx_sessions_experiment
                ON sessions(experiment_id);

                CREATE INDEX IF NOT EXISTS idx_sessions_phase
                ON sessions(phase);

                CREATE VIRTUAL TABLE IF NOT EXISTS turns_fts
                USING fts5(content, content=turns, content_rowid=rowid);
            """)

    def start_session(self, experiment_id: str, phase: int, task_id: str) -> str:
        session_id = f"{experiment_id}-{phase}-{task_id}-{datetime.now().isoformat()}"
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO sessions (session_id, experiment_id, phase, task_id, started_at)
                VALUES (?, ?, ?, ?, ?)
            """, (session_id, experiment_id, phase, task_id, datetime.now().isoformat()))
        return session_id

    def log_turn(self, session_id: str, turn_number: int, role: str, content: str):
        turn_id = f"{session_id}-turn-{turn_number}"
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO turns (turn_id, session_id, turn_number, role, content, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (turn_id, session_id, turn_number, role, content, datetime.now().isoformat()))
        return turn_id

    def end_session(self, session_id: str, success: bool, metadata: dict = None):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                UPDATE sessions
                SET completed_at = ?, success = ?, metadata = ?
                WHERE session_id = ?
            """, (datetime.now().isoformat(), int(success), json.dumps(metadata or {}), session_id))

    def get_phase_stats(self, experiment_id: str, phase: int) -> dict:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute("""
                SELECT
                    COUNT(*) as total,
                    SUM(success) as successes,
                    AVG(julianday(completed_at) - julianday(started_at)) * 24 * 60 as avg_minutes
                FROM sessions
                WHERE experiment_id = ? AND phase = ?
            """, (experiment_id, phase)).fetchone()
            return {
                'total': row[0],
                'successes': row[1] or 0,
                'success_rate': (row[1] or 0) / row[0] if row[0] else 0,
                'avg_minutes': row[2] or 0
            }
```

### 2. Agent-as-Judge (Claude Code Self-Evaluation)

**Key insight**: Claude Code itself performs retrospection and failure classification as part of its normal workflow. No separate LLM API calls needed.

```
┌─────────────────────────────────────────────────────────────────┐
│  SINGLE CLAUDE CODE SESSION                                      │
│                                                                   │
│  1. Worker phase:     Execute SWE-bench task                     │
│  2. Test phase:       Run tests, observe outcome                 │
│  3. Retrospect phase: Analyze own work, classify failure         │
│  4. Output phase:     Write structured JSON to cache             │
│                                                                   │
│  All in ONE session = ONE LLM cost                               │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation via `/retrospect` skill**:

The retrospection skill guides Claude Code to self-evaluate at end of task:

```markdown
# .claude/skills/retrospect/SKILL.md
---
description: Analyze current session, classify outcome, extract learnings
---

# Retrospect

After completing a task, analyze your own work.

## Process

1. **Review outcome**: Did tests pass? What was the result?

2. **Classify failure** (if failed):
   Choose ONE from:
   - understanding/misread_requirements
   - understanding/missed_edge_case
   - understanding/wrong_scope
   - implementation/syntax_error
   - implementation/type_error
   - implementation/logic_error
   - implementation/import_error
   - environment/test_flakiness
   - environment/setup_failure
   - environment/timeout
   - process/premature_commit
   - process/incomplete_fix
   - process/regression

3. **Check learning application**:
   Review learnings loaded at session start.
   Did you apply any? Which one helped?

4. **Extract new learnings**:
   What would help next time?
   Be specific and actionable.

5. **Write output**:
   Save to `.claude/cache/retrospections/<session>.json`

## Output Format

```json
{
  "session_id": "<from context>",
  "task_id": "<SWE-bench issue ID>",
  "timestamp": "<ISO format>",
  "outcome": "success | partial | failure",
  "failure_mode": "<category/type if failed>",
  "learnings_applied": ["<learning_id>", ...],
  "new_learnings": [
    {
      "id": "<generated UUID>",
      "category": "<understanding|implementation|process>",
      "insight": "<specific, actionable lesson>",
      "confidence": 0.8
    }
  ],
  "reasoning": "<brief explanation of what happened>"
}
```
```

**Why this works**:

1. **Same context**: Claude Code already has full context of the task it just completed
2. **No API overhead**: Retrospection is part of the same conversation, not a separate call
3. **Better accuracy**: Self-evaluation with full context beats external classification
4. **Natural workflow**: Fits the existing skill/hook pattern

**Experiment workflow**:

```
For each SWE-bench task:
  1. Load prior learnings into context (SessionStart hook)
  2. Present task: "Fix GitHub issue: <description>"
  3. Claude Code works on solution
  4. Run tests (Bash tool)
  5. Trigger: "/retrospect" or SessionEnd hook
  6. Claude Code self-evaluates and writes JSON
  7. LocalTracer records session metadata
```

**Cost comparison**:

| Approach | LLM Calls per Task | Relative Cost |
|----------|-------------------|---------------|
| Separate judge API | 2 (worker + judge) | 1.5-2x |
| Agent-as-judge (same session) | 1 (worker includes retrospection) | 1x |

**Self-evaluation prompts embedded in skill**:

The `/retrospect` skill contains the evaluation criteria, so Claude Code uses its own context to answer:
- "Did I solve the right problem?" → misread_requirements check
- "Did I handle edge cases?" → missed_edge_case check
- "Did tests reveal type issues?" → type_error check
- etc.

No external prompting needed—the skill guides self-analysis.

### 3. Local Embeddings (Replace OpenAI)

Use sentence-transformers for drift detection:

```python
# src/meta/local_embeddings.py

from sentence_transformers import SentenceTransformer
import numpy as np

class LocalEmbedder:
    """
    Zero-cost embeddings using sentence-transformers.
    Model downloads once, runs locally forever.
    """

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        # Small, fast model (80MB) - downloads once
        self.model = SentenceTransformer(model_name)

    def embed(self, texts: list[str]) -> np.ndarray:
        return self.model.encode(texts, normalize_embeddings=True)

    def similarity(self, text1: str, text2: str) -> float:
        embeddings = self.embed([text1, text2])
        return float(np.dot(embeddings[0], embeddings[1]))

    def drift_score(self, intent: str, learnings: list[str]) -> float:
        """
        Calculate drift score: how far learnings have drifted from intent.
        Returns 0.0 (perfectly aligned) to 1.0 (completely drifted).
        """
        if not learnings:
            return 0.0

        intent_emb = self.embed([intent])[0]
        learning_embs = self.embed(learnings)

        # Average similarity to intent
        similarities = [float(np.dot(intent_emb, l_emb)) for l_emb in learning_embs]
        avg_similarity = np.mean(similarities)

        # Convert similarity (0-1) to drift (0-1)
        # similarity=1 → drift=0, similarity=0 → drift=1
        return 1.0 - avg_similarity


# Installation (one-time):
# pip install sentence-transformers
# or: uv add sentence-transformers
```

### 4. Free Benchmark Alternative

If SWE-bench is too heavy, use a lighter alternative:

```python
# scripts/generate_mini_benchmark.py

"""
Generate a mini benchmark from this repository's own issues.
Zero external dependencies.
"""

import subprocess
import json
from pathlib import Path

def extract_test_tasks() -> list[dict]:
    """
    Extract tasks from this repo's test failures and past commits.
    """
    tasks = []

    # 1. Find commits that fixed bugs (commit message contains "fix")
    result = subprocess.run(
        ["git", "log", "--oneline", "--grep=fix", "-n", "20"],
        capture_output=True, text=True
    )
    for line in result.stdout.strip().split('\n'):
        if line:
            commit_hash, message = line.split(' ', 1)
            tasks.append({
                'id': f'git-{commit_hash}',
                'type': 'bug_fix',
                'description': message,
                'commit': commit_hash,
                'difficulty': 'medium'
            })

    # 2. Extract from TODO comments in codebase
    result = subprocess.run(
        ["grep", "-r", "TODO:", "--include=*.py", "."],
        capture_output=True, text=True
    )
    for i, line in enumerate(result.stdout.strip().split('\n')[:10]):
        if line and 'TODO:' in line:
            tasks.append({
                'id': f'todo-{i}',
                'type': 'feature',
                'description': line.split('TODO:')[1].strip(),
                'file': line.split(':')[0],
                'difficulty': 'easy'
            })

    return tasks

def create_synthetic_tasks() -> list[dict]:
    """
    Create synthetic but realistic tasks for testing.
    """
    return [
        {
            'id': 'synth-1',
            'type': 'bug_fix',
            'description': 'Fix: TypeError when calling function with None argument',
            'setup': 'Create a function that crashes on None, write test that catches it',
            'difficulty': 'easy'
        },
        {
            'id': 'synth-2',
            'type': 'feature',
            'description': 'Add retry logic with exponential backoff to HTTP client',
            'setup': 'Create HTTP client class, implement retry decorator',
            'difficulty': 'medium'
        },
        {
            'id': 'synth-3',
            'type': 'refactor',
            'description': 'Extract duplicated validation logic into shared module',
            'setup': 'Create 3 files with duplicated code, refactor to DRY',
            'difficulty': 'medium'
        },
        # Add more as needed...
    ]

if __name__ == "__main__":
    tasks = extract_test_tasks() + create_synthetic_tasks()
    Path(".claude/cache/experiments/mini_benchmark.json").write_text(
        json.dumps(tasks, indent=2)
    )
    print(f"Generated {len(tasks)} tasks")
```

## Cost Reduction Strategies

### Model Cost Optimization

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Use Haiku for classification | 90% cheaper than Opus | Lower accuracy on edge cases |
| Reduce task count (50 → 20 per phase) | 60% reduction | Lower statistical power |
| Use Sonnet instead of Opus for worker | 80% cheaper | May reduce baseline performance |
| Cache embeddings | ~100% on repeats | Storage overhead |

### Estimated Costs (Full Experiment)

**Original Design (185 tasks × 4 phases):**
- Opus worker: ~$150-300 (depending on attempts)
- Braintrust: ~$50/month
- Human annotation: ~$200 (100 samples @ $2/each)
- Separate judge LLM: ~$50
- **Total: ~$450-600**

**Claude Code Only Design (Agent-as-Judge):**
- Claude Code (worker + self-retrospection): ~$50-100
- Local tracing: $0
- Local embeddings: $0
- **Total: ~$50-100** (80-85% reduction)

The key insight: retrospection happens within the same Claude Code session that did the work. No separate API calls for judging.

### Minimal Viable Experiment

For initial validation with minimal cost:

```
Phases: 3 (skip human tuning phase initially)
Tasks per phase: 15 (instead of 50)
Total tasks: 45

Model: Claude Code (single agent for work + retrospection)
Embeddings: Local (sentence-transformers)
Tracing: Local SQLite

Estimated cost: ~$15-30 (just Claude Code API)
```

## Implementation: Zero-Dependency Experiment Runner

```python
# scripts/run_experiment_local.py

"""
Run the meta-retrospection experiment with zero external dependencies.

Usage:
    uv run python scripts/run_experiment_local.py --phases 3 --tasks-per-phase 15
"""

import argparse
import asyncio
from pathlib import Path

# Local imports (no external deps except anthropic SDK)
from src.meta.local_tracing import LocalTracer
from src.meta.llm_judge import classify_failure, check_learning_application
from src.meta.local_embeddings import LocalEmbedder


async def run_experiment(
    phases: int = 3,
    tasks_per_phase: int = 15,
    model: str = "claude-sonnet-4-20250514"
):
    """Run experiment with local infrastructure."""

    # Initialize local components
    tracer = LocalTracer()
    embedder = LocalEmbedder()
    experiment_id = f"exp-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    # Load tasks (from local benchmark or SWE-bench)
    tasks = load_tasks(tasks_per_phase * phases)

    # Phase 1: Baseline
    print("Phase 1: Baseline (no learning)")
    for task in tasks[:tasks_per_phase]:
        session_id = tracer.start_session(experiment_id, 1, task['id'])
        success = await run_task(task, model, learnings=[])
        if not success:
            failure_mode = await classify_failure(...)
            tracer.end_session(session_id, False, {'failure_mode': failure_mode})
        else:
            tracer.end_session(session_id, True)

    # Phase 2: Retrospection
    print("Phase 2: Retrospection enabled")
    learnings = []
    for task in tasks[tasks_per_phase:tasks_per_phase*2]:
        session_id = tracer.start_session(experiment_id, 2, task['id'])
        success = await run_task(task, model, learnings=learnings)

        # Retrospect
        retrospection = await run_retrospection(task, success)
        learnings.extend(retrospection['learnings'])

        # Check if prior learning was applied
        if learnings:
            application = await check_learning_application(learnings[:-1], ...)
            tracer.end_session(session_id, success, {
                'learning_applied': application['learning_id']
            })

    # Phase 3: Meta-retrospection
    print("Phase 3: Meta-retrospection enabled")
    for i, task in enumerate(tasks[tasks_per_phase*2:]):
        session_id = tracer.start_session(experiment_id, 3, task['id'])
        success = await run_task(task, model, learnings=learnings)

        # Retrospect
        retrospection = await run_retrospection(task, success)
        learnings.extend(retrospection['learnings'])

        # Meta-retrospect every 5 tasks
        if (i + 1) % 5 == 0:
            drift_score = embedder.drift_score(
                intent="Produce reliable, maintainable code",
                learnings=[l['insight'] for l in learnings[-15:]]
            )
            recurring = detect_recurring_issues(tracer, experiment_id, 3)
            print(f"  Meta-retrospection: drift={drift_score:.2f}, recurring={recurring}")

        tracer.end_session(session_id, success)

    # Generate report
    report = generate_report(tracer, experiment_id, embedder)
    Path(f".claude/cache/experiments/{experiment_id}/report.md").write_text(report)
    print(f"\nExperiment complete. Report: .claude/cache/experiments/{experiment_id}/report.md")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--phases", type=int, default=3)
    parser.add_argument("--tasks-per-phase", type=int, default=15)
    parser.add_argument("--model", default="claude-sonnet-4-20250514")
    args = parser.parse_args()

    asyncio.run(run_experiment(args.phases, args.tasks_per_phase, args.model))
```

## New Dependencies (All Free)

Add to `pyproject.toml`:

```toml
[project]
dependencies = [
    # Existing...
    "sentence-transformers>=2.2.0",  # Local embeddings (~80MB model)
    "datasets>=2.14.0",              # Hugging Face datasets (SWE-bench)
]
```

## Summary: What's Paid vs. Free

| Component | Status | Notes |
|-----------|--------|-------|
| SWE-bench dataset | ✅ Free | Open source on Hugging Face |
| Local tracing | ✅ Free | SQLite (existing infrastructure) |
| Agent-as-judge | ✅ Free | Same Claude Code session does retrospection |
| Local embeddings | ✅ Free | sentence-transformers (MIT license) |
| Statistical analysis | ✅ Free | scipy, pandas (existing) |
| Braintrust | ❌ Removed | Replaced with local tracer |
| Human annotators | ❌ Removed | Claude Code self-evaluates |
| Separate judge LLM | ❌ Removed | Agent-as-judge pattern |
| External embedding APIs | ❌ Removed | Replaced with local embeddings |
| **Claude Code** | 💰 Only Cost | ~$50-100 full experiment, ~$15-30 minimal |

**Single LLM Architecture**: Claude Code is the only LLM. It does the work AND retrospects on its own work within the same session. This eliminates all additional API costs.

```
┌──────────────────────────────────────────────────────────┐
│  CLAUDE CODE = WORKER + RETROSPECTOR + META-RETROSPECTOR │
│                                                           │
│  Session 1: Task → Work → /retrospect → JSON             │
│  Session 2: Task → Work → /retrospect → JSON             │
│  ...                                                      │
│  Session 5: → /meta-retrospect (analyze retrospections)  │
│                                                           │
│  All sessions use the SAME Claude Code instance          │
└──────────────────────────────────────────────────────────┘
```

---

## Original References

- Current learning extraction: `scripts/braintrust_analyze.py`
- Current compound learnings: `.claude/skills/compound-learnings/`
- Artifact indexing: `scripts/artifact_index.py`

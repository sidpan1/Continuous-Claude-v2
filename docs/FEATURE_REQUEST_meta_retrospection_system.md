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

## Original References

- Current learning extraction: `scripts/braintrust_analyze.py`
- Current compound learnings: `.claude/skills/compound-learnings/`
- Artifact indexing: `scripts/artifact_index.py`

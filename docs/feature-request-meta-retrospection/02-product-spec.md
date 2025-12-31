# Meta-Retrospection System: Product Specification

## Overview

This document defines the user stories, acceptance criteria, and priorities for the meta-retrospection system.

## Epic Summary

Build a hierarchical learning system with three automated layers (worker, retrospector, meta-retrospector) and humans at the policy level.

## User Stories

### Story 1: Structured Retrospection Output (P0 - Foundation)

**As a** system operator
**I want** retrospection to produce structured JSON
**So that** downstream analysis can process learnings programmatically

#### Tasks
- [ ] Create Pydantic schema for retrospection output
- [ ] Update `scripts/braintrust_analyze.py` to output structured JSON
- [ ] Create storage directory `.claude/cache/retrospections/`
- [ ] Add SQLite table for retrospection index

#### Acceptance Criteria
- [ ] Retrospection outputs valid JSON matching schema
- [ ] JSON includes: `session_id`, `timestamp`, `intent`, `outcome`, `learnings[]`, `failures[]`
- [ ] Retrospections are queryable via SQLite
- [ ] Unit tests pass for schema validation

**Complexity:** Medium (2-3 days)

---

### Story 2: Retrospect Skill (P0 - Foundation)

**As a** Claude Code user
**I want** a `/retrospect` command
**So that** I can trigger end-of-session analysis manually

#### Tasks
- [ ] Create `.claude/skills/retrospect/SKILL.md`
- [ ] Create `scripts/retrospect.py` with CLI interface
- [ ] Integrate with trace fetching (Braintrust or local)
- [ ] Add intent extraction from session start

#### Acceptance Criteria
- [ ] `/retrospect` command is discoverable in Claude Code
- [ ] Command produces structured JSON in `.claude/cache/retrospections/`
- [ ] Works with and without Braintrust (graceful degradation)
- [ ] Skill triggers on "analyze session" type queries

**Complexity:** Medium (2-3 days)

---

### Story 3: Meta-Retrospection Script (P1 - Core)

**As a** system
**I want** to analyze batches of retrospections
**So that** I can detect trends in learning effectiveness

#### Tasks
- [ ] Create `scripts/meta_retrospect.py`
- [ ] Implement trend detection (improving/stable/degrading)
- [ ] Implement recurring issue detection
- [ ] Implement learning application rate calculation
- [ ] Output recommendations as structured JSON

#### Acceptance Criteria
- [ ] Script accepts `--batch-size N` parameter
- [ ] Correctly identifies issues flagged 3+ times
- [ ] Calculates learning application rate from subsequent sessions
- [ ] Outputs to `.claude/cache/meta-retrospections/<batch>.json`
- [ ] Unit tests for each detection algorithm

**Complexity:** High (4-5 days)

---

### Story 4: Meta-Retrospect Skill (P1 - Core)

**As a** Claude Code user
**I want** a `/meta-retrospect` command
**So that** I can trigger batch analysis of past retrospections

#### Tasks
- [ ] Create `.claude/skills/meta-retrospect/SKILL.md`
- [ ] Wire skill to `scripts/meta_retrospect.py`
- [ ] Add human-readable summary output
- [ ] Generate recommendations for retrospector prompt adjustments

#### Acceptance Criteria
- [ ] `/meta-retrospect` command works
- [ ] Produces both JSON and human-readable summary
- [ ] Recommendations are actionable (specific prompt changes)
- [ ] Works on minimum of 5 retrospections

**Complexity:** Medium (2-3 days)

---

### Story 5: Human Policy Configuration (P2 - Human Layer)

**As a** human operator
**I want** to define my intent and thresholds in a config file
**So that** the system knows when to alert me

#### Tasks
- [ ] Create `.claude/meta/human-policy.yaml` schema
- [ ] Add policy loading to meta-retrospector
- [ ] Implement threshold-based alerting
- [ ] Create policy validation on load

#### Acceptance Criteria
- [ ] Policy file is human-editable YAML
- [ ] System alerts when `drift_score` exceeds threshold
- [ ] System alerts when `recurring_issues` exceeds threshold
- [ ] Invalid policy produces clear error message

**Example policy file:**
```yaml
intent:
  primary_goals:
    - "Produce reliable, maintainable code"
    - "Minimize production bugs"
  constraints:
    - "Prefer simplicity over cleverness"
    - "Test before commit"

thresholds:
  alert_on_drift_score: 0.3
  alert_on_recurring_issues: 3
  min_learning_application_rate: 0.6

review_frequency: "weekly"
```

**Complexity:** Low (1-2 days)

---

### Story 6: Drift Detection Algorithm (P2 - Human Layer)

**As a** meta-retrospector
**I want** to measure how far learnings have drifted from stated intent
**So that** I can alert humans when the system is optimizing for wrong goals

#### Tasks
- [ ] Define drift scoring algorithm (0.0-1.0 scale)
- [ ] Implement semantic similarity using local embeddings
- [ ] Add drift score to meta-retrospection output
- [ ] Create visualization of drift over time

#### Acceptance Criteria
- [ ] Drift score is 0.0-1.0 (0 = aligned, 1 = drifted)
- [ ] Algorithm uses local embeddings (sentence-transformers)
- [ ] Drift score correlates with human judgment (validate on 10 samples)
- [ ] Historical drift scores stored for trend analysis

**Complexity:** High (4-5 days)

---

### Story 7: Automatic Meta-Retrospection Trigger (P3 - Automation)

**As a** system
**I want** meta-retrospection to run automatically every N sessions
**So that** trends are detected without manual intervention

#### Tasks
- [ ] Add session counter to retrospection storage
- [ ] Create hook or trigger for meta-retrospection
- [ ] Add configuration for trigger frequency
- [ ] Implement quiet mode (no alerts if all thresholds OK)

#### Acceptance Criteria
- [ ] Meta-retrospection runs automatically after configured N sessions
- [ ] Produces alerts only when thresholds exceeded
- [ ] Can be disabled via policy config
- [ ] Logs execution in `.claude/cache/meta-retrospections/`

**Complexity:** Medium (2-3 days)

---

### Story 8: Human Dashboard Report (P3 - Observability)

**As a** human operator
**I want** a readable report of system health
**So that** I can quickly understand what needs attention

#### Tasks
- [ ] Create `scripts/human_dashboard.py`
- [ ] Generate markdown report from meta-retrospection data
- [ ] Include trend indicators
- [ ] Highlight actionable recommendations

#### Acceptance Criteria
- [ ] Report is generated as markdown file
- [ ] Includes: summary stats, trend direction, top issues, recommendations
- [ ] Can be generated on-demand via CLI
- [ ] Report is under 100 lines (scannable in 2 minutes)

**Complexity:** Medium (2-3 days)

---

### Story 9: Observability & Audit Trail (P3 - Observability)

**As a** human operator
**I want** to trace any decision back through all layers
**So that** I can debug unexpected behavior

#### Tasks
- [ ] Add reasoning field to all layer outputs
- [ ] Create trace viewer script
- [ ] Link retrospections → meta-retrospections → policy
- [ ] Add timestamps and version info to all outputs

#### Acceptance Criteria
- [ ] Given any learning, can trace back to: which session, which meta-batch, which policy
- [ ] `scripts/trace_decision.py --learning-id X` shows full chain
- [ ] All outputs include `_meta` field with timestamps

**Complexity:** Medium (2-3 days)

---

## Priority Summary

| Priority | Stories | Rationale |
|----------|---------|-----------|
| **P0** | 1, 2 | Foundation - enables data collection |
| **P1** | 3, 4 | Core meta-layer logic |
| **P2** | 5, 6 | Human layer integration |
| **P3** | 7, 8, 9 | Automation and polish |

## Success Metrics

| Metric | Target |
|--------|--------|
| Recurring issue rate | <20% (down from ~40% baseline) |
| Learning application rate | >70% |
| Drift score | <0.3 |
| Human time on execution-level fixes | <20% of total time |

## Dependencies

| Story | Depends On |
|-------|------------|
| 2 | 1 (needs schema) |
| 3 | 1 (needs retrospection data) |
| 4 | 3 (wraps script) |
| 6 | 3 (needs batch data) |
| 7 | 3, 4 (needs meta-retrospect working) |
| 8 | 3 (needs meta-retrospection data) |
| 9 | 1, 3 (needs both layers) |

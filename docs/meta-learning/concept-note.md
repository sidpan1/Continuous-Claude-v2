# Meta-Learning System: Concept Note

## The Problem

Claude Code sessions are ephemeral. Each session starts with a blank slate, repeating mistakes from previous sessions. Humans end up debugging individual outputs—low-leverage work that doesn't compound.

**Observable symptoms:**
- Same bug patterns appear across sessions
- "Learnings" exist as scattered notes, rarely applied
- No visibility into whether the system is improving
- Humans fix outputs instead of tuning the process

## First Principles Analysis

### What Does "Learning" Mean for an AI System?

Learning requires three things:
1. **Observation**: Capture what happened (inputs, actions, outcomes)
2. **Evaluation**: Judge what worked vs. failed
3. **Retention**: Store insights in a form that influences future behavior

Traditional ML does this via gradient descent. For LLM agents, we need a different mechanism:
- **Observation** → Session traces, file changes, outcomes
- **Evaluation** → Self-reflection or external judge
- **Retention** → Persistent artifacts (rules, skills, prompts)

### The Calculus Mental Model

Think of improvement as derivatives:

| Derivative | System Layer | What It Measures |
|------------|--------------|------------------|
| Position (x) | Worker | Current output quality |
| Velocity (dx/dt) | Retrospector | Rate of improvement per session |
| Acceleration (d²x/dt²) | Meta-Retrospector | Is improvement speeding up or slowing down? |

Each layer reveals patterns invisible to the layer below:
- Worker can't see it's making the same mistake across sessions
- Retrospector can't see its own blind spots accumulating
- Meta-Retrospector detects systemic drift

### Why Three Layers?

**Single layer (worker only):** No learning. Same mistakes repeat.

**Two layers (worker + retrospector):** Captures learnings but no quality control. Garbage learnings accumulate. No way to know if learnings are being applied.

**Three layers (+ meta-retrospector):** Closes the loop. Measures learning effectiveness. Detects drift from intent. Enables humans to tune policy, not outputs.

## Existing Infrastructure Analysis

The Continuous-Claude-v2 repository already has significant learning infrastructure:

### What Exists (Free)

| Component | Location | Function |
|-----------|----------|----------|
| **Continuity Ledger** | `thoughts/ledgers/` | Session state that survives `/clear` |
| **Handoffs** | `thoughts/shared/handoffs/` | Cross-session work transfer with post-mortems |
| **Artifact Index** | `.claude/cache/artifact-index/context.db` | SQLite FTS5 for searching past work |
| **Compound Learnings** | `.claude/skills/compound-learnings/` | Manual pattern → artifact conversion |
| **Rules System** | `.claude/rules/` | Auto-loaded operational guidelines |
| **Skills System** | `.claude/skills/` | Reusable expert workflows |
| **Hooks** | `.claude/hooks/` | Event-driven automation |

### What's Missing

| Gap | Impact |
|-----|--------|
| **Structured retrospection** | Learnings are unstructured markdown, hard to query |
| **Outcome tracking** | No systematic capture of session success/failure |
| **Meta-analysis** | No batch analysis of retrospection quality |
| **Drift detection** | No measurement of alignment with intent |
| **Learning velocity** | No metrics on improvement rate |

### What's Paid (Excluded)

- **Braintrust**: Trace storage, session replay, LLM-as-judge via proxy
- The existing `braintrust_analyze.py --learn` requires Braintrust API

**Design constraint:** Build a system that works entirely with local, free components.

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  HUMAN LAYER                                                 │
│  ───────────                                                 │
│  Declares intent (.claude/intent.yaml)                       │
│  Reviews drift alerts                                        │
│  Approves/rejects meta-recommendations                       │
└─────────────────────────────────────────────────────────────┘
                           ↓ policy
┌─────────────────────────────────────────────────────────────┐
│  META-RETROSPECTOR (batch analysis)                          │
│  ─────────────────                                           │
│  Analyzes N retrospections                                   │
│  Detects: recurring issues, drift, stale patterns            │
│  Outputs: trend report, recommendations, drift score         │
│  Trigger: manual or every N sessions                         │
└─────────────────────────────────────────────────────────────┘
                           ↓ insights
┌─────────────────────────────────────────────────────────────┐
│  RETROSPECTOR (end of session)                               │
│  ────────────                                                │
│  Self-reflection before session ends                         │
│  Captures: what worked, what failed, key decisions           │
│  Outputs: structured JSON to .claude/cache/retrospections/   │
│  Trigger: /retrospect command or SessionEnd hook             │
└─────────────────────────────────────────────────────────────┘
                           ↓ learnings
┌─────────────────────────────────────────────────────────────┐
│  WORKER (Claude Code session)                                │
│  ──────                                                      │
│  Does the actual work                                        │
│  Influenced by: rules, skills, ledger context                │
│  Outputs: code changes, handoffs, task completion            │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Self-Reflection Over External Judge

Without Braintrust, we can't cheaply run an external LLM-as-judge on traces. Instead:

**Approach:** Claude reflects on its own session before ending.

**Why this works:**
- Claude has full context during the session
- No extra API costs (same session)
- Captures tacit knowledge that traces miss ("I almost did X but...")

**Trade-off:** Self-evaluation has blind spots. Mitigated by meta-layer pattern detection.

### 2. File-Based State Over Database-Heavy

The existing system uses SQLite for search but files for primary storage. We follow this pattern:

```
.claude/cache/retrospections/
├── 2024-01-15_abc123.json    # Individual retrospection
├── 2024-01-15_def456.json
└── index.db                   # SQLite index for queries
```

**Why:** Files are human-readable, git-trackable, and don't require database migrations.

### 3. Outcome Marking is Encouraged, Not Required

Retrospections capture Claude's self-assessment. Outcomes capture human judgment.

```yaml
# In retrospection JSON
outcome:
  self_assessed: "partial_success"  # Claude's view
  human_marked: "SUCCEEDED"          # Human override (optional)
  confidence: "high"                 # If human marked
```

**Why:** Requiring human input for every session won't scale. Self-assessment provides signal; human marking improves calibration when available.

### 4. Integration with Compound Learnings

The existing `compound-learnings` skill does pattern → artifact conversion. We don't replace it; we feed it better data.

**Current flow:**
```
Raw learnings files → compound-learnings → artifacts
```

**New flow:**
```
Structured retrospections → meta-retrospect (prioritizes) → compound-learnings → artifacts
```

Meta-retrospection pre-filters and prioritizes, making compound-learnings more effective.

### 5. Intent as First-Class Artifact

Drift detection requires knowing what we're drifting from. We introduce an intent file:

```yaml
# .claude/intent.yaml
goals:
  - "Produce correct, maintainable code"
  - "Minimize debugging cycles"

anti-goals:
  - "Optimize for token efficiency at cost of correctness"
  - "Over-engineer solutions"

success_signals:
  - "Tests pass on first run"
  - "No rework needed after PR review"
```

This is the "north star" for drift measurement.

## What This Enables

### For the System
- **Pattern detection**: Automatically surface recurring issues
- **Drift alerts**: Notify when learnings diverge from intent
- **Effectiveness tracking**: Measure if created rules actually help
- **Prioritized learning**: Focus compound-learnings on high-signal patterns

### For Humans
- **Policy-level control**: Tune thresholds, not individual outputs
- **Visibility**: Dashboard showing learning health
- **Leverage**: Small adjustments cascade through the system

### Measurable Outcomes
| Metric | Baseline | Target |
|--------|----------|--------|
| Recurring issue rate | ~40% (estimated) | <20% |
| Learning application rate | Unknown | >60% |
| Drift score | Unmeasured | <0.3 |
| Human time on execution fixes | High | <20% of time |

## Alternative Approaches Considered

### A. External LLM Judge (Rejected)

**Approach:** Send session transcript to separate LLM for evaluation.

**Why rejected:**
- Extra API costs per session
- Requires Braintrust or similar infrastructure
- Self-reflection captures context external judge lacks

### B. Embedding-Based Drift Only (Rejected)

**Approach:** Use sentence-transformers locally for all analysis.

**Why rejected:**
- Embeddings good for similarity, poor for reasoning
- Can't generate actionable recommendations
- Keep embeddings for drift scoring only, use Claude for analysis

### C. Continuous Learning (Rejected)

**Approach:** Update rules/skills after every session automatically.

**Why rejected:**
- High variance per session
- Risk of over-fitting to recent work
- Batch analysis provides statistical smoothing

### D. No Meta Layer (Considered)

**Approach:** Just do structured retrospection + compound-learnings.

**Trade-off:** Simpler but no visibility into learning effectiveness. We'd never know if the system is actually improving. Kept meta-layer for observability.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| **Self-reflection blind spots** | Meta-layer detects patterns Claude misses about itself |
| **Drift toward proxy metrics** | Explicit intent file + drift scoring |
| **Noise amplification** | Batch analysis + signal thresholds (3+ occurrences) |
| **Complexity** | Progressive rollout: retrospection first, meta later |
| **Stale patterns** | Meta-retrospector flags rules not correlated with success |

## Relationship to Existing Skills

| Existing Skill | Relationship |
|----------------|--------------|
| `compound-learnings` | **Consumer** of meta-retrospect output |
| `recall-reasoning` | Can query retrospection index |
| `research` | Retrospections reference research outputs |
| `create_handoff` | Handoff includes retrospection summary |
| `debug` | Can reference past retrospections for similar issues |

## Summary

The meta-learning system adds two capabilities to the existing infrastructure:

1. **Structured retrospection**: Capture session learnings in queryable format
2. **Meta-analysis**: Batch analysis of retrospection quality and drift

These integrate with (not replace) existing compound-learnings, rules, and skills systems. The goal is to close the learning loop: not just capture learnings, but measure if they're working.

**Next step:** Product specification with concrete user stories and acceptance criteria.

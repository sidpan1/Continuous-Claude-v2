# Meta-Retrospection System: Concept Document

## The Problem

Coding agents make mistakes. They make the **same** mistakes repeatedly. Each session starts fresh, learning nothing from past failures.

Current state:
- Agent fixes a bug, forgets what worked
- Same failure mode appears across sessions
- Humans debug individual outputs (low leverage)
- No compound learning over time

## The Insight: Calculus as a Mental Model

Think of learning as derivatives:

| Physics | System Layer | What It Measures |
|---------|--------------|------------------|
| **Position** | Worker | Where we are (task output) |
| **Velocity** (dx/dt) | Retrospector | Rate of improvement |
| **Acceleration** (d²x/dt²) | Meta-Retrospector | Is improvement speeding up or slowing down? |

Each derivative reveals patterns invisible to the layer below:
- Worker can't see it's making the same mistake across sessions
- Retrospector can't see its own blind spots accumulating
- Meta-Retrospector detects drift, stale patterns, and fatigue

## The Solution: Three Layers + Humans

```
┌─────────────────────────────────────────────────────────────┐
│  HUMAN LAYER                                                 │
│  ───────────                                                 │
│  Declares intent. Tunes policy. Reviews drift alerts.        │
│  Spends time on strategy, not execution.                     │
└─────────────────────────────────────────────────────────────┘
                           ↓ policy
┌─────────────────────────────────────────────────────────────┐
│  META-RETROSPECTOR (runs every N sessions)                   │
│  ─────────────────                                           │
│  Analyzes batches of retrospections.                         │
│  Detects: recurring issues, drift from intent, stale rules.  │
│  Outputs: trend analysis, recommendations, drift score.      │
└─────────────────────────────────────────────────────────────┘
                           ↓ adjustments
┌─────────────────────────────────────────────────────────────┐
│  CLAUDE CODE SESSION (worker + retrospector)                 │
│  ─────────────────────────────────────                       │
│  Does the work. Runs tests. Self-evaluates.                  │
│  Outputs: structured retrospection JSON.                     │
│                                                              │
│  ONE session = work + retrospection = ONE cost               │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Worker and Retrospector Are the Same Session

No separate "judge" LLM. Claude Code does the work, then retrospects on that work in the same session. This:
- Eliminates extra API costs
- Keeps full context available during self-evaluation
- Matches how humans naturally reflect on their work

### 2. Meta-Retrospection Operates on Batches

Running meta-analysis per-session would be:
- Expensive (extra LLM calls)
- Statistically meaningless (trends need multiple data points)
- Noisy (individual sessions vary)

Instead, meta-retrospection runs every 5-10 sessions, analyzing patterns across the batch.

### 3. Humans Stay at High Abstraction

Humans should not fix individual worker outputs. That's low leverage.

Instead, humans:
- Define **intent** (what success looks like)
- Set **thresholds** (when to alert)
- Review **drift reports** (is the system optimizing for the wrong thing?)
- Approve **policy changes** (adjustments to how the system learns)

Small adjustments at the meta-layer cascade through retrospection → worker with amplified effect.

### 4. Structured Output Enables Automation

Retrospections output structured JSON, not prose. This enables:
- Automated trend detection
- Query-able learning database
- Drift score calculation
- Cross-session pattern matching

## What Success Looks Like

**Before:**
- Same bugs appear repeatedly
- Learnings are informal notes, rarely applied
- Humans fix individual failures
- No visibility into learning effectiveness

**After:**
- Recurring issues drop 50%+
- 70%+ of relevant learnings get applied
- Humans tune policies, not outputs
- Dashboard shows learning health at a glance

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| **Alignment drift** - system optimizes for proxy metrics | Drift detection alerts when learnings diverge from stated intent |
| **Noise amplification** - each layer adds variance | Batch operations + statistical smoothing |
| **Complexity** - three layers feel heavy | Clear separation + good observability |
| **Over-automation** - humans disengage | Required human approval for major changes |

## What This Is NOT

- **Not a chatbot memory system** - This is structured learning for task execution, not conversation recall
- **Not automatic improvement** - Each layer requires explicit triggers and outputs
- **Not unsupervised** - Humans define intent and review drift; the system surfaces patterns, humans make decisions

## Next Steps

See companion documents:
- `02-product-spec.md` - User stories and acceptance criteria
- `03-implementation-spec.md` - Technical architecture and code patterns
- `04-experiment-design.md` - How we'll validate this works

# Collaborative Self-Improving AI: Product Specification

## Vision

**An AI coding assistant that learns from every interaction, improves itself over time, and collaborates with humans at every level of that improvement.**

This isn't just a tool that remembers things. It's a system that:
- Reflects on its own work
- Detects patterns across sessions
- Proposes improvements to itself
- Learns how to learn better
- Keeps humans in control of alignment at every layer

---

## The Core Insight

Learning happens at multiple levels, and each level can improve the levels below:

```
Work → produces → Retrospection
Retrospection → reveals → Patterns
Patterns → become → Rules/Skills
Rules/Skills → improve → Work
Meta-analysis → improves → The learning process itself
```

This creates a **recursive improvement loop** where the system doesn't just get better at coding—it gets better at getting better.

---

## System Overview

### The Learning Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 4: META-META                                              │
│  "Is our learning process effective?"                            │
│  Human role: Approve changes to how system learns                │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: META-RETROSPECTION                                     │
│  "What patterns appear across sessions?"                         │
│  Human role: Approve rules/skills, correct drift                 │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: RETROSPECTION                                          │
│  "What worked and failed this session?"                          │
│  Human role: Confirm outcomes, provide context                   │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1: WORK                                                   │
│  "Execute tasks, write code"                                     │
│  Human role: Provide tasks, review output                        │
└─────────────────────────────────────────────────────────────────┘
```

### Operating Modes

| Mode | Description | Learning Behavior |
|------|-------------|-------------------|
| **Synchronous** | Human present, real-time collaboration | Reflection at session end |
| **Asynchronous** | AI works autonomously toward objective | Reflection at checkpoints + end |

### Work Organization

```
Epic (large initiative)
├── Story (1-4 hour chunk, right-sized for async)
│   ├── Task (15-60 min, atomic unit)
│   ├── Task
│   └── Task
├── Story
└── Bug (can appear at any level)
```

Issues are both **work containers** and **learning artifacts**.

---

## User Journeys

### Part 1: Setup Journeys

#### Journey 1.1: Repository Onboarding

**Goal:** System learns the project; human validates understanding.

**The Problem:** Asking users "what are your values?" is too abstract. They don't know what to say without context.

**The Solution:** Observe first, confirm later.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "Set up learning for this project"                        │
│                                                                  │
│  Claude: "Analyzing your repository..."                         │
│                                                                  │
│  [30 seconds later]                                              │
│                                                                  │
│  Claude: "Here's what I learned about your project:             │
│                                                                  │
│  **Codebase Signals**                                            │
│  • TypeScript strict mode enabled                               │
│  • 78% test coverage                                            │
│  • ESLint with 47 rules active                                  │
│  • Husky pre-commit hooks                                       │
│  • PR template requires checklist                               │
│                                                                  │
│  **From Your Docs**                                              │
│  • CONTRIBUTING.md: 'All changes must have tests'               │
│  • README: 'Production-ready code only'                         │
│                                                                  │
│  **My Inference**                                                │
│  You prioritize: Correctness > Speed, Consistency > Flexibility │
│                                                                  │
│  Does this sound right?                                          │
│                                                                  │
│  [Yes, that's us] [Mostly, but...] [Let me explain]"            │
│                                                                  │
│  Dev: "Mostly, but we also care about performance—we've had     │
│        incidents from slow queries."                             │
│                                                                  │
│  Claude: "Added 'query performance' to priorities.              │
│  Created .claude/intent.yaml based on this conversation."       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** System does the analysis; human just confirms or corrects.

---

#### Journey 1.2: Setting an Autonomous Objective

**Goal:** Define what "done" looks like and constraints for unattended work.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "I need you to work on caching overnight while I sleep."  │
│                                                                  │
│  Claude: "I can work autonomously. Let me confirm the scope:    │
│                                                                  │
│  **Objective**                                                   │
│  Add caching to API endpoints                                    │
│                                                                  │
│  **I'll pause and ask if:**                                      │
│  • Architectural decisions needed                               │
│  • Same approach fails 3 times                                  │
│  • Security concerns found                                      │
│  • Scope exceeds 500 lines                                      │
│                                                                  │
│  **I'll keep going if:**                                         │
│  • Minor blockers I can solve                                   │
│  • Tests pass                                                   │
│  • Within scope                                                 │
│                                                                  │
│  **Time limit:** 4 hours                                         │
│                                                                  │
│  **Learning behavior:**                                          │
│  • Checkpoint reflection every 30 minutes                       │
│  • Full retrospection at end                                    │
│  • Learnings applied to subsequent tasks                        │
│                                                                  │
│  Any other constraints?"                                         │
│                                                                  │
│  Dev: "Use existing Redis. Don't touch auth endpoints."          │
│                                                                  │
│  Claude: "Got it. Starting autonomous work now."                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### Part 2: Synchronous Journeys (Human-in-Loop)

#### Journey 2.1: Regular Work Session

**Goal:** Normal coding with learning happening invisibly.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Normal 45-minute coding session]                               │
│                                                                  │
│  Dev: "Add user authentication"                                  │
│  Claude: [implements]                                            │
│                                                                  │
│  Dev: "Tests failing"                                            │
│  Claude: [tries approach A - fails]                              │
│  Claude: [tries approach B - works]                              │
│                                                                  │
│  Dev: "Great, also add rate limiting"                            │
│  Claude: [implements]                                            │
│                                                                  │
│  [Session ending]                                                │
│                                                                  │
│  Claude: "Before we wrap up, quick reflection? (30 sec)"        │
│                                                                  │
│  Dev: "Sure"                                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Zero friction during work. Learning is invisible until natural breakpoints.

---

#### Journey 2.2: End-of-Session Reflection

**Goal:** Capture learnings while context is fresh.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "Reflecting on our session...                          │
│                                                                  │
│  **What we built:**                                              │
│  • JWT authentication for /api/auth                             │
│  • Rate limiting middleware                                     │
│                                                                  │
│  **What worked:**                                                │
│  • Using existing middleware pattern from /api/logging          │
│  • Testing with curl before writing unit tests                  │
│                                                                  │
│  **What we had to retry:**                                       │
│  • First tried session-based auth (wrong for API)               │
│                                                                  │
│  **Pattern I noticed:**                                          │
│  'Check existing patterns before implementing new features'     │
│                                                                  │
│  Did this session achieve your goal?                             │
│  [Yes] [Partially] [No] [Skip]"                                  │
│                                                                  │
│  Dev: [Yes]                                                      │
│                                                                  │
│  Claude: "Retrospection saved. This will inform future work."   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### Part 3: Asynchronous Journeys (Autonomous Mode)

#### Journey 3.1: Monitoring Progress

**Goal:** Check on autonomous work without interrupting.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Dev checks phone]                                              │
│                                                                  │
│  Claude: "🟢 Autonomous work in progress                         │
│                                                                  │
│  **Status:** 2.5 hours in, ~60% complete                        │
│                                                                  │
│  **Done:**                                                       │
│  ✓ GET /products - cached                                       │
│  ✓ GET /products/:id - cached                                   │
│  ✓ GET /orders - cached                                         │
│                                                                  │
│  **In progress:**                                                │
│  → Cache invalidation logic                                     │
│                                                                  │
│  **Learnings so far:**                                           │
│  • This codebase prefers explicit cache keys                    │
│  • 5-min TTL works well for read-heavy endpoints                │
│                                                                  │
│  No blockers. Continuing."                                       │
│                                                                  │
│  Dev: [closes phone]                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Journey 3.2: Self-Correction Mid-Session

**Goal:** System catches its own drift without human intervention.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Async session, internal log]                                   │
│                                                                  │
│  Claude (2-hour checkpoint reflection):                          │
│                                                                  │
│  "**Self-check:**                                                │
│                                                                  │
│  Objective: Add caching to API endpoints                        │
│  Current focus: Optimizing Redis connection pooling             │
│                                                                  │
│  ⚠️ **Drift detected**                                          │
│                                                                  │
│  I've spent 40 minutes on connection pooling.                   │
│  This is scope creep—pooling works fine already.                │
│                                                                  │
│  Intent file says: 'Don't over-engineer'                        │
│                                                                  │
│  **Self-correction:**                                            │
│  Reverting pooling changes. Returning to endpoint caching.      │
│  Noting 'pooling optimization' for future backlog."             │
│                                                                  │
│  [Continues on original objective]                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Intent file is the guardrail when humans aren't present.

---

#### Journey 3.3: Escalation

**Goal:** System pauses for human input when needed.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "🟡 Need your input                                     │
│                                                                  │
│  I've paused because I hit a decision point:                     │
│                                                                  │
│  The /reports/sales endpoint has complex cache invalidation.    │
│                                                                  │
│  **Options:**                                                    │
│  [A] 5-min TTL (simple, may be stale)                           │
│  [B] Event-driven invalidation (complex, always fresh)          │
│  [C] Skip this endpoint                                          │
│                                                                  │
│  What would you prefer?"                                         │
│                                                                  │
│  Dev: "A - staleness is fine for reports"                        │
│                                                                  │
│  Claude: "Got it. Resuming.                                      │
│                                                                  │
│  **Learning noted:** 'For reporting endpoints, prefer           │
│  TTL-based caching over event-driven.'                           │
│                                                                  │
│  I'll apply this to similar decisions."                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Human decisions become learnings for future autonomy.

---

#### Journey 3.4: Autonomous Completion

**Goal:** Review results and learnings from autonomous work.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "✅ Autonomous work complete                            │
│                                                                  │
│  **Summary:**                                                    │
│  Added Redis caching to 11 API endpoints.                        │
│  Response time: 340ms → 45ms (87% improvement)                  │
│                                                                  │
│  **Deliverables:**                                               │
│  • PR #47 ready for review                                      │
│  • 31 new tests (all passing)                                   │
│                                                                  │
│  **Decisions made:**                                             │
│  • 5-min TTL for reports (per your guidance)                    │
│  • Skipped /inventory (flagged for later)                       │
│                                                                  │
│  **What I learned:**                                             │
│  • This codebase prefers explicit cache keys                    │
│  • Batch invalidation > per-item invalidation                   │
│  • TTL works well for read-heavy, event-driven for writes       │
│                                                                  │
│  **Retrospection saved.** These learnings will improve          │
│  future caching work.                                            │
│                                                                  │
│  [Review PR] [Start next task] [See full retrospection]"        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### Part 4: Delegation Journeys

#### Journey 4.1: Sync → Async Delegation

**Goal:** Hand off mid-session work to run autonomously.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "This refactoring is bigger than I thought. Can you       │
│        continue in background while I'm in meetings?"            │
│                                                                  │
│  Claude: "I'll create an issue to track this:                   │
│                                                                  │
│  **Issue #52: Refactor UserService to repository pattern**      │
│                                                                  │
│  **Current state:**                                              │
│  ✓ Created UserRepository interface                             │
│  ✓ Migrated findById, findByEmail                              │
│  → In progress: create, update methods                          │
│  ○ Pending: delete, bulk operations                            │
│  ○ Pending: Update 12 call sites                               │
│                                                                  │
│  **Decisions already made:**                                     │
│  • Repository returns domain objects, not Prisma types         │
│                                                                  │
│  **Constraints:**                                                │
│  • Don't modify auth endpoints                                  │
│                                                                  │
│  Create issue and start async work?                              │
│  [Create & Start] [Create Only] [Continue Sync]"                │
│                                                                  │
│  Dev: [Create & Start]                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Issues carry full context across session boundaries.

---

#### Journey 4.2: Work Decomposition

**Goal:** Break large work into right-sized pieces.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Async session discovers scope is larger than expected]         │
│                                                                  │
│  Claude: "🟡 Scope adjustment                                    │
│                                                                  │
│  The caching work is larger than expected (23 endpoints).       │
│  I've broken it into manageable pieces:                          │
│                                                                  │
│  **Epic #52: Add caching to API**                                │
│  ├── Story #53: Cache user endpoints (3) ← Doing now            │
│  ├── Story #54: Cache product endpoints (5)                     │
│  ├── Story #55: Cache order endpoints (4)                       │
│  ├── Story #56: Cache reporting endpoints (7)                   │
│  └── Story #57: Cache admin endpoints (4)                       │
│                                                                  │
│  Each story has tasks:                                           │
│  Story #53 tasks:                                                │
│  ├── Task: Analyze user endpoints                               │
│  ├── Task: Cache GET /users                                     │
│  ├── Task: Cache GET /users/:id                                 │
│  ├── Task: Cache GET /users/me                                  │
│  ├── Task: Add invalidation logic                               │
│  └── Task: Write tests                                          │
│                                                                  │
│  I'll finish #53 this session. Others ready for future."        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Journey 4.3: Picking Up from Backlog

**Goal:** Resume work from issue queue.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "What should we work on?"                                  │
│                                                                  │
│  Claude: "Checking backlog...                                    │
│                                                                  │
│  🔴 **High Priority:**                                           │
│  • #58: Fix payment timeout bug                                 │
│    └─ P0, reported 2 hours ago                                  │
│                                                                  │
│  🟡 **In Progress (from previous sessions):**                    │
│  • #54: Cache product endpoints                                 │
│    └─ 2/5 tasks complete, ready to continue                     │
│                                                                  │
│  🟢 **Ready to Start:**                                          │
│  • #55: Cache order endpoints                                   │
│  • #61: Add input validation                                    │
│                                                                  │
│  **Recommended:** Fix #58 first (production impact).            │
│                                                                  │
│  Which would you like to tackle?"                                │
│                                                                  │
│  Dev: "Fix the payment bug"                                      │
│                                                                  │
│  Claude: "Opening #58. Reading context...                       │
│  I see the error logs. Let me investigate."                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### Part 5: Learning Journeys

#### Journey 5.1: Receiving a Pattern Alert

**Goal:** System surfaces recurring issue for human decision.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "I noticed something across recent sessions:           │
│                                                                  │
│  **Recurring Pattern Detected**                                  │
│                                                                  │
│  'Forgetting to run tests before commit'                        │
│  Appeared in 4 of last 10 sessions.                             │
│                                                                  │
│  **Evidence:**                                                   │
│  • Jan 10: CI failed after push                                 │
│  • Jan 12: Same issue                                           │
│  • Jan 14: Tests would have caught bug                          │
│  • Jan 15: 'I keep doing this'                                  │
│                                                                  │
│  **Suggestion:** Create a rule to remind about tests            │
│  before commits.                                                 │
│                                                                  │
│  [Create Rule] [Dismiss] [Remind Later]"                        │
│                                                                  │
│  Dev: [Create Rule]                                              │
│                                                                  │
│  Claude: "Rule created. I'll remind you about tests             │
│  before commits going forward."                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Journey 5.2: Alignment Correction

**Goal:** Redirect when system is learning wrong lessons.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "**Alignment Alert**                                    │
│                                                                  │
│  I've noticed my recent learnings might be drifting:            │
│                                                                  │
│  Your intent says: 'Correctness first'                          │
│                                                                  │
│  But my recent learnings focus on:                               │
│  • 'Reduce token usage' (6 mentions)                            │
│  • 'Faster completion' (4 mentions)                             │
│  • 'Correctness/testing' (1 mention)                            │
│                                                                  │
│  This could mean:                                                │
│  1. Recent work was legitimately efficiency-focused             │
│  2. I'm optimizing for the wrong thing                          │
│                                                                  │
│  What should I do?                                               │
│                                                                  │
│  [A] Update my goals - efficiency matters now                   │
│  [B] This is drift - refocus on correctness                     │
│  [C] Let me explain the context"                                │
│                                                                  │
│  Dev: "B - we had a crunch but it's over. Back to quality."     │
│                                                                  │
│  Claude: "Understood. Reweighting toward correctness.           │
│  Recent efficiency learnings marked as context-specific."       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Journey 5.3: Weekly Health Check

**Goal:** Quick overview of learning system effectiveness.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "/dashboard"                                               │
│                                                                  │
│  Claude: "                                                       │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║          LEARNING HEALTH  •  Jan 8-15                     ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║  Sessions: 12       Success Rate: 75% ↑                   ║  │
│  ║                                                           ║  │
│  ║  ████████████████░░░░░░░░  Succeeded (9)                  ║  │
│  ║  ████░░░░░░░░░░░░░░░░░░░░  Partial (3)                    ║  │
│  ║                                                           ║  │
│  ║  Recurring Issues: 1 (down from 3)                        ║  │
│  ║  Alignment: 92%                                           ║  │
│  ║  Learning Application: 68%                                ║  │
│  ║                                                           ║  │
│  ║  ✓ System is healthy                                      ║  │
│  ║                                                           ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║  Top insight: 'Run tests before commit' rule              ║  │
│  ║  applied 8 times, prevented 3 CI failures.                ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│  "                                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Journey 5.4: Meta-Learning Review

**Goal:** Evaluate and tune how the system learns.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "How well is the learning system working?"                │
│                                                                  │
│  Claude: "Here's my meta-analysis:                              │
│                                                                  │
│  **Learning Effectiveness**                                      │
│                                                                  │
│  Rules created: 8                                                │
│  Rules that improved outcomes: 5 (62%)                          │
│  Rules with no measurable impact: 2 (25%)                       │
│  Rules that may have hurt: 1 (12%)                              │
│                                                                  │
│  **Retrospection Quality**                                       │
│                                                                  │
│  Sync session retrospections: Detailed, actionable              │
│  Async session retrospections: Often too brief                  │
│                                                                  │
│  **Pattern Detection**                                           │
│                                                                  │
│  Patterns surfaced: 12                                          │
│  Patterns you approved: 8 (67%)                                 │
│  Patterns you rejected: 4 (33%)                                 │
│                                                                  │
│  **Suggested Process Improvements**                              │
│                                                                  │
│  1. Add mid-session reflection for async (briefer retros)       │
│  2. Increase pattern threshold from 3 to 4 (fewer false +)      │
│  3. Retire rule 'always-use-interfaces' (no impact)             │
│                                                                  │
│  Approve these adjustments?                                      │
│  [Approve All] [Review Each] [Dismiss]"                         │
│                                                                  │
│  Dev: [Review Each]                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** The system proposes improvements to itself; humans approve.

---

#### Journey 5.5: Understanding Provenance

**Goal:** Trace why a rule or behavior exists.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "Why do you always remind me about tests?"                │
│                                                                  │
│  Claude: "That comes from a rule created on Jan 12.             │
│                                                                  │
│  **Origin Story:**                                               │
│                                                                  │
│  This rule exists because 'forgetting tests' appeared           │
│  in 4 sessions between Jan 5-12:                                │
│                                                                  │
│  • Jan 5: CI failed, 20 min wasted                              │
│  • Jan 8: Tests would have caught bug                           │
│  • Jan 10: Pushed broken code                                   │
│  • Jan 12: You said 'I keep doing this'                         │
│                                                                  │
│  On Jan 12, I suggested this rule and you approved.             │
│                                                                  │
│  **Impact since creation:**                                      │
│  Applied 12 times, prevented ~4 CI failures.                    │
│                                                                  │
│  Want to modify or remove it?"                                   │
│                                                                  │
│  Dev: "No, keep it. Just curious."                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Recursive Learning Model

### How Each Layer Improves

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LAYER 1: WORK                                                   │
│  Improved by: Rules, skills from Layer 3                        │
│  Example: "Always run tests" rule prevents CI failures          │
│                                                                  │
│  LAYER 2: RETROSPECTION                                          │
│  Improved by: Insights from Layer 4                             │
│  Example: "Add checkpoint reflections in async mode"            │
│                                                                  │
│  LAYER 3: META-RETROSPECTION                                     │
│  Improved by: Analysis from Layer 4                             │
│  Example: "Increase pattern threshold to reduce false +"        │
│                                                                  │
│  LAYER 4: META-META ANALYSIS                                     │
│  Improved by: Human oversight and tuning                        │
│  Example: "Weight human-marked outcomes higher"                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### What Gets Learned at Each Layer

| Layer | Learns About | Examples |
|-------|--------------|----------|
| **Work** | How to code better | "Batch operations > individual" |
| **Retrospection** | What to notice | "Track decisions, not just outcomes" |
| **Meta** | What patterns matter | "3 occurrences = strong signal" |
| **Meta-Meta** | How to learn | "Async retros need more structure" |

### Human Touchpoints

| Layer | Human Role | Effort | Frequency |
|-------|------------|--------|-----------|
| **Work** | Provide tasks, review | Active | Per session |
| **Retrospection** | Mark outcomes | 30 sec | Per session |
| **Meta** | Approve rules/skills | 5 min | When surfaced |
| **Meta-Meta** | Tune learning process | 10 min | Monthly |

---

## Experience Principles

### 1. Invisible When Working

Learning happens in background. No interruptions during active coding.

### 2. Observe First, Confirm Later

System analyzes and proposes; humans validate or correct. Never interrogate.

### 3. Progressive Disclosure

```
Level 0: System learns silently
Level 1: Alerts only on threshold breach
Level 2: Dashboard on request
Level 3: Detailed retrospections if curious
Level 4: Full meta-analysis for tuning
```

### 4. Human Approval for Permanence

Rules, skills, process changes—all require human approval. System proposes, human disposes.

### 5. Evidence-Based Everything

Every suggestion includes:
- How many times pattern appeared
- Which sessions it came from
- What the impact was

No vague recommendations.

### 6. Graceful Degradation

Works at every engagement level:
- Zero engagement: Self-reflection still captures learnings
- Minimal: Occasional yes/no
- Full: Intent file, dashboards, meta-tuning

---

## Success Metrics

### User-Felt Outcomes

| What They Feel | How We Measure |
|----------------|----------------|
| "Claude stops making same mistakes" | Recurring issue rate <20% |
| "Less time re-explaining things" | Context carryover rate >80% |
| "Claude remembers what works" | Learning application rate >60% |
| "System doesn't annoy me" | Alert frequency <2/week |
| "I trust autonomous work" | Async success rate >70% |

### System Health

| Metric | Target | Meaning |
|--------|--------|---------|
| Retrospection completion | >70% | Users engaging with learning |
| Recommendation acceptance | >50% | Suggestions are useful |
| Rule effectiveness | >60% | Rules actually help |
| Drift detection accuracy | >80% | Catching misalignment |
| Escalation appropriateness | >90% | Right things escalated |

---

## Constraints

### What This System Is NOT

1. **Not a keylogger** — Claude reflects on its own work, not surveillance
2. **Not fully automatic** — Humans approve all permanent changes
3. **Not prescriptive** — Learns YOUR patterns, doesn't impose its own
4. **Not invasive** — Zero overhead during active work
5. **Not infallible** — Proposes improvements; humans decide

### Technical Boundaries

- **Local only** — No external services required
- **File-based** — Human-readable, git-trackable
- **Lightweight** — No database servers, no background daemons

---

## Rollout Phases

### Phase 1: Foundation

**Ships:**
- Repository onboarding (observe-first)
- `/retrospect` command
- Structured retrospection storage
- Basic outcome tracking

**Value:** Sessions have memory.

### Phase 2: Intelligence

**Ships:**
- Meta-retrospection (batch analysis)
- Pattern detection
- Rule/skill suggestions
- Recurring issue alerts

**Value:** Patterns surface automatically.

### Phase 3: Autonomy

**Ships:**
- Async mode with checkpoints
- Self-correction mid-session
- Escalation protocol
- Issue-based handoffs

**Value:** Claude works while you sleep.

### Phase 4: Recursion

**Ships:**
- Meta-meta analysis
- Learning process improvements
- Effectiveness tracking
- Full provenance

**Value:** System improves how it improves.

---

## Open Questions

1. **Reflection frequency in async?** Every 30 min? Adaptive based on progress?

2. **Pattern threshold?** 3 occurrences? Should it adapt based on rejection rate?

3. **Rule expiration?** Auto-disable after 30 days of no relevance?

4. **Cross-project learning?** Should learnings transfer between projects?

5. **Team learning?** How do individual learnings become team knowledge?

6. **Escalation timeout?** How long to wait for human before auto-deciding?

---

## Appendix: Interaction Budget

| Activity | Frequency | Duration | Annual Hours |
|----------|-----------|----------|--------------|
| Onboarding | Once | 15 min | 0.25 |
| Objective setting | 2/week | 5 min | 8.7 |
| Session reflection | Daily | 30 sec | 3 |
| Outcome marking | Daily | 5 sec | 0.5 |
| Alert response | 2/week | 3 min | 5.2 |
| Dashboard check | Weekly | 2 min | 1.7 |
| Meta-review | Monthly | 10 min | 2 |
| **Total** | | | **~22 hours/year** |

Compare to: Manual learning tracking, pattern detection, rule writing (~100+ hours/year)

---

## Appendix: Issue Taxonomy

```
📦 EPIC — Large initiative (days/weeks)
│
├── 📖 STORY — Deliverable chunk (1-4 hours)
│   ├── ✅ TASK — Atomic unit (15-60 min)
│   ├── ✅ TASK
│   └── ✅ TASK
│
├── 📖 STORY
│
└── 🐛 BUG — Can appear at any level

💡 SPIKE — Time-boxed research
🔄 CONTINUATION — Auto-created on session timeout
```

---

## Appendix: The Learning Loop Visualized

```
         ┌──────────────────────────────────────────────────────┐
         │                                                      │
         │                    HUMAN LAYER                       │
         │         Intent • Priorities • Approvals              │
         │                                                      │
         └─────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌─────────┐    ┌─────────────┐    ┌──────────────┐             │
│  │  WORK   │───▶│ RETROSPECT  │───▶│    META      │──┐          │
│  │         │    │             │    │              │  │          │
│  │ Tasks   │    │ What worked │    │ Patterns     │  │          │
│  │ Code    │    │ What failed │    │ Trends       │  │          │
│  │ Issues  │    │ Learnings   │    │ Drift        │  │          │
│  └────▲────┘    └─────────────┘    └──────────────┘  │          │
│       │                                              │          │
│       │         Rules, Skills, Process Changes       │          │
│       └──────────────────────────────────────────────┘          │
│                                                                  │
│                        RECURSIVE LOOP                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

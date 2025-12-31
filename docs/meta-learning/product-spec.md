# Meta-Learning System: Product Specification

## Vision

**A coding assistant that gets better every session—not through magic, but through structured reflection and human guidance.**

Today, each Claude Code session starts fresh. The same mistakes repeat. Learnings exist as scattered notes that nobody reads. Humans spend hours debugging outputs instead of building.

Tomorrow: Claude reflects on what worked and what didn't. Patterns surface automatically. Humans guide alignment with minimal effort. The system compounds knowledge over time.

---

## Users

### Primary: The Developer

A software engineer using Claude Code daily. They want Claude to:
- Stop making the same mistakes
- Apply lessons from past sessions
- Surface insights they wouldn't notice
- Require minimal overhead to improve

**Key frustration:** "I feel like I'm training Claude from scratch every session."

### Secondary: The Team Lead

Oversees multiple developers using Claude Code. They want:
- Visibility into what Claude is learning
- Confidence that Claude aligns with team practices
- Ability to encode team knowledge into the system

**Key frustration:** "Each team member teaches Claude different things. There's no shared learning."

---

## Core Principles

### 1. Humans Align, System Executes

Humans shouldn't fix individual outputs. That's low leverage. Instead:
- Humans define what "good" looks like
- System identifies patterns
- Humans approve what becomes permanent
- System applies learnings going forward

### 2. Reflection Over Surveillance

We don't record everything and analyze it externally. Instead:
- Claude reflects on its own work while context is fresh
- Self-assessment captures nuance that logs miss
- Human feedback calibrates over time

### 3. Batch Over Stream

Per-session analysis is noisy. Individual sessions vary. Instead:
- Retrospections accumulate
- Meta-analysis finds patterns across sessions
- Statistical smoothing separates signal from noise

### 4. Progressive Disclosure

Don't overwhelm users with data. Instead:
- Default: System runs quietly
- Alert: Only when thresholds exceeded
- Deep dive: Available on demand

---

## User Journeys

### Journey 1: First-Time Setup

**Goal:** Configure the system to understand what success looks like.

**Duration:** 15-30 minutes, once per project

#### Scene

Dev opens a new project. They've heard the meta-learning system can help Claude improve over time. They want to set it up.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "Help me set up learning for this project"                 │
│                                                                  │
│  Claude: "I'll help you create an intent file. This tells me    │
│  what success looks like for your project.                       │
│                                                                  │
│  Let's start with a few questions:                               │
│                                                                  │
│  1. What matters most in this codebase?                          │
│     □ Correctness (tests pass, no bugs)                          │
│     □ Performance (fast, efficient)                              │
│     □ Maintainability (readable, documented)                     │
│     □ Velocity (ship quickly)                                    │
│                                                                  │
│  Dev: "Correctness first, then maintainability"                  │
│                                                                  │
│  Claude: "Got it. What should I explicitly NOT optimize for?"    │
│                                                                  │
│  Dev: "Don't sacrifice correctness for speed. We're not in a    │
│        rush, we need it right."                                  │
│                                                                  │
│  Claude: "When should I alert you about learning health?"        │
│                                                                  │
│  Dev: "If I keep making the same mistake 3+ times, tell me.      │
│        Otherwise, just learn quietly."                           │
│                                                                  │
│  Claude: "Created .claude/intent.yaml with your preferences.     │
│  I'll start learning from our sessions. You can check progress   │
│  anytime with /dashboard."                                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Intent file created with goals and thresholds
- System knows what to optimize for
- Dev feels setup was quick and painless

#### What Dev DOESN'T Have To Do

- Write YAML manually
- Understand the underlying system
- Configure every threshold
- Read documentation first

---

### Journey 2: Regular Work Session

**Goal:** Do normal work. System learns in background.

**Duration:** Normal session length. Zero overhead.

#### Scene

Dev works on a feature. They use Claude for coding, debugging, refactoring. The session has ups and downs—some approaches work, others don't.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Normal work session - 45 minutes]                              │
│                                                                  │
│  Dev: "Add user authentication to the API"                       │
│  Claude: [implements feature]                                    │
│                                                                  │
│  Dev: "Tests are failing"                                        │
│  Claude: [debugs, tries approach A - doesn't work]               │
│  Claude: [tries approach B - works]                              │
│                                                                  │
│  Dev: "Great, let's also add rate limiting"                      │
│  Claude: [implements rate limiting]                              │
│                                                                  │
│  [Session ending]                                                │
│                                                                  │
│  Claude: "Before we wrap up, I'd like to capture what we         │
│  learned. Takes 30 seconds. Want me to?"                         │
│                                                                  │
│  Dev: "Sure"                                                     │
│                                                                  │
│  [Claude reflects - see Journey 3]                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Work completed normally
- Prompt to reflect is gentle, skippable
- No friction during actual work

#### What Dev DOESN'T Have To Do

- Manually log what worked/failed
- Remember to capture learnings
- Change their workflow

---

### Journey 3: End-of-Session Reflection

**Goal:** Capture what worked and what didn't while context is fresh.

**Duration:** 30-60 seconds

#### Scene

Session is ending. Claude offers to reflect. Dev says yes.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "Reflecting on our session...                           │
│                                                                  │
│  **What we accomplished:**                                       │
│  - Added JWT authentication to /api/auth endpoints               │
│  - Added rate limiting middleware                                │
│                                                                  │
│  **What worked well:**                                           │
│  - Using existing middleware pattern from /api/logging           │
│  - Testing auth flow with curl before writing unit tests         │
│                                                                  │
│  **What we had to retry:**                                       │
│  - First tried session-based auth (wrong for API)                │
│  - Initially missed token expiration handling                    │
│                                                                  │
│  **Pattern I noticed:**                                          │
│  'Check existing codebase patterns before implementing new       │
│   features' - this saved time with rate limiting.                │
│                                                                  │
│  Quick feedback: Did this session achieve your goal?             │
│  [Yes] [Partially] [No] [Skip]"                                  │
│                                                                  │
│  Dev: [clicks Yes]                                               │
│                                                                  │
│  Claude: "Thanks! Retrospection saved. I'll apply these          │
│  learnings in future sessions."                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Learnings captured in structured format
- Dev's feedback calibrates self-assessment
- Takes seconds, not minutes

#### What Dev DOESN'T Have To Do

- Write up what happened
- Categorize learnings
- Decide what's important to remember

---

### Journey 4: Receiving an Alert

**Goal:** Respond to a pattern the system detected.

**Duration:** 2-5 minutes

#### Scene

Dev starts a new session. System has detected a recurring issue.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "Before we start, I noticed something across our        │
│  recent sessions that might be worth addressing.                 │
│                                                                  │
│  **Recurring Issue Detected**                                    │
│                                                                  │
│  'Forgetting to run tests before committing'                     │
│  This has come up in 4 of your last 10 sessions.                 │
│                                                                  │
│  Recent examples:                                                │
│  - Jan 10: 'Pushed, CI failed, had to fix'                       │
│  - Jan 12: 'Same thing, tests would have caught it'              │
│  - Jan 14: 'Forgot again, wasted 20 min on CI feedback loop'     │
│                                                                  │
│  **Suggestion:** Create a rule that reminds me to run tests      │
│  before any commit.                                              │
│                                                                  │
│  [Create Rule] [Dismiss] [Remind Me Later]"                      │
│                                                                  │
│  Dev: [clicks Create Rule]                                       │
│                                                                  │
│  Claude: "Rule created. I'll now remind you to run tests         │
│  before commits. You can adjust this in .claude/rules/           │
│  if needed."                                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Issue surfaced with evidence
- One-click resolution
- Dev didn't have to notice the pattern themselves

#### What Dev DOESN'T Have To Do

- Review all past sessions
- Notice the pattern manually
- Write the rule from scratch
- Figure out where rules go

---

### Journey 5: Weekly Health Check

**Goal:** Quick overview of learning system health.

**Duration:** 2-3 minutes, weekly

#### Scene

Dev wants to see if the learning system is working. They run the dashboard.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "/dashboard"                                               │
│                                                                  │
│  Claude: "                                                       │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║           LEARNING HEALTH  •  Jan 8-15                    ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║   Sessions: 12        Success Rate: 75% ↑                 ║  │
│  ║                                                           ║  │
│  ║   ████████████████████░░░░░░  Succeeded (9)               ║  │
│  ║   ████░░░░░░░░░░░░░░░░░░░░░░  Partial (3)                 ║  │
│  ║   ░░░░░░░░░░░░░░░░░░░░░░░░░░  Failed (0)                  ║  │
│  ║                                                           ║  │
│  ║   Recurring Issues: 1 (down from 3 last week)             ║  │
│  ║   Alignment: 92% (well aligned with your goals)           ║  │
│  ║                                                           ║  │
│  ║   ✓ System is healthy. No action needed.                  ║  │
│  ║                                                           ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║   Top Insight This Week:                                  ║  │
│  ║   'Running tests before commit' rule applied 8 times,     ║  │
│  ║   prevented 3 potential CI failures.                      ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│  "                                                               │
│                                                                  │
│  Dev: "Nice, it's working."                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Quick visual summary
- Clear health indicator
- Highlights value delivered
- No action needed if healthy

#### What Dev DOESN'T Have To Do

- Read through retrospections
- Calculate metrics manually
- Dig into details unless curious

---

### Journey 6: Alignment Correction

**Goal:** Redirect the system when it's learning the wrong lessons.

**Duration:** 5-10 minutes

#### Scene

Dev notices Claude is optimizing for the wrong thing. Maybe it's focused on token efficiency when correctness matters more.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "**Alignment Alert**                                    │
│                                                                  │
│  I've noticed my recent learnings might be drifting from         │
│  your stated goals.                                              │
│                                                                  │
│  Your intent says: 'Correctness first'                           │
│                                                                  │
│  But my recent learnings focus on:                               │
│  - 'Reduce token usage' (mentioned 6 times)                      │
│  - 'Faster completion' (mentioned 4 times)                       │
│  - 'Correctness/testing' (mentioned 1 time)                      │
│                                                                  │
│  This could mean:                                                │
│  1. Recent sessions were legitimately token-constrained          │
│  2. I'm optimizing for the wrong thing                           │
│                                                                  │
│  What should I do?                                               │
│                                                                  │
│  [A] This is fine - efficiency matters now, update my goals      │
│  [B] This is drift - refocus on correctness                      │
│  [C] Let me explain the context..."                              │
│                                                                  │
│  Dev: "B - we had a crunch but we're past it. Back to quality."  │
│                                                                  │
│  Claude: "Understood. I'll weight correctness-related            │
│  learnings higher going forward. I've also noted that            │
│  'token efficiency' learnings from Jan 10-15 were                │
│  context-specific and shouldn't become permanent rules."         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- System self-identifies drift
- Human provides context
- Course correction is instant
- Drift doesn't become permanent

#### What Dev DOESN'T Have To Do

- Monitor every retrospection
- Notice the drift themselves
- Manually edit learning files

---

### Journey 7: Creating a New Skill

**Goal:** Turn a recurring multi-step pattern into a reusable skill.

**Duration:** 5 minutes

#### Scene

System has noticed dev does the same complex workflow repeatedly. It suggests creating a skill.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Claude: "I've noticed a pattern across 5 recent sessions.       │
│                                                                  │
│  **Pattern: Debug Workflow**                                     │
│                                                                  │
│  When debugging, you consistently:                               │
│  1. Check the error message                                      │
│  2. Find the relevant file                                       │
│  3. Look at recent changes (git diff)                            │
│  4. Check test coverage for that area                            │
│  5. Form hypothesis and test                                     │
│                                                                  │
│  This is more than a simple rule—it's a multi-step process.      │
│                                                                  │
│  Would you like me to create a 'debug' skill that guides         │
│  this workflow? You could invoke it with '/debug'.               │
│                                                                  │
│  [Create Skill] [Not Now] [Never for This Pattern]"              │
│                                                                  │
│  Dev: [clicks Create Skill]                                      │
│                                                                  │
│  Claude: "Created .claude/skills/debug/SKILL.md                  │
│                                                                  │
│  Now when you say 'help me debug this' or '/debug',              │
│  I'll follow this workflow. You can customize the skill          │
│  file anytime."                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Complex pattern becomes one-click workflow
- Skill is customizable
- Dev's expertise is encoded

#### What Dev DOESN'T Have To Do

- Notice they have a consistent pattern
- Write the skill from scratch
- Figure out the skill format

---

### Journey 8: Understanding Why

**Goal:** Trace back why a rule or behavior exists.

**Duration:** 1-2 minutes

#### Scene

Dev encounters a rule they don't remember creating. Or a new team member asks why Claude behaves a certain way.

#### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Dev: "Why do you always remind me about tests before commit?"   │
│                                                                  │
│  Claude: "That comes from a rule created on Jan 12.              │
│                                                                  │
│  **Origin Story:**                                               │
│                                                                  │
│  This rule exists because 'forgetting to run tests' appeared     │
│  as a recurring issue in 4 sessions between Jan 5-12:            │
│                                                                  │
│  - Jan 5: CI failed after push, 20 min wasted                    │
│  - Jan 8: Same issue, tests would have caught bug                │
│  - Jan 10: Pushed broken code to PR                              │
│  - Jan 12: You said 'I keep doing this'                          │
│                                                                  │
│  On Jan 12, I suggested creating this rule and you approved.     │
│                                                                  │
│  Since then, the rule has been applied 12 times and              │
│  prevented an estimated 4 CI failures.                           │
│                                                                  │
│  Want to modify or remove this rule?"                            │
│                                                                  │
│  Dev: "No, keep it. Just wanted to know why."                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Outcome

- Full provenance available
- Shows value delivered
- Easy to modify if needed

#### What Dev DOESN'T Have To Do

- Search through files
- Remember when/why things were created
- Guess at the reasoning

---

## Experience Principles

### 1. Invisible When Working

During active coding, the learning system is silent. No popups, no interruptions, no "did you know" tooltips. Work flows normally.

### 2. Gentle at Transitions

Reflection prompts appear only at natural breakpoints:
- End of session
- Before starting new task
- After significant milestone

Never mid-thought.

### 3. Evidence-Based Suggestions

Every suggestion comes with evidence:
- "This appeared in N sessions"
- "Here are the specific examples"
- "This correlates with X% success rate"

No vague recommendations.

### 4. One-Click Actions

Common responses are single clicks:
- [Approve] [Dismiss] [Later]
- [Yes] [No] [Skip]

Typing is optional, never required.

### 5. Graceful Degradation

System works at every engagement level:
- **Zero engagement:** System still learns from self-reflection
- **Minimal engagement:** Occasional yes/no feedback
- **Full engagement:** Intent file, regular dashboard checks, rule customization

Each level provides value.

---

## Information Architecture

### What Dev Sees (Progressive Disclosure)

```
Level 0: Nothing (system runs silently)
    │
    ▼
Level 1: Alerts only (threshold breaches)
    │
    ▼
Level 2: Dashboard summary (weekly health)
    │
    ▼
Level 3: Detailed retrospections (on demand)
    │
    ▼
Level 4: Raw data (for debugging)
```

### Where Things Live

```
For Humans:
├── /dashboard         → Visual health summary
├── /retrospect        → Trigger reflection
├── /meta-retrospect   → Batch analysis
└── "Why do you..."    → Provenance queries

For Files:
├── .claude/intent.yaml           → Human-defined goals (edit directly)
├── .claude/rules/                → Human-approved rules (edit if needed)
└── .claude/skills/               → Human-approved skills (edit if needed)

System Internals (rarely need to touch):
└── .claude/cache/retrospections/ → Learning data
```

---

## Success Metrics

### For Individual Developers

| What They Feel | How We Measure |
|----------------|----------------|
| "Claude stops repeating mistakes" | Recurring issue rate <20% |
| "I spend less time re-explaining" | Session setup time decreases |
| "Claude remembers what works" | Learning application rate >60% |
| "The system doesn't annoy me" | Alert frequency <2/week |

### For the System

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| Reflection completion rate | >70% | Are devs engaging? |
| Recommendation acceptance rate | >50% | Are suggestions useful? |
| Rule effectiveness correlation | >0.3 | Do rules actually help? |
| Drift detection accuracy | >80% | Can we catch misalignment? |

---

## Constraints

### What This System Is NOT

1. **Not a keylogger.** We don't record everything. Claude reflects on its own work.

2. **Not automatic.** Humans approve every permanent change. No auto-created rules.

3. **Not prescriptive.** System suggests, human decides. Always.

4. **Not invasive.** Zero overhead during active work. Reflection is optional.

5. **Not a replacement for good practices.** This helps Claude learn YOUR practices, not impose its own.

### Technical Boundaries

- **Local only.** No external services required.
- **File-based.** Human-readable, git-trackable.
- **Lightweight.** No database servers, no background processes.

---

## Rollout Phases

### Phase 1: Foundation

**What ships:**
- `/retrospect` command for end-of-session reflection
- Structured storage of retrospections
- Basic outcome tracking (success/partial/failed)

**User value:**
- Sessions have memory
- "What worked" is captured automatically

### Phase 2: Intelligence

**What ships:**
- Meta-retrospection (batch analysis)
- Recurring issue detection
- Rule/skill suggestions

**User value:**
- Patterns surface automatically
- One-click rule creation

### Phase 3: Alignment

**What ships:**
- Intent file and goal-setting flow
- Drift detection and alerts
- Dashboard with health metrics

**User value:**
- System stays aligned with human goals
- Visibility into learning health

### Phase 4: Polish

**What ships:**
- Provenance queries ("why does this rule exist?")
- Automatic trigger options
- Team sharing capabilities

**User value:**
- Full transparency
- Hands-off operation
- Knowledge compounds across team

---

## Open Questions

1. **How often should we prompt for reflection?**
   - Every session? Long sessions only? User preference?

2. **What's the right alert threshold?**
   - Too sensitive = annoying. Too lenient = misses issues.

3. **Should rules expire?**
   - If a rule hasn't been relevant in 30 days, should it auto-disable?

4. **How do we handle conflicting learnings?**
   - Session A says "approach X works." Session B says "approach X failed."

5. **Multi-project learning?**
   - Should learnings from Project A inform Project B? When?

---

## Appendix: Interaction Summary

| Touchpoint | Frequency | Duration | Human Effort |
|------------|-----------|----------|--------------|
| Initial setup | Once | 15-30 min | Guided conversation |
| End-of-session reflection | Per session | 30-60 sec | One click + optional feedback |
| Alert response | ~2/week | 2-5 min | Review + one click |
| Dashboard check | Weekly | 2-3 min | Glance |
| Alignment correction | Rare | 5-10 min | Choose option + optional context |
| **Total weekly** | | | **~15-20 minutes** |

Compare to: Manually tracking learnings, noticing patterns, writing rules (~2-3 hours/week)

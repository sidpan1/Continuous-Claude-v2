# Meta-Retrospection System: Implementation Specification

## Overview

This document describes how to integrate the three-workspace meta-retrospection architecture with the **existing** Continuous-Claude-v2 infrastructure. The system leverages existing hooks, skills, scripts, and ledger patterns rather than building from scratch.

## Existing Infrastructure Inventory

Before designing integration, we assessed what already exists:

| Category | Count | Key Items |
|----------|-------|-----------|
| **Skills** | 34 | `compound-learnings`, `braintrust-analyze`, `recall-reasoning` |
| **Agents** | 14 | `braintrust-analyst`, `session-analyst`, `plan-agent` |
| **Hooks** | 9 | SessionStart, SessionEnd, PostToolUse, PreCompact, etc. |
| **Plugins** | 1 | Braintrust tracing (full session observability) |
| **Scripts** | 17 | `braintrust_analyze.py`, `artifact_index.py`, etc. |
| **Ledgers** | Active | `thoughts/ledgers/CONTINUITY_CLAUDE-*.md` |

## Three-Workspace Architecture

```
Continuous-Claude-v2/                    # Root repository
├── CLAUDE.md                            # Root guide (add workspace docs)
├── .claude/                             # EXISTING infrastructure
│   ├── skills/                          # 34 existing skills
│   ├── hooks/                           # 9 existing hooks
│   ├── agents/                          # 14 existing agents
│   ├── plugins/braintrust-tracing/      # Session observability
│   └── settings.json                    # Hook registration
│
├── scripts/                             # EXISTING script patterns
│   ├── braintrust_analyze.py            # Session analysis (55KB)
│   └── ...                              # 17 scripts total
│
├── worker/                              # NEW: Worker workspace
│   ├── CLAUDE.md                        # Worker-specific instructions
│   └── .claude/
│       └── cache/sessions/              # Session logs for retrospector
│
├── retrospective/                       # NEW: Retrospector workspace
│   ├── CLAUDE.md                        # Retrospector instructions
│   ├── .claude/                         # Minimal config
│   └── retrospections/                  # Per-session JSON outputs
│
└── meta-retrospective/                  # NEW: Meta-retrospector workspace
    ├── CLAUDE.md                        # Meta-retrospector instructions
    ├── .claude/                         # Minimal config
    ├── human-policy.yaml                # Human intent & thresholds
    ├── dashboard.md                     # System health summary
    └── analysis/                        # Batch analysis outputs
```

## Integration with Existing Components

### 1. Leveraging Existing Hooks

The existing hook system provides session lifecycle management:

| Existing Hook | Integration Point |
|---------------|-------------------|
| **SessionStart** | Load prior learnings from retrospections |
| **SessionEnd** | Trigger session logging for retrospector |
| **PreCompact** | Auto-generate handoff (already exists) |
| **PostToolUse** | Track file edits and test results (already exists) |

**New hooks to add:**

```json
// Add to .claude/settings.json
{
  "hooks": {
    "SessionEnd": [
      // Existing hooks...
      {
        "hooks": [{
          "type": "command",
          "command": "$HOME/.claude/hooks/session-log-for-retrospector.sh"
        }]
      }
    ]
  }
}
```

### 2. Leveraging Existing Skills

| Existing Skill | How It Helps |
|----------------|--------------|
| **braintrust-analyze** | Already analyzes sessions, extracts learnings |
| **compound-learnings** | Transforms learnings into permanent capabilities |
| **recall-reasoning** | Searches past decisions and approaches |
| **continuity_ledger** | Preserves state across `/clear` |

**New skills to add:**

| New Skill | Location | Purpose |
|-----------|----------|---------|
| `/retrospect` | `retrospective/.claude/skills/` | Analyze specific worker session |
| `/meta-retrospect` | `meta-retrospective/.claude/skills/` | Analyze batch of retrospections |

### 3. Leveraging Existing Scripts

The `braintrust_analyze.py` script (55KB) already provides:
- Session replay and analysis
- Loop detection
- Token trends
- Learning extraction

**Integration approach:** Create thin wrapper scripts that:
1. Call `braintrust_analyze.py` for raw session data
2. Transform output into retrospection JSON schema
3. Write to `retrospective/retrospections/`

```python
# scripts/retrospect.py - New script
"""
DESCRIPTION: Retrospect on a worker session
USAGE: uv run python -m runtime.harness scripts/retrospect.py --session-id <id>
"""

import subprocess
import json
from pathlib import Path

async def main():
    args = parse_args()

    # Use existing braintrust_analyze for session data
    result = subprocess.run([
        "uv", "run", "python", "-m", "runtime.harness",
        "scripts/braintrust_analyze.py",
        "--session", args.session_id,
        "--output-json"
    ], capture_output=True, text=True)

    session_data = json.loads(result.stdout)

    # Transform to retrospection schema
    retrospection = transform_to_retrospection(session_data)

    # Write to retrospections directory
    output_path = Path(f"retrospective/retrospections/{args.session_id}.json")
    output_path.write_text(json.dumps(retrospection, indent=2))
```

### 4. Leveraging Existing Ledgers

Continuity ledgers survive `/clear` and preserve session state. The meta-retrospection system extends this pattern:

| Existing Pattern | Extended Usage |
|------------------|----------------|
| `thoughts/ledgers/CONTINUITY_CLAUDE-*.md` | Session-to-session state |
| `thoughts/shared/handoffs/` | Cross-session context |
| **NEW:** `retrospective/retrospections/*.json` | Structured learning extraction |
| **NEW:** `meta-retrospective/analysis/*.json` | Trend analysis |

## Running Each Layer

### Worker Session

```bash
cd Continuous-Claude-v2
claude worker/
```

**What the worker CLAUDE.md should contain:**
- Focus on task execution only
- No awareness of retrospection (separation of concerns)
- SessionEnd hook writes session metadata to `worker/.claude/cache/sessions/`

**Session log format** (written by hook):
```json
{
  "session_id": "work-2025-12-31-abc123",
  "started_at": "2025-12-31T10:00:00Z",
  "ended_at": "2025-12-31T10:30:00Z",
  "task_description": "Fix authentication bug",
  "files_modified": ["src/auth/login.ts"],
  "test_results": {"passed": 15, "failed": 0},
  "outcome": "success",
  "braintrust_trace_id": "trace-xyz"
}
```

### Retrospector Session

```bash
cd Continuous-Claude-v2
claude retrospective/ --add-dir worker/
```

**What the retrospective CLAUDE.md should contain:**
- Session ID is REQUIRED (`/retrospect <session-id>`)
- Reads from `worker/.claude/cache/sessions/`
- Writes to `retrospections/<session-id>.json`
- Can also query Braintrust via existing `braintrust_analyze.py`

**Key commands:**
```bash
# Inside retrospective session:
/retrospect work-2025-12-31-abc123    # Analyze specific session
/retrospect --latest                   # Analyze most recent
/retrospect --list                     # List available sessions
```

### Meta-Retrospector Session

```bash
cd Continuous-Claude-v2
claude meta-retrospective/ --add-dir retrospective/ --add-dir worker/
```

**What the meta-retrospective CLAUDE.md should contain:**
- Analyzes batches of retrospections
- Reads from `retrospective/retrospections/*.json`
- Reads policy from `human-policy.yaml`
- Writes to `analysis/<batch-id>.json` and `dashboard.md`

**Key commands:**
```bash
# Inside meta-retrospective session:
/meta-retrospect                       # Analyze all
/meta-retrospect --last 10             # Last 10 sessions
/meta-retrospect --since 2025-12-01    # Since date
```

## Data Schemas

### Retrospection Output

```json
{
  "session_id": "work-2025-12-31-abc123",
  "timestamp": "2025-12-31T11:00:00Z",
  "intent": "Fix authentication bug in login flow",
  "outcome": "success",
  "learnings": [
    {
      "id": "learn-001",
      "category": "implementation",
      "insight": "JWT validation should check expiry before signature",
      "confidence": 0.9
    }
  ],
  "failures": [],
  "learnings_applied": ["learn-prev-042"],
  "braintrust_trace_id": "trace-xyz"
}
```

### Meta-Retrospection Output

```json
{
  "batch_id": "meta-2025-12-31-001",
  "timestamp": "2025-12-31T12:00:00Z",
  "sessions_analyzed": ["work-2025-12-29-xxx", "work-2025-12-30-yyy"],
  "metrics": {
    "success_rate": 0.85,
    "success_trend": "improving",
    "learning_application_rate": 0.72,
    "recurring_issue_rate": 0.15
  },
  "recurring_issues": [
    {
      "mode": "implementation/logic_error",
      "count": 3,
      "sessions": ["work-2025-12-29-xxx", "work-2025-12-30-yyy"],
      "suggested_action": "Add property-based testing"
    }
  ],
  "drift": {
    "score": 0.2,
    "interpretation": "aligned"
  },
  "recommendations": ["Add pre-implementation checklist"],
  "alerts": []
}
```

### Human Policy

```yaml
# meta-retrospective/human-policy.yaml
version: "1.0"

intent:
  primary_goals:
    - "Produce correct code that passes tests"
    - "Learn transferable patterns"
    - "Reduce recurring failures"

thresholds:
  alert_on_drift_score: 0.3
  alert_on_recurring_issues: 3
  min_learning_application_rate: 0.5

automation:
  meta_retrospect_after_n_sessions: 5
```

## Implementation Phases

### Phase 1: Create Workspace Directories

Create the three workspaces with CLAUDE.md files:

```bash
mkdir -p worker/.claude/cache/sessions
mkdir -p retrospective/.claude retrospective/retrospections
mkdir -p meta-retrospective/.claude meta-retrospective/analysis
```

Each CLAUDE.md should:
1. Explain the workspace's role
2. Define available commands
3. Specify input/output locations
4. Reference integration with existing infrastructure

### Phase 2: Add Session Logging Hook

Extend existing hooks to write session metadata:

```typescript
// .claude/hooks/src/session-log-for-retrospector.ts
import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

interface SessionLog {
  session_id: string;
  started_at: string;
  ended_at: string;
  task_description: string;
  files_modified: string[];
  outcome: 'success' | 'partial' | 'failure';
}

async function main() {
  const input = JSON.parse(await readStdin());

  const sessionLog: SessionLog = {
    session_id: `work-${new Date().toISOString().slice(0,10)}-${randomId()}`,
    started_at: input.started_at,
    ended_at: new Date().toISOString(),
    task_description: extractTaskDescription(input.transcript_path),
    files_modified: getModifiedFiles(),
    outcome: determineOutcome(input)
  };

  const outputDir = join(process.cwd(), 'worker/.claude/cache/sessions');
  mkdirSync(outputDir, { recursive: true });
  writeFileSync(
    join(outputDir, `${sessionLog.session_id}.json`),
    JSON.stringify(sessionLog, indent=2)
  );
}
```

### Phase 3: Create /retrospect Skill

Add skill to `retrospective/.claude/skills/retrospect/SKILL.md`:

```markdown
---
description: Analyze a worker session and extract learnings
---

# /retrospect

Analyze a completed worker session.

## Usage

```bash
/retrospect <session-id>    # Analyze specific session
/retrospect --latest        # Analyze most recent
/retrospect --list          # Show available sessions
```

## Process

1. Load session from `worker/.claude/cache/sessions/<id>.json`
2. Optionally query Braintrust for detailed trace
3. Assess outcome (success/partial/failure)
4. Extract learnings with categories
5. Identify failures with root cause
6. Write to `retrospections/<session-id>.json`
```

### Phase 4: Create /meta-retrospect Skill

Add skill to `meta-retrospective/.claude/skills/meta-retrospect/SKILL.md`:

```markdown
---
description: Analyze patterns across multiple retrospections
---

# /meta-retrospect

Analyze batch of retrospections to detect trends.

## Usage

```bash
/meta-retrospect             # Analyze all
/meta-retrospect --last 10   # Last 10 sessions
```

## Process

1. Load retrospections from `retrospective/retrospections/*.json`
2. Load policy from `human-policy.yaml`
3. Calculate metrics (success rate, trends)
4. Detect recurring issues (3+ occurrences)
5. Calculate drift score
6. Generate recommendations
7. Check alert thresholds
8. Write to `analysis/<batch-id>.json`
9. Update `dashboard.md`
```

### Phase 5: Integrate with Existing Skills

Connect to existing infrastructure:

| Existing Skill | Integration |
|----------------|-------------|
| `braintrust-analyze` | Call from /retrospect for detailed session data |
| `compound-learnings` | Run after /meta-retrospect to persist patterns |
| `recall-reasoning` | Feed retrospection learnings into search index |

## Visibility Matrix

| Layer | worker/ | retrospective/ | meta-retrospective/ |
|-------|---------|----------------|---------------------|
| Worker | ✅ Read/Write | ❌ | ❌ |
| Retrospector | ✅ Read | ✅ Read/Write | ❌ |
| Meta-Retrospector | ✅ Read | ✅ Read | ✅ Read/Write |

## Key Integration Principles

1. **Leverage existing hooks** — Don't rewrite SessionEnd, extend it
2. **Leverage existing scripts** — Call `braintrust_analyze.py` for session data
3. **Leverage existing skills** — Use `compound-learnings` to persist insights
4. **Leverage existing ledgers** — Retrospections complement, not replace, ledgers
5. **Session ID required** — Retrospector needs explicit session ID (no guessing)
6. **`--add-dir` for visibility** — Higher layers see lower layers via this flag
7. **JSON as interface** — Layers communicate through structured files
8. **Claude Code orchestrates** — All thinking happens in Claude Code sessions

## Files to Create

| File | Purpose |
|------|---------|
| `worker/CLAUDE.md` | Worker workspace instructions |
| `retrospective/CLAUDE.md` | Retrospector instructions with /retrospect skill |
| `meta-retrospective/CLAUDE.md` | Meta-retrospector instructions with /meta-retrospect skill |
| `meta-retrospective/human-policy.yaml` | Human intent and thresholds |
| `meta-retrospective/dashboard.md` | System health summary (updated by /meta-retrospect) |
| `.claude/hooks/src/session-log-for-retrospector.ts` | Session logging hook |

## Files to Modify

| File | Change |
|------|--------|
| `CLAUDE.md` (root) | Add section on three-workspace architecture |
| `.claude/settings.json` | Register new SessionEnd hook |

## Summary

The meta-retrospection system integrates with Continuous-Claude-v2 by:
1. Using **existing hooks** for session lifecycle
2. Using **existing scripts** (`braintrust_analyze.py`) for session data
3. Using **existing skills** (`compound-learnings`) to persist learnings
4. Adding **three workspaces** with focused CLAUDE.md files
5. Using **`--add-dir`** for layer visibility
6. Requiring **explicit session ID** for retrospection

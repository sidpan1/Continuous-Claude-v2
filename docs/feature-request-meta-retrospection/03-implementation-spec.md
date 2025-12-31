# Meta-Retrospection System: Implementation Specification

## Overview

Technical architecture, data schemas, and code patterns for the meta-retrospection system.

## System Architecture

### Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                    CLAUDE CODE SESSION                           │
│                                                                  │
│  1. SessionStart hook loads prior learnings                      │
│  2. Worker executes task                                         │
│  3. Tests run                                                    │
│  4. /retrospect (same session) → JSON                            │
│                                                                  │
│  Output: .claude/cache/retrospections/<session>.json             │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    META-RETROSPECTOR                             │
│                    (every 5-10 sessions)                         │
│                                                                  │
│  Input: Batch of retrospection JSONs                             │
│  Process: Trend detection, drift scoring, pattern matching       │
│  Output: .claude/cache/meta-retrospections/<batch>.json          │
│                                                                  │
│  Triggers: Manual /meta-retrospect OR automatic after N sessions │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    HUMAN REVIEW                                  │
│                                                                  │
│  Reads: Dashboard report (markdown)                              │
│  Updates: .claude/meta/human-policy.yaml                         │
│  Approves: Rule updates, threshold changes                       │
└──────────────────────────────────────────────────────────────────┘
```

## File Structure

```
.claude/
├── skills/
│   ├── retrospect/
│   │   └── SKILL.md              # /retrospect command
│   └── meta-retrospect/
│       └── SKILL.md              # /meta-retrospect command
├── meta/
│   ├── human-policy.yaml         # Human-defined intent & thresholds
│   └── retrospector-config.json  # Meta-tuned settings
├── cache/
│   ├── retrospections/
│   │   └── <session_id>.json     # Individual retrospection outputs
│   ├── meta-retrospections/
│   │   └── <batch_id>.json       # Batch analysis outputs
│   └── experiments/
│       └── traces.db             # Local SQLite tracing

scripts/
├── retrospect.py                 # Retrospection logic
├── meta_retrospect.py            # Meta-retrospection logic
├── human_dashboard.py            # Generate reports
└── trace_decision.py             # Audit trail viewer

src/meta/
├── schemas.py                    # Pydantic models
├── local_tracing.py              # SQLite tracing (Braintrust alternative)
├── local_embeddings.py           # Drift detection embeddings
└── trend_detection.py            # Statistical analysis
```

## Data Schemas

### Retrospection Output

```python
# src/meta/schemas.py

from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from enum import Enum

class Outcome(str, Enum):
    SUCCESS = "success"
    PARTIAL = "partial"
    FAILURE = "failure"

class LearningCategory(str, Enum):
    UNDERSTANDING = "understanding"  # Misread requirements, wrong scope
    IMPLEMENTATION = "implementation"  # Syntax, types, logic errors
    PROCESS = "process"  # Premature commits, incomplete testing

class Learning(BaseModel):
    id: str  # UUID
    category: LearningCategory
    insight: str  # Specific, actionable lesson
    confidence: float  # 0.0-1.0
    applied: bool = False  # Updated in subsequent sessions

class Failure(BaseModel):
    mode: str  # From taxonomy (e.g., "misread_requirements")
    description: str
    root_cause: str
    prevention: str  # What would prevent this next time

class Retrospection(BaseModel):
    session_id: str
    task_id: str
    timestamp: datetime
    intent: str  # What was the goal?
    outcome: Outcome
    learnings: list[Learning]
    failures: list[Failure]
    learnings_applied: list[str]  # IDs of prior learnings used
    time_spent_minutes: int

    class Config:
        json_schema_extra = {
            "example": {
                "session_id": "abc-123",
                "task_id": "django__django-15498",
                "timestamp": "2025-01-15T10:30:00Z",
                "intent": "Fix QuerySet filter bug",
                "outcome": "success",
                "learnings": [{
                    "id": "learn-001",
                    "category": "implementation",
                    "insight": "Django ORM requires explicit Q objects for OR conditions",
                    "confidence": 0.9,
                    "applied": False
                }],
                "failures": [],
                "learnings_applied": ["learn-prev-042"],
                "time_spent_minutes": 25
            }
        }
```

### Meta-Retrospection Output

```python
class TrendDirection(str, Enum):
    IMPROVING = "improving"
    STABLE = "stable"
    DEGRADING = "degrading"

class RecurringIssue(BaseModel):
    failure_mode: str
    count: int
    sessions: list[str]  # Session IDs where this occurred
    suggested_fix: str

class MetaRetrospection(BaseModel):
    batch_id: str
    timestamp: datetime
    sessions_analyzed: list[str]

    # Trend analysis
    success_rate: float
    success_trend: TrendDirection

    # Issue detection
    recurring_issues: list[RecurringIssue]
    recurring_issue_rate: float  # % of failures that are recurring

    # Learning effectiveness
    learning_application_rate: float
    learnings_total: int
    learnings_applied: int

    # Drift detection
    drift_score: float  # 0.0-1.0
    drift_details: str  # Explanation

    # Recommendations
    recommendations: list[str]

    # Meta
    policy_version: str  # Which human-policy.yaml was active
```

### Human Policy Configuration

```yaml
# .claude/meta/human-policy.yaml

version: "1.0"

intent:
  primary_goals:
    - "Produce correct code that passes tests"
    - "Learn transferable patterns"
    - "Reduce recurring failures"

  constraints:
    - "Prefer simple solutions over clever ones"
    - "Test before marking complete"
    - "Don't introduce regressions"

thresholds:
  alert_on_drift_score: 0.3
  alert_on_recurring_issues: 3
  min_learning_application_rate: 0.5
  max_recurring_issue_rate: 0.25

automation:
  meta_retrospect_every_n_sessions: 5
  auto_apply_high_confidence_learnings: true
  high_confidence_threshold: 0.8

review:
  frequency: "weekly"
  sample_rate: 0.05  # Spot-check 5% of sessions
```

## Core Components

### Local Tracing (SQLite)

Replaces Braintrust for experiment logging:

```python
# src/meta/local_tracing.py

import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import Optional

class LocalTracer:
    """Zero-cost tracing using SQLite."""

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

                CREATE TABLE IF NOT EXISTS retrospections (
                    session_id TEXT PRIMARY KEY,
                    retrospection_json TEXT,
                    timestamp TEXT,
                    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
                );

                CREATE INDEX IF NOT EXISTS idx_sessions_experiment
                ON sessions(experiment_id);

                CREATE INDEX IF NOT EXISTS idx_sessions_phase
                ON sessions(phase);
            """)

    def start_session(self, experiment_id: str, phase: int, task_id: str) -> str:
        session_id = f"{experiment_id}-p{phase}-{task_id}-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO sessions (session_id, experiment_id, phase, task_id, started_at)
                VALUES (?, ?, ?, ?, ?)
            """, (session_id, experiment_id, phase, task_id, datetime.now().isoformat()))
        return session_id

    def end_session(self, session_id: str, success: bool, metadata: dict = None):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                UPDATE sessions
                SET completed_at = ?, success = ?, metadata = ?
                WHERE session_id = ?
            """, (datetime.now().isoformat(), int(success), json.dumps(metadata or {}), session_id))

    def save_retrospection(self, session_id: str, retrospection: dict):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO retrospections (session_id, retrospection_json, timestamp)
                VALUES (?, ?, ?)
            """, (session_id, json.dumps(retrospection), datetime.now().isoformat()))

    def get_phase_stats(self, experiment_id: str, phase: int) -> dict:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute("""
                SELECT
                    COUNT(*) as total,
                    SUM(success) as successes
                FROM sessions
                WHERE experiment_id = ? AND phase = ?
            """, (experiment_id, phase)).fetchone()
            return {
                'total': row[0],
                'successes': row[1] or 0,
                'success_rate': (row[1] or 0) / row[0] if row[0] else 0
            }

    def get_retrospections_for_batch(self, limit: int = 10) -> list[dict]:
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute("""
                SELECT retrospection_json FROM retrospections
                ORDER BY timestamp DESC
                LIMIT ?
            """, (limit,)).fetchall()
            return [json.loads(row[0]) for row in rows]
```

### Local Embeddings (Drift Detection)

```python
# src/meta/local_embeddings.py

import numpy as np
from typing import Optional

class LocalEmbedder:
    """
    Local embeddings for drift detection.
    Uses sentence-transformers (downloads once, runs locally).
    """

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        try:
            from sentence_transformers import SentenceTransformer
            self.model = SentenceTransformer(model_name)
            self._available = True
        except ImportError:
            self._available = False
            self.model = None

    @property
    def available(self) -> bool:
        return self._available

    def embed(self, texts: list[str]) -> np.ndarray:
        if not self._available:
            raise RuntimeError("sentence-transformers not installed")
        return self.model.encode(texts, normalize_embeddings=True)

    def similarity(self, text1: str, text2: str) -> float:
        embeddings = self.embed([text1, text2])
        return float(np.dot(embeddings[0], embeddings[1]))

    def drift_score(self, intent: str, learnings: list[str]) -> float:
        """
        Calculate how far learnings have drifted from intent.
        Returns 0.0 (perfectly aligned) to 1.0 (completely drifted).
        """
        if not learnings:
            return 0.0

        if not self._available:
            # Fallback: keyword overlap
            return self._keyword_drift(intent, learnings)

        intent_emb = self.embed([intent])[0]
        learning_embs = self.embed(learnings)

        similarities = [float(np.dot(intent_emb, l_emb)) for l_emb in learning_embs]
        avg_similarity = np.mean(similarities)

        # Convert similarity (0-1) to drift (0-1)
        return max(0.0, min(1.0, 1.0 - avg_similarity))

    def _keyword_drift(self, intent: str, learnings: list[str]) -> float:
        """Fallback drift detection using keyword overlap."""
        intent_words = set(intent.lower().split())
        learning_words = set()
        for learning in learnings:
            learning_words.update(learning.lower().split())

        if not intent_words:
            return 0.0

        overlap = len(intent_words & learning_words)
        return 1.0 - (overlap / len(intent_words))
```

### Trend Detection

```python
# src/meta/trend_detection.py

from collections import Counter
from typing import Optional
from .schemas import Retrospection, TrendDirection, RecurringIssue

def detect_trend(success_rates: list[float], window: int = 3) -> TrendDirection:
    """
    Detect if success rate is improving, stable, or degrading.
    Uses simple moving average comparison.
    """
    if len(success_rates) < window * 2:
        return TrendDirection.STABLE

    early = sum(success_rates[:window]) / window
    late = sum(success_rates[-window:]) / window

    diff = late - early
    if diff > 0.1:
        return TrendDirection.IMPROVING
    elif diff < -0.1:
        return TrendDirection.DEGRADING
    else:
        return TrendDirection.STABLE

def find_recurring_issues(
    retrospections: list[Retrospection],
    threshold: int = 3
) -> list[RecurringIssue]:
    """
    Find failure modes that appear 3+ times.
    """
    mode_sessions: dict[str, list[str]] = {}

    for retro in retrospections:
        for failure in retro.failures:
            if failure.mode not in mode_sessions:
                mode_sessions[failure.mode] = []
            mode_sessions[failure.mode].append(retro.session_id)

    recurring = []
    for mode, sessions in mode_sessions.items():
        if len(sessions) >= threshold:
            recurring.append(RecurringIssue(
                failure_mode=mode,
                count=len(sessions),
                sessions=sessions,
                suggested_fix=f"Add check for {mode} before execution"
            ))

    return sorted(recurring, key=lambda x: x.count, reverse=True)

def calculate_application_rate(retrospections: list[Retrospection]) -> float:
    """
    What % of available learnings were actually applied?
    """
    total_available = 0
    total_applied = 0

    available_learnings = set()
    for retro in retrospections:
        # Count how many available learnings were applied
        applied = len([l for l in retro.learnings_applied if l in available_learnings])
        total_applied += applied
        total_available += len(available_learnings)

        # Add this session's learnings to available pool
        for learning in retro.learnings:
            available_learnings.add(learning.id)

    return total_applied / total_available if total_available else 0.0
```

## Failure Mode Taxonomy

Consistent categorization for all failures:

```python
# src/meta/failure_modes.py

FAILURE_TAXONOMY = {
    "understanding": {
        "misread_requirements": "Solved wrong problem",
        "missed_edge_case": "Didn't handle boundary condition",
        "wrong_scope": "Changed too much or too little",
    },
    "implementation": {
        "syntax_error": "Code doesn't parse",
        "type_error": "Type mismatch",
        "logic_error": "Code runs but wrong output",
        "import_error": "Missing or wrong imports",
    },
    "environment": {
        "test_flakiness": "Test passes/fails intermittently",
        "setup_failure": "Couldn't configure environment",
        "timeout": "Exceeded time limit",
    },
    "process": {
        "premature_commit": "Submitted before testing",
        "incomplete_fix": "Partial solution",
        "regression": "Fixed one thing, broke another",
    },
}

def classify_failure(description: str) -> str:
    """
    Auto-classify failure based on description.
    Returns failure mode key like 'logic_error'.
    """
    description_lower = description.lower()

    # Simple keyword matching
    if "syntax" in description_lower or "parse" in description_lower:
        return "syntax_error"
    if "type" in description_lower:
        return "type_error"
    if "import" in description_lower:
        return "import_error"
    if "timeout" in description_lower:
        return "timeout"
    if "flaky" in description_lower or "intermittent" in description_lower:
        return "test_flakiness"
    if "wrong" in description_lower and "output" in description_lower:
        return "logic_error"
    if "scope" in description_lower:
        return "wrong_scope"
    if "edge" in description_lower or "boundary" in description_lower:
        return "missed_edge_case"

    return "logic_error"  # Default
```

## Integration Points

### SessionStart Hook (Load Learnings)

```bash
# .claude/hooks/session-start-learnings.sh

#!/bin/bash
# Load recent learnings into session context

LEARNINGS_DIR=".claude/cache/retrospections"
if [ -d "$LEARNINGS_DIR" ]; then
    # Get last 5 retrospections
    RECENT=$(ls -t "$LEARNINGS_DIR"/*.json 2>/dev/null | head -5)
    if [ -n "$RECENT" ]; then
        echo "# Recent Learnings"
        for f in $RECENT; do
            jq -r '.learnings[] | "- [\(.category)] \(.insight)"' "$f" 2>/dev/null
        done
    fi
fi
```

### Retrospect Skill

```markdown
# .claude/skills/retrospect/SKILL.md
---
description: Analyze the current session and extract structured learnings
---

# Retrospect

Perform end-of-session retrospection to extract learnings.

## When to Use
- At the end of a task/session
- After fixing a bug
- After completing a feature
- When asked to "analyze this session" or "what did we learn"

## Process

1. **Summarize intent**: What was the goal?
2. **Assess outcome**: success | partial | failure
3. **Extract learnings**: What insights are transferable?
4. **Classify failures**: Use taxonomy (understanding/implementation/process)
5. **Output JSON**: Save to `.claude/cache/retrospections/`

## Output Format

```json
{
  "session_id": "<from context>",
  "task_id": "<if available>",
  "timestamp": "<ISO format>",
  "intent": "<goal statement>",
  "outcome": "success | partial | failure",
  "learnings": [{
    "id": "<uuid>",
    "category": "understanding | implementation | process",
    "insight": "<specific, actionable lesson>",
    "confidence": 0.8
  }],
  "failures": [{
    "mode": "<from taxonomy>",
    "description": "<what happened>",
    "root_cause": "<why>",
    "prevention": "<how to avoid>"
  }],
  "time_spent_minutes": 30
}
```

Save to: `.claude/cache/retrospections/<session_id>.json`
```

## Dependencies

**Required:**
- Python 3.11+
- Pydantic
- SQLite (built-in)

**Optional (for drift detection):**
```bash
pip install sentence-transformers
# or
uv add sentence-transformers
```

Model downloads once (~80MB), runs locally thereafter.

# Meta-Retrospection System: Experiment Design

## Purpose

Validate that the meta-retrospection system improves coding agent performance compared to baseline (no learning) and single-layer retrospection.

## Research Questions

1. **RQ1**: Does retrospection improve task success rate compared to no learning?
2. **RQ2**: Does meta-retrospection improve success rate beyond retrospection alone?
3. **RQ3**: Does the system reduce recurring failure modes over time?
4. **RQ4**: Does human policy tuning provide additional improvement?
5. **RQ5**: Do learnings transfer across different task types?

## Experimental Design

### Design Type: Within-Subjects Longitudinal

The same system progresses through conditions sequentially. Learnings accumulate over time, matching real-world usage.

```
Timeline:
├── Phase 0: Warmup (10 tasks, discarded)
├── Phase 1: Baseline (50 tasks, no learning)
├── Phase 2: Retrospection (50 tasks, +retrospect)
├── Phase 3: Meta-Retrospection (50 tasks, +meta every 5)
└── Phase 4: Human Policy (25 tasks, +policy tuning)
```

### Why Within-Subjects?

Between-subjects (parallel groups) would require:
- Multiple isolated agent instances
- No cross-contamination of learnings
- 2-3x larger sample sizes

Within-subjects matches the "compound learning" hypothesis we're testing.

## Variables

### Independent Variables

| Variable | Levels |
|----------|--------|
| Learning Condition | None, Retrospection, Meta-Retrospection, Human-Tuned |
| Task Type | Bug fix, Feature, Refactor |
| Task Difficulty | Easy, Medium, Hard |

### Dependent Variables

| Variable | Type | Measurement |
|----------|------|-------------|
| Success Rate | Binary | Task passes all tests |
| Time to Solution | Continuous | Minutes to completion |
| Recurring Issues | Count | Same failure mode 3+ times |
| Learning Application | Binary | Was prior learning used? |
| Drift Score | Continuous | 0.0-1.0 (from embeddings) |

### Control Variables

| Variable | Value |
|----------|-------|
| Model | Claude (via Claude Code) |
| Temperature | 0.0 |
| Timeout | 30 min per task |
| Repository state | Fresh clone per task |

## Task Selection

### Source: SWE-bench Lite

300 real GitHub issues from popular Python repos. We select 185 tasks stratified by type and difficulty:

```
Distribution:
├── Bug Fixes: 100 tasks (35 easy, 40 medium, 25 hard)
├── Features: 50 tasks (15 easy, 20 medium, 15 hard)
└── Refactors: 35 tasks (10 easy, 15 medium, 10 hard)
```

### Setup

```bash
pip install datasets
```

```python
from datasets import load_dataset
swebench = load_dataset('princeton-nlp/SWE-bench_Lite', split='test')
```

## Procedure

### Phase 0: Warmup (Discarded)

10 random tasks to verify infrastructure. Data not used in analysis.

### Phase 1: Baseline

**Purpose**: Measure unassisted performance.

Per task:
1. Clone fresh repository
2. Present issue to agent
3. Agent attempts solution (max 30 min, 5 attempts)
4. Run test suite
5. Record outcome
6. **No retrospection**

### Phase 2: Retrospection Only

**Purpose**: Measure single-session learning impact.

Per task:
1. Load learnings from prior retrospections
2. Present issue
3. Agent attempts solution
4. Run test suite
5. **Run /retrospect** → JSON output
6. Annotator reviews: "Was prior learning applied?"

### Phase 3: Meta-Retrospection Active

**Purpose**: Measure batch trend detection impact.

Structure:
- Tasks 1-5: Retrospection
- After task 5: Run /meta-retrospect
- Tasks 6-10: Retrospection (with any prompt adjustments)
- After task 10: Run /meta-retrospect
- Continue pattern...

**Key measurement**: Do recurring issues decrease after meta-retrospection?

### Phase 4: Human Policy Tuning

**Purpose**: Measure human-in-the-loop value.

1. Tasks 1-10: Run with existing policies
2. Human reviews dashboard (~15 min)
3. Human adjusts policy
4. Tasks 11-25: Run with new policies
5. Compare pre/post intervention

## Analysis Plan

### Primary Analysis: Success Rate by Condition

**Test**: Cochran's Q test (repeated measures on binary outcome)

**Follow-up**: Pairwise McNemar tests with Bonferroni correction

**Sample size**: n=50 per phase provides 80% power at α=0.05 for Cohen's h=0.3

### Secondary Analyses

#### 1. Recurring Issue Reduction

```python
def recurring_issue_rate(failures):
    mode_counts = Counter(f.mode for f in failures)
    recurring = sum(1 for f in failures if mode_counts[f.mode] >= 3)
    return recurring / len(failures) if failures else 0
```

**Expected**: 40% → 25% → 15% across phases

**Test**: Chi-square test for trend

#### 2. Learning Transfer

Compare success rate on task N+1 based on whether task N was same or different domain.

```python
within_domain = [success for (prev, curr) if prev.domain == curr.domain]
cross_domain = [success for (prev, curr) if prev.domain != curr.domain]
```

#### 3. Drift Validation

Correlate drift score with human judgment (1-5 scale).

**Threshold**: Spearman r > 0.6 indicates meaningful drift detection

## Expected Results

### Optimistic Scenario

| Phase | Success Rate | Recurring Issues |
|-------|--------------|------------------|
| Baseline | 20% | 40% |
| Retrospection | 35% | 25% |
| Meta-Retrospection | 45% | 12% |
| Human Policy | 52% | 8% |

### Conservative Scenario

| Phase | Success Rate | Recurring Issues |
|-------|--------------|------------------|
| Baseline | 18% | 42% |
| Retrospection | 24% | 35% |
| Meta-Retrospection | 30% | 25% |
| Human Policy | 33% | 20% |

### Null Scenario

All phases ~20% success rate, ~40% recurring issues, <20% learning application.

If null occurs, investigate:
- Are learnings being loaded into context?
- Are learnings specific enough to be actionable?
- Is context window sufficient?

## Threats to Validity

### Internal

| Threat | Mitigation |
|--------|------------|
| Order effects | Randomize within phases |
| Contamination | Fresh repo clone per task |
| Annotator bias | Blind annotation |
| Model drift | Fixed model version, temp=0 |

### External

| Threat | Mitigation |
|--------|------------|
| Task representativeness | Real GitHub issues (SWE-bench) |
| Model specificity | Document version; replicate later |
| Domain specificity | Multiple repos (Django, Flask, Pandas) |

## Cost Estimate

### Full Experiment (185 tasks)

| Component | Cost |
|-----------|------|
| Claude Code sessions | ~$50-100 |
| Local tracing | $0 |
| Local embeddings | $0 |
| **Total** | **~$50-100** |

### Minimal Experiment (45 tasks)

| Component | Cost |
|-----------|------|
| Claude Code (15 tasks × 3 phases) | ~$15-30 |
| Infrastructure | $0 |
| **Total** | **~$15-30** |

## Data Collection

### Storage Structure

```
.claude/cache/experiments/<experiment_id>/
├── config.json              # Experiment parameters
├── task_assignments.json    # Which tasks in which phase
├── attempts/
│   └── <task_id>.json       # Per-task data
├── retrospections/
│   └── <task_id>.json       # Retrospection outputs
├── meta_retrospections/
│   └── batch_<n>.json       # Meta outputs
└── analysis/
    └── final_report.md      # Results
```

### Per-Task Schema

```python
class TaskAttempt(BaseModel):
    task_id: str
    phase: int
    started_at: datetime
    completed_at: datetime
    success: bool
    attempts: int
    failure_mode: Optional[str]
    learnings_applied: list[str]
    drift_score: Optional[float]
```

## Timeline

### Setup (1 week)
- Finalize task selection
- Build logging infrastructure
- Test on 5 tasks
- Run warmup (Phase 0)

### Execution (2 weeks)
- Days 1-2: Phase 1 (50 tasks)
- Days 3-4: Phase 2 (50 tasks)
- Day 5: Analysis checkpoint
- Days 6-8: Phase 3 (50 tasks)
- Day 9: Human review
- Day 10: Phase 4 (25 tasks)

### Analysis (1 week)
- Days 1-2: Failure annotation
- Days 3-4: Statistical analysis
- Days 5-7: Report writing

## Deliverables

1. **Raw data**: All attempts, retrospections, meta-retrospections (anonymized)
2. **Analysis scripts**: Python notebooks reproducing all analyses
3. **Final report**: Executive summary + detailed results per RQ
4. **Learnings database**: Extracted learnings with effectiveness ratings

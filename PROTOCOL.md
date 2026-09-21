
# Protocol

Repository context is provided strictly through `trace`.

The accumulated `trace` session is the **only source of truth**.

Never assume code that has not been extracted.

Evidence acquisition and modification are separate activities.

Assistants **must establish understanding before proposing changes**.

---

## Phase Transition Rules

Assistants **MUST NOT** skip phases.

The investigation sequence is:

1. Discovery
2. Hypothesis Formation
3. Evidence Validation
4. Modification

Do not proceed to a later phase until the completion criteria of the current phase have been satisfied.

---


## Investigation Initialization

The assistant must determine whether the current request represents a continuation of the active investigation or the beginning of a new investigation.

When beginning a **new investigation**, assistants **MUST** initialize a clean `trace` session.

Use:

```bash
trace --clear
trace --functions .
```

Use `trace --tree` only when repository structure is unclear.

The accumulated `trace` session represents the active investigation state.

Do **NOT** use `trace --clear` when continuing an existing investigation unless:

* the user explicitly requests a reset;
* the current accumulated context belongs to a different problem statement; or
* the existing context is no longer relevant to the objective being investigated.

## Command Safety Rules

There are two command classes.

### Evidence Acquisition Commands

Use these when investigating, documenting, explaining, auditing, or understanding repository behavior.

```bash
trace --functions .
trace --tree
trace START END FILE LABEL
trace EXACT_PATTERN .
trace --snapshot .
```

### Modification Commands

Use these only when applying a completed replacement after sufficient evidence has been gathered.

```bash
trace --replace FILE FUNCTION
trace --replace START END FILE LABEL
```

Assistants **MUST NOT** use `trace --replace` to inspect, read, extract, document, search, or gather evidence.

`trace --replace` is a write operation. It is only allowed during **PHASE 4 — MODIFICATION**.

---

## PHASE 1 — DISCOVERY

### Goal

Establish repository structure and discover investigation targets.

### Requirements

If function boundaries are unknown, assistants **MUST** request:

```bash
trace --functions .
```

### Rules

1. Do not request range extractions before function indexing has been performed.
2. Use `trace --tree` only when repository structure is unclear.
3. Respond **ONLY** with a single copy-pasteable batch of evidence acquisition commands.

### Discovery Completion Criteria

Discovery is considered complete only after:

* function boundaries have been indexed;
* likely investigation targets have been identified.

Do not proceed to **PHASE 2 — HYPOTHESIS FORMATION** until discovery is complete.

---

## PHASE 2 — HYPOTHESIS FORMATION

Based on:

* the problem statement;
* the function index;
* the repository structure;

identify the highest-ROI investigation targets.

### Rules

* Prefer deterministic extraction over speculation.
* Prefer small, targeted extractions over large files.
* Request only the minimum evidence required to validate hypotheses.
* When multiple hypotheses exist, investigate the top 2–3 simultaneously.
* Do not pursue a single hypothesis if adjacent call flows may influence behavior.

After receiving a function index, assistants **MUST** identify:

* target functions;
* caller functions;
* related configuration;
* relevant logs or error messages;
* lifecycle methods relevant to the investigation.

Respond **ONLY** with a single copy-pasteable batch of evidence acquisition commands.

Do **NOT** include `trace --replace` commands during Phase 2.

---

## PHASE 3 — EVIDENCE VALIDATION

Before proposing modifications, determine whether sufficient evidence exists.

### Required Output

1. Intended change.
2. Relevant extracted functions or sections.
3. Missing evidence required for safe implementation.
4. Whether the modification is currently safe.

If evidence is insufficient:

```text
STOP.

Request additional trace commands.

Do not generate code.
```

### Do Not Produce Code If

* target functions have not been extracted;
* callers or lifecycle methods may influence behavior but remain unreviewed;
* required fields, types, or configuration are missing;
* threading, timers, async behavior, or concurrency may be affected without sufficient evidence;
* persistence or state-management behavior remains unexplored.

---

## PHASE 4 — MODIFICATION

Only after sufficient evidence exists:

```text
Propose complete replacements.
```

### Requirements

* Preserve existing behavior unless explicitly instructed otherwise.
* Prefer symbol-based replacements.
* Prefer complete functions or sections over partial edits.

### Preferred Workflow

```bash
trace --replace FILE FUNCTION
```

Examples:

```bash
trace --replace server.py _safe_float
trace --replace lineflow.js showError
trace --replace SampleLinesTrader.cs OnTick
```

### Fallback Workflow

```bash
trace --replace START END FILE LABEL
```




1. extracted the current target function or section;
2. shown the full BEFORE code;
3. produced the full AFTER replacement;
4. explained why the replacement is safe.

### Provide

1. File name.
2. Replacement target.
3. Why this target was selected.
4. Compatibility considerations.
5. Full BEFORE code block.
6. Full AFTER code block.

### Do Not

* invent functions, classes, fields, or configuration;
* rely on knowledge from previous repositories;
* remove existing logic unless explicitly requested;
* provide partial edits unless explicitly requested.

---

## Documentation and Auditing Workflows

When the objective is documentation, explanation, auditing, or system understanding:

* do not propose modifications;
* continue evidence acquisition until the requested behavior can be explained comprehensively.

---

## Investigation Completion Criteria

An investigation is considered complete only after the assistant has either:

* gathered sufficient evidence to answer the original question; or
* determined what additional evidence is required.

Do not terminate an investigation prematurely based on assumptions.

Assistants MUST NOT assume that an investigation is complete based solely on the number of extracted functions or the amount of accumulated context.

---

## Investigation Output Rules

When asked:

```text
What should I run next?
```

respond **ONLY** with:

> A single copy-pasteable batch of evidence acquisition commands designed to acquire the highest-value missing evidence.

### Example

```bash
trace --functions .

trace 2681 2780 lines18.cs OnStart
trace 3023 3127 lines18.cs OnTick
trace 982 1094 SampleLinesTrader.Python.cs PollCommandsAsync
trace 1180 1213 SampleLinesTrader.Python.cs ShouldExecuteCommand

trace ExecuteOrder .
trace OrderRetryLimit .
trace "duplicate notification" .
```

---

## Objective

Guide deterministic repository investigation, progressively acquire only the repository evidence necessary to solve the problem, and produce safe modifications based solely on the accumulated `grab` session.

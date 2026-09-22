# Trace

**Your coding friend in the terminal.**

Describe the problem.
Let your AI decide what evidence it needs.
Use Trace to retrieve that evidence precisely.
Keep investigating until the cause is proven.

Trace is a poweful terminal investigation tool for AI-assisted debugging and codebase analysis.

Instead of dumping an entire repository, diff, log file, or frontend into an AI context window, Trace lets the model progressively request the exact evidence it needs.

Trace combines repository search, function and symbol extraction, structured HTML/CSS inspection, JSON and YAML queries, version comparison, and clipboard/tmux workflows into a deterministic investigation loop.

> The AI does not need the entire repository.
> It needs the right evidence at the right time.

---

# How Trace Works

```text
Problem statement + Function index
      ↓
AI decides what evidence it needs
      ↓
AI generates a batch of Trace commands
      ↓
Trace retrieves exact evidence
      ↓
Evidence accumulates in context
      ↓
AI updates its hypothesis
      ↓
More targeted Trace commands
      ↓
Root cause is proven
      ↓
Patch / recommendation
```

The workflow is iterative.

The model does not have to guess which files might matter before the investigation starts.

It asks for evidence as its understanding of the problem changes.

---

# Investigation Workflows

Trace is designed around real engineering problems rather than a single repository-search command.

## 1. Code Investigation

Start with a problem statement.

```text
Users occasionally receive duplicate notifications.

We suspect retry handling might be involved,
but we do not know which execution path causes it.

What Trace commands do you need?
```

The AI can begin by requesting repository structure or function boundaries:

```bash
trace --functions .
```

It then receives exact function coordinates:

```text
NotificationDispatcher.cs:312-383 ProcessNotificationDelivery
NotificationDispatcher.cs:448-486 ShouldRetryNotification
NotificationDispatcher.cs:521-564 RecordDeliveryAttempt
NotificationDispatcher.cs:612-642 HasRecentSuccessfulDelivery

RetryPolicy.cs:188-236 RetryFailedNotification
RetryPolicy.cs:245-271 GetRetryBackoffDelay
```

The AI can now request a complete investigation batch:

```bash
trace 312 383 NotificationDispatcher.cs ProcessNotificationDelivery
trace 448 486 NotificationDispatcher.cs ShouldRetryNotification
trace 521 564 NotificationDispatcher.cs RecordDeliveryAttempt
trace 612 642 NotificationDispatcher.cs HasRecentSuccessfulDelivery

trace 188 236 RetryPolicy.cs RetryFailedNotification
trace 245 271 RetryPolicy.cs GetRetryBackoffDelay

trace NotificationRetryLimit .
trace DeliveryDeduplicationWindowMinutes .
trace "duplicate notification" .
```

Trace executes the batch and accumulates the evidence:

```text
+72L  block   ProcessNotificationDelivery(...)
+38L  block   ShouldRetryNotification(...)
+44L  block   RecordDeliveryAttempt(...)
+31L  block   HasRecentSuccessfulDelivery(...)
+49L  block   RetryFailedNotification(...)
+27L  block   GetRetryBackoffDelay(...)
+18L  symbol  NotificationRetryLimit
+13L  symbol  DeliveryDeduplicationWindowMinutes
+26L  text    "duplicate notification"

[trace] +9 entries (+318L)
→ context 807L / 64192B copied to clipboard
```

Paste the accumulated evidence back into the AI.

The AI updates its hypothesis and requests the next batch.

```text
Problem
   ↓
Function index
   ↓
Investigation batch
   ↓
Evidence
   ↓
Updated hypothesis
   ↓
More targeted evidence
   ↓
Root cause
```

---

## 2. Regression / Version Investigation

One of the strongest Trace workflows is investigating a regression between two versions.

Start with the engineering problem rather than manually reading thousands of changed lines.

```text
Version 1 works.

Version 2 has a regression.

Find what changed that could explain the behavior.

What Trace diff commands do you need?
```

Trace supports repository/file comparison and symbol-level comparison.

```bash
trace --diff /path/to/version-1 /path/to/version-2
```

Or compare only a specific implementation unit:

```bash
trace --diff-symbol \
  version-1/grab_state.py \
  version-2/grab_state.py \
  build_state
```

The AI determines which differences it needs to inspect.

```text
WORKING VERSION
       │
       ├────── Trace diff evidence ──────┐
       │                                 │
BROKEN VERSION                           │
                                         ↓
                               AI compares behavior
                                         ↓
                               candidate regression
                                         ↓
                           targeted symbol/function evidence
                                         ↓
                                  root cause
```

The model does not need to ingest both repositories in their entirety.

It can begin with repository-level change evidence and progressively narrow the investigation:

```text
Repository-level changes
        ↓
Relevant changed files
        ↓
Changed functions
        ↓
Changed conditions / state
        ↓
Symbol-level comparison
        ↓
Behavioral difference
        ↓
Regression cause
```

This workflow is especially useful when the most important fact is already known:

> **This version works. This version does not. What changed?**

---

## 3. JSON / Log Investigation

Large JSON and JSONL logs often contain the evidence required to explain a failure, but sending the complete log to an AI wastes context and makes reasoning harder.

Instead:

```text
This run failed.

The execution log is a large JSONL document.

Determine why it failed.

What Trace jq queries do you need?
```

The AI requests structured evidence:

```bash
trace -jq events.jsonl \
  'select(.round == 14) | {round,type,message}'
```

It can generate an entire batch:

```bash
trace -jq events.jsonl 'select(.type == "error")'
trace -jq events.jsonl 'select(.round >= 12 and .round <= 16)'
trace -jq events.jsonl 'select(.event == "patch") | {round,file,status}'
trace -jq events.jsonl 'select(.status == "failed") | {round,type,message}'
```

Each query extracts only the relevant structured records.

```text
Large JSON / JSONL log
          ↓
AI defines jq evidence requests
          ↓
Trace executes targeted queries
          ↓
Small structured evidence set
          ↓
AI identifies suspicious state
          ↓
More specific jq queries
          ↓
Failure mechanism
```

Instead of:

```text
5 MB JSON
    ↓
AI
```

Trace provides:

```text
5 MB JSON
    ↓
targeted jq evidence
    ↓
20 useful records
    ↓
AI
```

The objective is not merely to make `jq` easier to run.

The objective is to let the model decide **which structured evidence is actually necessary**.

For direct object-path extraction:

```bash
trace --json-path config.json '.runtime.providers.openai'
```

---

## 4. HTML / Frontend Investigation

Frontend debugging is often spread across HTML structure, CSS selectors, JavaScript functions, DOM IDs, classes, and runtime state.

Trace lets the AI request those structures directly.

Start with the problem:

```text
The Cancel button sometimes remains disabled
after an investigation finishes.

Determine why.

Tell me which HTML, CSS, and JavaScript
evidence you need.
```

Instead of exporting the complete frontend, the AI can request a targeted batch:

```bash
trace --html-id grab-ui.html cancel-button
trace --html-class grab-ui.html action-buttons
trace --css grab-ui.html '#cancel-button'
trace --symbol grab-ui.html renderRun
trace --context 25 Cancel grab-ui.html
trace --context 40 progress-label grab-ui.html
```

Trace supports several frontend-specific evidence types.

### HTML ID

Extract an element by its `id`:

```bash
trace --html-id grab-ui.html cancel-button
```

Conceptually:

```html
<button id="cancel-button">
    Cancel
</button>
```

becomes a directly addressable investigation unit.

This is useful when the AI knows the DOM element involved but does not need the entire page.

---

### HTML Class

Extract an element using a class:

```bash
trace --html-class grab-ui.html run-card
```

For example:

```html
<div class="run-card active">
    ...
</div>
```

The AI can request the structural block associated with that class rather than searching manually through the entire document.

---

### HTML Tag

Inspect tag boundaries:

```bash
trace --html-tag grab-ui.html form
trace --html-tag grab-ui.html button
trace --html-tag grab-ui.html dialog
```

This is useful when structure matters but no stable ID or class exists.

---

### CSS Selector

Extract the CSS block associated with a selector:

```bash
trace --css grab-ui.html '#cancel-button'
trace --css grab-ui.html '.run-card'
trace --css grab-ui.html '.progress-label'
```

This lets the AI investigate:

```text
HTML element
      ↓
class / ID
      ↓
CSS selector
      ↓
JavaScript handler
      ↓
state mutation
      ↓
frontend behavior
```

---

### JavaScript Symbol

HTML files often contain inline JavaScript.

Trace can also retrieve the relevant JS function directly:

```bash
trace --symbol grab-ui.html renderRun
```

A frontend investigation can therefore combine multiple structural evidence types in a single batch:

```bash
trace --html-id grab-ui.html cancel-button
trace --html-class grab-ui.html run-actions
trace --css grab-ui.html '#cancel-button'
trace --symbol grab-ui.html renderRun
trace --symbol grab-ui.html cancelRun
trace "disabled" grab-ui.html
```

The AI gets only the HTML, CSS, JavaScript, and state evidence associated with the behavior being investigated.

```text
UI problem
    ↓
HTML ID / class
    ↓
DOM structure
    ↓
CSS selector
    ↓
JavaScript function
    ↓
state / event handler
    ↓
behavioral cause
```

This makes frontend investigation follow the same Trace principle:

> **Ask for the evidence associated with the behavior, not the entire application.**

---

## 5. Structured File Investigation

Trace can address structured configuration and documentation directly.

### JSON path

```bash
trace --json-path config.json '.providers.openai.model'
```

### YAML path

```bash
trace --yaml-path deployment.yml '.spec.template.spec.containers'
```

### Markdown heading

```bash
trace --heading README.md "Installation"
```

This gives the model another option besides line-oriented search.

```text
Structured document
       ↓
AI identifies relevant path / heading
       ↓
Trace extracts exact structure
       ↓
Evidence enters investigation context
```

---

# Basic Commands

| Command                                   | Purpose                                                   |
| ----------------------------------------- | --------------------------------------------------------- |
| `trace --clear`                           | Reset the active investigation context                    |
| `trace --tree`                            | Capture repository structure                              |
| `trace --functions .`                     | Build a repository function index                         |
| `trace --functions FILE`                  | Build a function index for a file                         |
| `trace PATTERN .`                         | Search symbols, text, logs, configuration, and references |
| `trace --context N PATTERN FILE`          | Extract surrounding context around matches                |
| `trace START END FILE NAME`               | Extract an exact implementation range                     |
| `trace --symbol FILE SYMBOL`              | Acquire implementation by symbol                          |
| `trace --diff BEFORE AFTER`               | Compare files or repository versions                      |
| `trace --diff-symbol BEFORE AFTER SYMBOL` | Compare one symbol across versions                        |
| `trace -jq FILE FILTER`                   | Query JSON / JSONL with jq                                |
| `trace --html-id FILE ID`                 | Extract an HTML element by ID                             |
| `trace --html-class FILE CLASS`           | Extract an HTML element by class                          |
| `trace --html-tag FILE TAG`               | Inspect HTML tag boundaries                               |
| `trace --css FILE SELECTOR`               | Extract a CSS selector block                              |
| `trace --json-path FILE PATH`             | Extract a JSON path                                       |
| `trace --yaml-path FILE PATH`             | Extract a YAML path                                       |
| `trace --heading FILE HEADING`            | Extract a Markdown section                                |

Trace commands are designed to be generated in **batches**.

Rather than manually asking for one piece of context at a time, the AI can request multiple related evidence items in one investigation round.

---

# Evidence Types

Trace can acquire evidence at several levels:

```text
Repository
    │
    ├── tree
    ├── file search
    ├── function index
    ├── symbols
    ├── exact line ranges
    │
    ├── version diffs
    │     └── symbol diffs
    │
    ├── HTML
    │     ├── id
    │     ├── class
    │     └── tag
    │
    ├── CSS
    │     └── selector
    │
    ├── structured data
    │     ├── jq
    │     ├── JSON path
    │     └── YAML path
    │
    └── documentation
          └── Markdown heading
```

The model chooses the evidence type according to the problem it is trying to solve.

---

# Function Indexing

Function indexing provides the AI with deterministic coordinates for subsequent evidence acquisition.

```bash
trace --functions server.py
trace --functions .
```

Example:

```text
server.py:38-58 [21L] def _init_logging() -> None:
server.py:59-95 [37L] def format(self, record: logging.LogRecord) -> str:
server.py:96-110 [15L] def _get_client() -> str:
server.py:111-121 [11L] def get_cloudflare_access_email() -> str:
server.py:122-166 [45L] def _log_request_start():
server.py:167-211 [45L] def _log_request_end(resp: Response):
server.py:212-227 [16L] def _safe_float(x: Any) -> float:
server.py:247-264 [18L] def _enqueue_all_trading_commands(bot_to_instance: dict, val: bool) -> int:
server.py:265-269 [5L] def _line_key(bot_id: str, instance_id: str, line_id: str) -> Tuple[str, str, str]:
server.py:270-303 [34L] def _coerce_nonneg_float(x: Any) -> float | None:
server.py:304-357 [54L] def _history_add_event(row: Dict[str, Any], event_type: str) -> bool:
server.py:358-473 [116L] def _history_update_last_open_event_with_outcome(out_row: Dict[str, Any]) -> bool:

[trace] functions:. +13L
→ context 489L / 44768B copied to clipboard
```

The AI can then use those coordinates to request exact implementation evidence.

---

# Progressive Evidence Acquisition

Trace maintains an accumulated investigation context.

Every successful extraction adds evidence to the current investigation rather than replacing the previous result.

```text
Round 1
repository structure
       ↓
Round 2
function index
       ↓
Round 3
likely implementation paths
       ↓
Round 4
symbols + configuration
       ↓
Round 5
specific suspicious behavior
       ↓
Root cause
```

Different investigations can use completely different evidence sequences.

A frontend problem might look like:

```text
Problem
   ↓
HTML ID
   ↓
CSS selector
   ↓
JS symbol
   ↓
state mutation
   ↓
Root cause
```

A regression might look like:

```text
Problem
   ↓
repository diff
   ↓
changed file
   ↓
symbol diff
   ↓
surrounding implementation
   ↓
Root cause
```

A failed agent run might look like:

```text
Problem
   ↓
jq query
   ↓
suspicious round
   ↓
more targeted jq query
   ↓
controller symbol
   ↓
Root cause
```

The evidence mechanism changes.

The investigation model remains the same.

---

# Why Not Export Everything?

Large repositories, frontend files, logs, and structured data contain substantial amounts of information unrelated to the problem being investigated.

Sending everything creates several problems:

* irrelevant code consumes context
* important evidence becomes harder to identify
* models reason over unnecessary implementation detail
* large logs overwhelm useful state transitions
* repository snapshots become stale as investigations evolve
* frontend files mix markup, styling, JavaScript, and unrelated components
* missing evidence can still exist despite enormous prompts

Trace instead treats context acquisition as part of the reasoning process.

```text
Do not ask:

"What should I upload?"

Ask:

"What evidence does the model need next?"
```

---

# What Trace Solves

AI-assisted debugging commonly breaks down because:

* context is incomplete
* important implementation details are missing
* irrelevant files pollute the prompt
* logs contain too much unrelated information
* regressions span many changed files
* frontend behavior crosses HTML, CSS, JavaScript, and state
* structured configuration is difficult to inspect efficiently
* the model must guess about code it cannot see

Developers often compensate by:

* copying large files
* pasting fragmented snippets
* sending huge logs
* searching manually across repositories
* repeatedly explaining execution paths
* dumping entire projects into context

Trace replaces that process with explicit, progressive evidence acquisition.

---

# Why Trace Exists

Large software systems distribute behavior across functions, files, services, configuration, logs, versions, HTML, CSS, and runtime state.

The evidence necessary to explain a bug is rarely contained in a single file.

Trace gives an AI a practical way to ask:

> What do I need to inspect next?

The developer remains in control of execution while the model directs the investigation.

```text
Human
  │
  │ describes problem
  ↓
AI
  │
  │ requests evidence
  ↓
Trace
  │
  │ acquires evidence
  ↓
AI
  │
  │ reasons and requests more
  ↓
Trace
  │
  │ acquires narrower evidence
  ↓
Root cause
```

Trace is not trying to replace:

```text
ripgrep
git
jq
sed
awk
yq
```

It coordinates proven Unix tooling into an AI-directed investigation workflow.

---

# Context Storage

Latest extraction:

```text
~/.cache/trace/buffer.txt
```

Accumulated investigation context:

```text
~/.cache/trace/context.txt
```

The accumulated context represents the evidence gathered during the current investigation.

Start a fresh investigation with:

```bash
trace --clear
```

Do not clear the context between investigation rounds unless you are intentionally starting a different problem.

---

# Delayed Batch Summaries

For large command batches:

```bash
export TRACE_DELAY_FOOTER=1
```

Trace can summarize the evidence added during the batch:

```text
[trace] +4 blocks (+110L)
→ context 254L / 6202B copied to clipboard

  +45L  _attach_maxage_fields(...)
  +45L  _parse_duration_to_seconds(...)
  +16L  _parse_iso_utc_to_dt(...)
  +4L   _line_key(...)
```

This makes large AI-generated investigation batches easier to review.

---

# Clipboard Integration

Supported targets:

* tmux buffer
* Wayland clipboard via `wl-copy`
* X clipboard via `xclip`
* macOS clipboard via `pbcopy`

Each investigation step can automatically update the clipboard with the accumulated evidence.

That makes the terminal → AI → terminal investigation loop fast:

```text
AI generates Trace batch
        ↓
execute in terminal
        ↓
Trace updates clipboard
        ↓
paste evidence into AI
        ↓
AI generates next batch
```

---

# Vim / Neovim Integration

```vim
set clipboard+=unnamedplus
set clipboard+=unnamed
```

Trace does not require an editor integration, but keyboard-driven workflows make repeated evidence acquisition faster.

---

# Supported Languages and Formats

Trace currently targets repository investigation across:

### Source code

* Python
* C#
* JavaScript
* TypeScript
* shell scripts

### Infrastructure and configuration

* YAML
* Ansible
* JSON
* JSONL

### Frontend

* HTML
* CSS
* inline JavaScript

### Documentation

* Markdown

The underlying investigation model is not language-specific:

```text
find evidence
     ↓
extract evidence
     ↓
accumulate evidence
     ↓
reason
     ↓
request more evidence
```

---

# Requirements

Required:

```text
zsh
ripgrep
```

Optional tools used by specific workflows:

```text
git
jq
yq
tree
tmux
wl-copy
xclip
pbcopy
```

---

# Install

The repository is currently hosted under the existing `grab` GitHub repository:

```bash
git clone https://github.com/johnsellin93/trace.git
cd trace
chmod +x trace
echo 'export PATH="$HOME/trace:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Once the GitHub repository itself is renamed to `trace`, this becomes:

```bash
git clone https://github.com/johnsellin93/trace.git
cd trace
chmod +x trace
echo 'export PATH="$HOME/trace:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
trace --help
trace --functions .
```

---

# Smart Search

Trace searches relevant project files while ignoring common generated or dependency content.

Typical included content:

* source code
* configuration
* documentation
* scripts
* HTML and CSS
* structured data

Typical ignored content:

* `node_modules`
* build output
* dist output
* vendor directories
* minified files
* lock files
* generated artifacts

---


# Trace

**Your coding friend in the terminal.**

Describe the problem.
Let your AI decide what evidence it needs.
Use Trace to retrieve that evidence precisely.
Keep investigating until the cause is proven.

Trace is a terminal investigation tool for AI-assisted debugging and codebase analysis.

Instead of dumping an entire repository, diff, log file, or frontend into an AI context window, Trace lets the model progressively request the exact evidence it needs.

Trace combines repository search, function and symbol extraction, structured data inspection, version comparison, and clipboard/tmux workflows into a deterministic investigation loop.

> The AI does not need the entire repository.
> It needs the right evidence at the right time.

---

# How Trace Works

```text
Problem statement
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

The AI now has enough evidence to update its hypothesis and request the next batch.

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

The AI determines which differences it needs to inspect.

Typical investigation:

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

The model can request targeted `trace --diff ...` commands instead of requiring the entire repositories to be exported.

As evidence arrives, it can narrow the comparison:

```text
Repository-level changes
        ↓
Relevant changed files
        ↓
Changed functions
        ↓
Changed conditions / state
        ↓
Behavioral difference
        ↓
Regression cause
```

This is useful when the most important fact is already known:

> **This version works. This version does not. What changed?**

---

## 3. JSON / Log Investigation

Large JSON logs often contain the evidence required to explain a failure, but sending the complete log to an AI wastes context and makes reasoning harder.

Instead:

```text
This run failed.

The execution log is a large JSON document.

Determine why it failed.

What Trace jq queries do you need?
```

The AI requests structured evidence:

```bash
trace -jq '...'
trace -jq '...'
trace -jq '...'
```

Each query extracts only the relevant structured records.

The workflow becomes:

```text
Large JSON log
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

---

## 4. HTML / Frontend Investigation

The same workflow can be applied to frontend problems.

```text
This UI element behaves incorrectly.

Determine which HTML, JavaScript, CSS,
symbols, or surrounding implementation
you need to inspect.

Give me the Trace commands.
```

Trace can progressively acquire relevant frontend evidence instead of exporting the entire application.

```text
UI problem
    ↓
HTML structure
    ↓
related JS functions
    ↓
selectors / event handlers
    ↓
related state
    ↓
behavioral cause
```

---

# Basic Commands

| Command                     | Purpose                                                   |
| --------------------------- | --------------------------------------------------------- |
| `trace --clear`             | Reset the active investigation context                    |
| `trace --tree`              | Capture repository structure                              |
| `trace --functions .`       | Build a repository function index                         |
| `trace --functions FILE`    | Build a function index for a file                         |
| `trace PATTERN .`           | Search symbols, text, logs, configuration, and references |
| `trace START END FILE NAME` | Extract an exact implementation range                     |
| `trace --symbol ...`        | Acquire implementation by symbol                          |
| `trace --diff ...`          | Investigate differences between versions                  |
| `trace -jq ...`             | Extract structured JSON evidence                          |

Trace commands are designed to be generated in **batches**.

Rather than manually asking for one piece of context at a time, the AI can request multiple related evidence items in one investigation round.

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
server.py:212-227 [16L] def _log_unhandled_exception(e: Exception):
server.py:228-246 [19L] def _safe_float(x: Any) -> float:
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

Every extraction adds evidence to the current investigation rather than replacing the previous result.

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

This allows investigations to become progressively narrower.

Early commands establish where the problem might exist.

Later commands test increasingly specific hypotheses.

---

# Why Not Export the Entire Repository?

Large repositories contain substantial amounts of information unrelated to the problem being investigated.

Sending everything creates several problems:

* irrelevant code consumes context
* important evidence becomes harder to identify
* models reason over unnecessary implementation detail
* large logs overwhelm useful state transitions
* repository snapshots become stale as investigations evolve
* missing evidence can still exist despite enormous prompts

Trace instead treats context acquisition as part of the reasoning process.

```text
Do not ask:

"What repository should I upload?"

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

Large software systems distribute behavior across functions, files, services, configuration, logs, and versions.

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

Trace is not trying to replace `ripgrep`, `jq`, `git`, `sed`, or the Unix toolchain.

It coordinates them into an AI-directed investigation workflow.

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

# Supported Languages

Trace supports repository investigation across:

* Python
* C#
* JavaScript
* TypeScript
* shell scripts
* YAML
* Ansible

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
git clone https://github.com/johnsellin93/grab.git
cd grab
chmod +x trace
echo 'export PATH="$HOME/grab:$PATH"' >> ~/.zshrc
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

# The Trace Philosophy

Trace starts with a simple idea:

> **Describe the problem first. Acquire evidence second.**

You should not need to know every relevant file before asking an AI for help.

The AI should be able to progressively determine what it needs to inspect.

```text
Describe.
Trace.
Reason.
Repeat.
Prove.
```

# Trace

**Your coding friend in the terminal.**

## Version 1 works. Version 2 doesn't.

Instead of opening files, comparing implementations, searching logs, and repeatedly assembling context for an AI, ask the model:

> Find what changed that could explain the regression.
>
> What Trace commands do you need?

Trace can start with a repository-level diff:

```bash
trace --diff version-1/ version-2/
```

Then narrow the investigation to a specific implementation:

```bash
trace --diff-symbol \
  version-1/app_state.py \
  version-2/app_state.py \
  build_state
```

But Trace isn't really about running one command.

A typical investigation can involve **20–30 small, targeted evidence requests**, often generated in batches.

Each result changes what the model asks for next.

---

## Give the AI a map before giving it the code

```bash
trace --functions .
```

Trace gives the model a lightweight map of **what functions exist and where they are** without loading all of their implementations.

With that map as a starting point, the model can generate a mixed batch of evidence requests across code, logs, frontend, and configuration:

```bash
# Inspect suspicious implementations
trace --symbol version-2/app_state.py build_state
trace --symbol version-2/runner.py execute_run

# Search around a suspicious behavior
trace --context 30 retry version-2/runner.py

# Find failures
trace -jq events.jsonl \
  'select(.status == "failed" or .type == "error") |
   {round,event,type,file,status,message}'

# Reconstruct the failure window
trace -jq events.jsonl \
  'select(
     .round >= 12 and .round <= 16 and
     (.type == "error" or .status == "failed" or .event == "patch")
   ) |
   {round,event,type,file,status,message}'

# Search for likely failure mechanisms
trace -jq events.jsonl \
  'select(
     (.message // "") |
     test("timeout|rate limit|cached replay|validation failed"; "i")
   ) |
   {round,type,event,message}'

# Inspect frontend structure and behavior
trace --html-id app.html investigation-panel
trace --css app.html ".run-card"
trace --symbol app.html renderRun

# Inspect exact structured configuration
trace --json-path config.json '.runtime.providers.openai'
```

Instead of:

```text
5 MB JSON / JSONL log
        ↓
       AI
```

Trace can reduce it to:

```text
5 MB JSON / JSONL log
        ↓
targeted jq evidence
        ↓
20 useful records
        ↓
       AI
```

The evidence accumulates.

The model updates its hypothesis.

Then it asks for another batch.

```text
Problem
   ↓
Function map
   ↓
Batch of targeted evidence requests
   ↓
Evidence
   ↓
Updated hypothesis
   ↓
More targeted evidence
   ↓
Root cause
```

An investigation might involve:

```text
Round 1
repository diff + function map
        ↓
Round 2
changed symbols + suspicious functions
        ↓
Round 3
targeted log queries
        ↓
Round 4
HTML / CSS / JavaScript evidence
        ↓
Round 5
narrower implementation evidence
        ↓
Root cause
```

**The AI doesn't need the entire repository.
It needs the right evidence at the right time.**

---

# Investigation Workflows

## 1. Regression / Version Investigation

**Version 1 works. Version 2 doesn't. What changed?**

Trace can compare entire repositories:

```bash
trace --diff version-1/ version-2/
```

Then progressively narrow the investigation:

```bash
trace --diff-symbol \
  version-1/app_state.py \
  version-2/app_state.py \
  build_state
```

```text
Repository changes
        ↓
Relevant changed files
        ↓
Changed functions
        ↓
Symbol comparison
        ↓
Behavioral difference
        ↓
Regression cause
```

---

## 2. JSON / Log Investigation

Large JSON and JSONL logs can contain millions of irrelevant fields and events.

Instead of loading the entire log, let the model generate targeted queries:

```bash
trace -jq events.jsonl \
  'select(.status == "failed") | {round,type,message}'

trace -jq events.jsonl \
  'select(.round >= 12 and .round <= 16)'

trace -jq events.jsonl \
  'select(.event == "patch") | {round,file,status}'

trace -jq events.jsonl \
  'select(.type == "error")'
```

A model can request several queries in one batch, inspect the results, and generate more specific queries in the next round.

```text
Large JSON / JSONL log
        ↓
targeted jq batch
        ↓
small evidence set
        ↓
suspicious state
        ↓
more targeted queries
        ↓
failure mechanism
```

---

## 3. HTML / Frontend Investigation

Frontend bugs often cross HTML, CSS, JavaScript, and application state.

The model can request all of those evidence types in the same investigation:

```bash
trace --html-id app.html cancel-button

trace --html-class app.html action-buttons

trace --css app.html '#cancel-button'

trace --symbol app.html renderRun

trace --context 25 Cancel app.html
```

```text
UI problem
    ↓
HTML element
    ↓
CSS selector
    ↓
JavaScript handler
    ↓
state mutation
    ↓
behavioral cause
```

---

## 4. Code Investigation

For a codebase investigation, start by giving the model a lightweight function map:

```bash
trace --functions .
```

The model sees where functions live without loading every implementation.

It can then generate a batch:

```bash
trace --symbol server.py process_request

trace --symbol server.py retry_request

trace --context 30 retry server.py

trace "RetryLimit" .

trace "duplicate request" .
```

A single investigation may involve **20–30 commands across several rounds** as the hypothesis changes.

---

## 5. Structured File Investigation

```bash
trace --json-path config.json '.providers.openai.model'

trace --yaml-path deployment.yml '.spec.template.spec.containers'

trace --heading README.md "Installation"
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

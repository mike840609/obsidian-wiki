# Claude adapter — wiki-history-ingest

Claude Code conversation history. Data for the shared procedure in `../SKILL.md`.

## Config

- `CLAUDE_HISTORY_PATH` — defaults to `~/.claude`

## Before you start

**Project Scoping** — read `WIKI_SKIP_PROJECTS` from config (comma-separated substrings). Exclude any project directory whose name contains one of them from **every** step (scan, delta, sampling, manifest writes). If the user names extra projects to skip this run, add them. Apply the exclusion **once, uniformly** — don't hand-write `grep -v` filters into individual commands, which drifts between the scan and manifest steps.

## Pre-extraction (recommended — run before ingest)

Raw JSONL files are 80-90% noise: `tool_use` blocks, `thinking` blocks, `progress` events, and `file-history-snapshot` entries dominate by byte count. The `scripts/extract-jsonl.py` helper strips all of that and writes compact signal-only JSON to `~/.claude/extracted/`, achieving **50–200× file-size reduction** (e.g. 12 MB JSONL → 64 KB extracted). This lets the skill read 5–10× more conversations per run within the same token budget.

Run it as a pre-step before ingesting:

```bash
# First run — extract everything (skip excluded projects)
python3 "$OBSIDIAN_WIKI_REPO/scripts/extract-jsonl.py" --skip tsg,autom8

# Incremental — only sessions modified in the last day
python3 "$OBSIDIAN_WIKI_REPO/scripts/extract-jsonl.py" \
    --since "$(date -v-1d +%Y-%m-%d)" --skip tsg,autom8
```

Extracted files live at `~/.claude/extracted/<project-dir>/<session-id>.json` and contain:

```json
{
  "session_id": "uuid",
  "project": "-Users-name-myapp",
  "cwd": "/Users/name/myapp",
  "start_ts": "...",
  "end_ts": "...",
  "n_turns": 18,
  "n_user_words": 620,
  "turns": [
    {"role": "user",      "text": "..."},
    {"role": "assistant", "text": "..."}
  ]
}
```

**When reading conversations, always prefer the extracted file over the raw JSONL.** If `extract-jsonl.py` was not run first, fall back to raw JSONL — but note the coverage will be shallower because each raw file costs far more tokens to read.

## Conversation sampling heuristic

A history path can hold hundreds of conversation JSONLs — do not try to read them all. Per project:

- **If the project already has memory files** (`memory/*.md`), ingest those first (they are pre-distilled signal), then **also process conversations not yet in the manifest** — new conversations should still be captured even for memory-rich projects.
- **If the project has no memory files**, read only the **3 most recent** conversations (by mtime) to characterize it. Prefer pre-extracted files (see above) — they are cheap enough that you can read 5–10 in the same token budget as 1 raw JSONL.
- Always report what you sampled vs skipped (e.g. "agenttower: 7 memory files + 4 new conversations ingested, 14 unchanged conversations skipped"), so the coverage gap is visible rather than silent.

## Data layout

Claude Code stores data in two locations. Scan **both**.

### Source 1: `~/.claude/` (CLI sessions)

```
~/.claude/
├── projects/                          # Per-project directories
│   ├── -Users-name-project-a/         # Path-derived name (slashes → dashes)
│   │   ├── <session-uuid>.jsonl       # Conversation data (JSONL)
│   │   └── memory/                    # Structured memories
│   │       ├── MEMORY.md              # Memory index
│   │       ├── user_*.md              # User profile memories
│   │       ├── feedback_*.md          # Workflow feedback memories
│   │       └── project_*.md           # Project context memories
│   ├── -Users-name-project-b/
│   │   └── ...
├── sessions/                          # Session metadata (JSON)
│   └── <pid>.json                     # {pid, sessionId, cwd, startedAt, kind, entrypoint}
├── history.jsonl                      # Global session history
├── tasks/                             # Subagent task data
├── plans/                             # Saved plans
└── settings.json
```

### Source 2: `~/Library/Application Support/Claude/local-agent-mode-sessions/` (Desktop app agent sessions)

> **Pre-check first.** Many users are CLI-only and have no desktop sessions. Before walking the structure below, confirm it's non-empty:
> ```bash
> DESKTOP_SESSIONS="$HOME/Library/Application Support/Claude/local-agent-mode-sessions"
> [ -d "$DESKTOP_SESSIONS" ] && find "$DESKTOP_SESSIONS" -name "audit.jsonl" | head -1
> ```
> If that prints nothing, skip this entire source (including audit-log parsing) and don't narrate it.

The Claude desktop app stores local agent mode sessions here. The structure is deeply nested:

```
~/Library/Application Support/Claude/local-agent-mode-sessions/
└── <outer-uuid>/
    └── <inner-uuid>/
        ├── local_<session-uuid>.json          # Session metadata
        └── local_<session-uuid>/
            ├── audit.jsonl                    # Audit log — tool calls, file reads, commands run
            └── .claude/
                └── projects/
                    └── <path-encoded-name>/   # Same path-encoding as ~/.claude/projects/
                        └── <uuid>.jsonl       # Conversation transcript (same JSONL format as CLI)
```

**How to find all local-agent-mode sessions:**

```bash
# Find all session metadata files
find ~/Library/Application\ Support/Claude/local-agent-mode-sessions -name "local_*.json" -maxdepth 4

# Find all audit logs
find ~/Library/Application\ Support/Claude/local-agent-mode-sessions -name "audit.jsonl"

# Find all conversation transcripts
find ~/Library/Application\ Support/Claude/local-agent-mode-sessions -name "*.jsonl" -path "*/.claude/projects/*"
```

**Session metadata (`local_<uuid>.json`)** — JSON file with fields like `sessionId`, `cwd`, `startedAt`, `model`, `title`. Read this first to understand the session context before opening the transcript.

**Audit log (`audit.jsonl`)** — Each line is a JSON record of one agent action: tool calls (Read, Write, Bash, Edit), file accesses, shell commands executed, MCP calls. Useful for understanding *what the agent actually did* — often richer signal than the conversation text alone. Fields: `type`, `toolName`, `input`, `output`, `timestamp`, `sessionId`.

**Conversation transcript (`.claude/projects/.../<uuid>.jsonl`)** — Identical format to CLI conversation JSONL. Parse the same way as `~/.claude/projects/*/*.jsonl`.

## Sources ranked by value

1. **Memory files** (`~/.claude/projects/*/memory/*.md`) — Pre-distilled, already wiki-friendly. Gold.
2. **Conversation JSONL** (both `~/.claude/projects/*/*.jsonl` and desktop app transcripts) — Full conversation transcripts. Rich but noisy.
3. **Audit logs** (`audit.jsonl` in desktop sessions) — Tool-call level record of what was done. Useful for extracting concrete actions, file patterns, and command patterns even when the conversation is sparse.
4. **Session metadata** (`sessions/*.json` and `local_*.json`) — Tells you which project, when, and what CWD.

## What to scan (Step 1)

```bash
# --- Source 1: CLI sessions (~/.claude) ---
# Find all projects
Glob: ~/.claude/projects/*/

# Find memory files (highest value)
Glob: ~/.claude/projects/*/memory/*.md

# Find conversation JSONL files
Glob: ~/.claude/projects/*/*.jsonl

# --- Source 2: Desktop app local-agent-mode sessions ---
DESKTOP_SESSIONS="$HOME/Library/Application Support/Claude/local-agent-mode-sessions"

# Session metadata
find "$DESKTOP_SESSIONS" -name "local_*.json" -maxdepth 4

# Audit logs
find "$DESKTOP_SESSIONS" -name "audit.jsonl"

# Conversation transcripts
find "$DESKTOP_SESSIONS" -name "*.jsonl" -path "*/.claude/projects/*"
```

Canonical-path delta helper (honors `WIKI_SKIP_PROJECTS` + `--skip`, paths already canonical):

```bash
python3 "$OBSIDIAN_WIKI_REPO/scripts/manifest.py" delta "$OBSIDIAN_VAULT_PATH" \
  --scan "$CLAUDE_HISTORY_PATH/projects/*/memory/*.md"
```

Delta report format: "Found X CLI projects, Y desktop sessions. Memory files: A. Conversations: B. Audit logs: C. Delta: D new, E modified."

## Parsing and extraction (Step 2)

### Memory files first

Memory files are already structured with YAML frontmatter:

```markdown
---
name: memory-name
description: one-line description
type: user|feedback|project|reference
---

Memory content here.
```

For each memory file:

- Read it and parse the frontmatter
- `user` type → feeds into an entity page about the user, or concept pages about their domain
- `feedback` type → feeds into skills pages (workflow patterns, what works, what doesn't)
- `project` type → feeds into entity pages for the project
- `reference` type → feeds into reference pages pointing to external resources

The `MEMORY.md` index file in each project is a quick summary — read it first to decide which individual memory files are worth reading in full.

### Conversation JSONL

**Always check for a pre-extracted file first** (see Pre-extraction above). For each conversation `~/.claude/projects/<proj>/<uuid>.jsonl`, look for its counterpart at `~/.claude/extracted/<proj>/<uuid>.json`. If found, read that instead — it is already filtered to user + assistant text turns and costs 50–200× fewer tokens than the raw JSONL.

```
# Resolution order for each session:
1. ~/.claude/extracted/<project>/<session-id>.json   ← prefer (compact, signal-only)
2. ~/.claude/projects/<project>/<session-id>.jsonl   ← fallback (raw, noisy)
```

**Reading a pre-extracted file:** it already contains only the turns you need. Iterate `turns[].{role, text}` directly. The top-level fields (`cwd`, `start_ts`, `n_user_words`, etc.) give you project context without any further parsing.

**Reading raw JSONL (fallback):** Each line is a JSON object:

```json
{
  "type": "user|assistant|progress|file-history-snapshot",
  "message": {
    "role": "user|assistant",
    "content": "text string"
  },
  "uuid": "...",
  "timestamp": "2026-03-15T10:30:00.000Z",
  "sessionId": "...",
  "cwd": "/path/to/project",
  "version": "2.1.59"
}
```

For assistant messages, `content` may be an array of content blocks:

```json
{
  "content": [
    {"type": "thinking", "text": "..."},
    {"type": "text", "text": "The actual response..."},
    {"type": "tool_use", "name": "Read", "input": {...}}
  ]
}
```

- Filter to `type: "user"` and `type: "assistant"` entries only
- For assistant entries, extract `text` blocks (skip `thinking` and `tool_use` — those are noise)
- The `cwd` field tells you which project this conversation belongs to
- Skip `type: "progress"` — internal agent progress updates
- Skip `type: "file-history-snapshot"` — file state tracking
- Skip subagent conversations (under `subagents/` subdirectories) — unless the user asks

### Audit logs (desktop sessions only)

For each `audit.jsonl` found under `local-agent-mode-sessions/`, read it line by line. Each line is a JSON record of one agent action:

```json
{
  "type": "tool_call",
  "toolName": "Bash",
  "input": {"command": "npm test"},
  "output": "...",
  "timestamp": "2026-04-10T14:22:00Z",
  "sessionId": "..."
}
```

**What to extract from audit logs:**

- **File access patterns** — which files does the agent repeatedly Read or Edit? These are the high-value files in the project. Note them as project references.
- **Shell commands** — recurring Bash commands reveal the project's build/test/deploy workflow. Distill these into a `skills/` page (e.g. "how this project is built and tested").
- **Tool call sequences** — if the agent always does Read → Edit → Bash in a particular order, that's a workflow pattern worth capturing.
- **Error patterns** — failed tool calls (non-zero exit codes, error outputs) reveal pain points, known rough edges, or recurring bugs.
- **MCP tool calls** — calls to MCP tools reveal which external services and APIs the project integrates with.

**Skip from audit logs:**

- Routine file reads with no pattern (e.g. reading config files once)
- Tool outputs that are just noise (long stack traces, verbose logs) — summarize the error class, not the full output
- Anything that looks like secrets, tokens, or credentials in command arguments or outputs

**Cross-reference with the conversation transcript:** The audit log tells you *what happened*; the conversation tells you *why*. When both are available for the same session, use them together — the audit log grounds the conversation in concrete actions.

Read the paired `local_<uuid>.json` session metadata before processing the audit log — it gives you `cwd`, `startedAt`, and `title` to contextualize the actions.

## Clustering notes (Step 3)

- The project directory name gives you a natural first-level grouping

## Project naming (Step 4)

Each Claude project maps to a project directory in the vault. The project directory name from `~/.claude/projects/` encodes the original path — decode it to get a clean project name:

```
-Users/Documents/projects/my-Project   → myproject
-Users/Documents/projects/Another-app  → anotherapp
```

## Provenance guidance (Step 4)

- **Memory files** are mostly extracted — the user wrote them by hand and they're already distilled. Treat memory-derived claims as extracted unless you're stitching together claims from multiple memory files.
- **Conversation distillation** is mostly inferred. You're synthesizing a coherent claim from many turns of dialogue, often filling in implicit reasoning. Apply `^[inferred]` liberally to synthesized patterns, generalizations across sessions, and "what the user really meant" interpretations.
- Use `^[ambiguous]` when the user changed their mind across sessions or when assistant and user contradicted each other and the resolution is unclear.

## Manifest and log (Step 5)

`source_type` values: `"claude_conversation"`, `"claude_memory"`, `"claude_audit_log"`, `"claude_desktop_session"`

`projects` section of the manifest:

```json
{
  "project-name": {
    "source_path": "~/.claude/projects/-Users-...",
    "vault_path": "projects/project-name",
    "last_ingested": "TIMESTAMP",
    "conversations_ingested": 5,
    "conversations_total": 8,
    "memory_files_ingested": 3,
    "desktop_sessions_ingested": 2,
    "audit_logs_ingested": 2
  }
}
```

Log line:

```
- [TIMESTAMP] CLAUDE_HISTORY_INGEST projects=N conversations=M desktop_sessions=D audit_logs=A pages_updated=X pages_created=Y mode=append|full
```

hot.md example: "Ingested 5 Claude conversations across 2 projects; surfaced patterns in API design and testing strategy."

## Reference

See `.skills/claude-history-ingest/references/claude-data-format.md` for more details on the data structures.

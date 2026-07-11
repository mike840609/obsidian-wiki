# Copilot adapter — wiki-history-ingest

GitHub Copilot CLI session history. Data for the shared procedure in `../SKILL.md`.

## Config

- `COPILOT_HISTORY_PATH` — defaults to `~/.copilot/session-state`
- `COPILOT_VSCODE_STORAGE_PATH` — VS Code `workspaceStorage`; platform-specific — ask the user if absent

## Ingest mode nuance

Append-mode freshness is keyed per **session**, not per file: re-ingest sessions whose `updated_at` is newer than their `ingested_at` in the manifest.

## Data layout

Copilot stores data in three locations. Scan **all three**.

### Source 1: `~/.copilot/session-state/` (CLI sessions)

```
~/.copilot/session-state/
├── <session-uuid>/
│   ├── workspace.yaml           # Session metadata (id, cwd, summary_count, created_at, updated_at)
│   ├── vscode.metadata.json     # VS Code context (workspaceFolder, repositoryProperties, customTitle)
│   ├── events.jsonl             # Full event log — all turns, tool calls, reasoning
│   ├── session.db               # Per-session SQLite (todos/todo_deps only — skip for ingestion)
│   ├── index.md                 # Session summary written at session end
│   ├── checkpoints/             # Checkpoint JSON files (mid-session summaries)
│   │   └── <uuid>.json          # title, overview, history, work_done, technical_details,
│   │                            #   important_files, next_steps
│   ├── files/                   # Artifacts produced during session (plans, diagrams, etc.)
│   └── research/                # Research artifacts
└── ...
```

### Source 2: `~/.copilot/session-store.db` (Global SQLite)

The canonical cross-session database. This is the **highest-value** source: structured, queryable, and pre-summarised.

```
sessions       — id, cwd, repository, branch, summary, created_at, updated_at, host_type
turns          — session_id, turn_index, user_message, assistant_response, timestamp
checkpoints    — session_id, checkpoint_number, title, overview, history, work_done,
                 technical_details, important_files, next_steps, created_at
session_files  — session_id, file_path, tool_name, turn_index, first_seen_at
session_refs   — session_id, ref_type (commit/pr/issue), ref_value, turn_index, created_at
search_index   — FTS5 virtual table (content, session_id, source_type, source_id)
```

### Source 3: VS Code Workspace Storage (`<workspaceStorage>/<hash>/GitHub.copilot-chat/`)

VS Code extension data, keyed by workspace hash. The path is platform-specific and must come from `.env` or user input.

```
<hash>/GitHub.copilot-chat/
├── transcripts/
│   └── <session-uuid>.jsonl     # Conversation transcripts (same JSONL format as events.jsonl)
├── memory-tool/
│   └── memories/
│       └── <base64-session-id>/ # Per-session saved artifacts (plan.md, etc.)
│           └── plan.md
└── codebase-external.sqlite     # Codebase index (skip — no conversation knowledge)
```

## Sources ranked by value

1. **Checkpoints** (`session-store.db` `checkpoints` table + per-session `checkpoints/*.json`) — Pre-distilled summaries with `overview`, `work_done`, `technical_details`, `important_files`, `next_steps`. Gold.
2. **Session summaries** (`session-store.db` `sessions.summary` + `index.md`) — One-paragraph synopsis per session.
3. **Turns** (`session-store.db` `turns` table + `events.jsonl` / transcript JSONL) — Full conversation. Rich but verbose.
4. **Memory artifacts** (`memory-tool/memories/<id>/plan.md` etc.) — Pre-written plans and structured notes the user saved explicitly. Worth importing verbatim (or lightly summarised).
5. **File access patterns** (`session_files` table + `tool.execution_*` events) — Which files the agent repeatedly touched — reveals high-value project files.
6. **Session refs** (`session_refs` table) — Commits, PRs, and issues linked to sessions.
7. **`vscode.metadata.json`** — Workspace folder path, branch, `customTitle` (user-set session label). Useful for grouping and naming.

## What to scan (Step 1)

```bash
# --- Source 1: per-session directories ---
# Find all session directories (each has workspace.yaml)
ls ~/.copilot/session-state/

# For each session, read workspace.yaml for id/cwd/updated_at
# and vscode.metadata.json for customTitle / repositoryProperties

# --- Source 2: global database ---
# Query session-store.db with sqlite3 (or Python sqlite3)
SELECT s.id, s.cwd, s.repository, s.branch, s.summary, s.updated_at,
       COUNT(DISTINCT t.turn_index) AS turn_count,
       COUNT(DISTINCT c.id)         AS checkpoint_count
FROM sessions s
LEFT JOIN turns t ON t.session_id = s.id
LEFT JOIN checkpoints c ON c.session_id = s.id
GROUP BY s.id
ORDER BY s.updated_at DESC;

# --- Source 3: VS Code workspace storage ---
# For each <hash> directory under workspaceStorage, check for GitHub.copilot-chat/
# Find transcript files
ls <workspaceStorage>/<hash>/GitHub.copilot-chat/transcripts/
```

Build a unified inventory — **one entry per session UUID** — before classifying new/modified/unchanged.

Delta report format: "Found X sessions in session-state, Y in session-store.db, Z VS Code transcript files. Checkpoints: A. Delta: B new, C modified."

## Parsing and extraction (Step 2)

### Ingest checkpoints and summaries first

Checkpoints are already distilled — process them before touching raw turns.

From `session-store.db`:

```sql
SELECT s.id, s.cwd, s.repository, s.branch, s.summary,
       c.checkpoint_number, c.title, c.overview, c.work_done,
       c.technical_details, c.important_files, c.next_steps,
       c.created_at
FROM checkpoints c
JOIN sessions s ON c.session_id = s.id
ORDER BY s.updated_at DESC, c.checkpoint_number ASC;
```

From per-session `checkpoints/*.json` — each checkpoint file has: `title`, `overview`, `history`, `work_done`, `technical_details`, `important_files`, `next_steps`.

Read `index.md` (if present) as a session-level summary — it's typically written at session end and is already concise.

What to extract:

- `overview` → high-level description of what the session accomplished
- `work_done` → concrete tasks completed (good for skills / project pages)
- `technical_details` → implementation specifics (good for concepts pages)
- `important_files` → high-value files in the project (good for project pages)
- `next_steps` → open threads (good for linking to ongoing project work)

### Parse session turns

Read turns from `session-store.db` (preferred — already parsed) or from `events.jsonl` / transcript JSONL.

From `session-store.db`:

```sql
SELECT turn_index, user_message, assistant_response, timestamp
FROM turns
WHERE session_id = '<uuid>'
ORDER BY turn_index ASC;
```

From `events.jsonl` / transcript JSONL — each file is one session, each line is a JSON event:

| `type`                | What it is                              | Worth reading?                            |
| --------------------- | --------------------------------------- | ----------------------------------------- |
| `session.start`       | Session metadata (cwd, branch, version) | Yes — establishes project context         |
| `user.message`        | User turn                               | Yes — `data.content`                      |
| `assistant.message`   | Assistant turn                          | Yes — `data.content` (text) + `data.toolRequests` |
| `tool.execution_start`| Tool call                               | Skim — reveals what files/commands were used |
| `tool.execution_end`  | Tool result                             | No — usually noise                        |

Extraction strategy for `assistant.message`:

- `data.content` is the assistant's text response — extract this
- `data.reasoningText` is internal reasoning — skip (it's the unpacked `reasoningOpaque` field)
- `data.toolRequests` lists tool calls — skim tool names and arguments for file access patterns
- Skip `type: "tool.execution_end"` entirely

### Process memory artifacts

For each session that has a `memory-tool/memories/<base64-id>/` directory in VS Code workspace storage, read any markdown files saved there (typically `plan.md`). These are documents the user explicitly saved — treat them as high-quality, user-authored content.

Decode the base64 directory name to get the session UUID:

```python
import base64
session_id = base64.b64decode(dir_name).decode('utf-8')
```

Memory artifacts map to project `skills/` or `concepts/` pages, depending on content type.

### Extract file and ref patterns

From `session-store.db`:

```sql
-- Most-touched files per project
SELECT repository, file_path, COUNT(*) AS touch_count
FROM session_files
GROUP BY repository, file_path
ORDER BY touch_count DESC;

-- Linked commits/PRs/issues per session
SELECT session_id, ref_type, ref_value, turn_index
FROM session_refs
ORDER BY session_id, turn_index;
```

**File access patterns** reveal which files are architecturally important — note them on project pages.

**Session refs** link Copilot sessions to git history — useful for connecting wiki knowledge to concrete code changes.

## Clustering notes (Step 3)

- `cwd` / `repository` give you a natural first-level grouping; `vscode.metadata.json`'s `customTitle` gives a human-readable session label

## Project naming (Step 4)

Derive the project name from `cwd` or `repository`:

```
C:\Users\name\git\my-project   → my-project
/Users/name/code/another-app   → another-app
```

Prefer `repository` (e.g., `owner/repo`) from `session-store.db` over raw `cwd` when available.

## Provenance guidance (Step 4)

- **Checkpoints and index.md** are pre-distilled by the system — treat checkpoint-derived claims as extracted (the system wrote them from observed actions).
- **Memory artifacts** are user-authored — treat as extracted.
- **Conversation turn distillation** is mostly inferred. You're synthesizing a coherent claim from many turns. Apply `^[inferred]` liberally to synthesized patterns, generalizations across sessions, and "what the user really meant" interpretations.
- Use `^[ambiguous]` when the user changed direction mid-session or when the session ended unresolved.

## Manifest and log (Step 5)

Per-session manifest entry fields: `ingested_at`, `session_id`, `updated_at` (instead of file `size_bytes`/`modified_at`).

`source_type` values: `"copilot_session"`, `"copilot_checkpoint"`, `"copilot_transcript"`, `"copilot_memory_artifact"`

`projects` section of the manifest:

```json
{
  "project-name": {
    "repository": "owner/repo",
    "cwd": "C:\\Users\\name\\git\\project-name",
    "vault_path": "projects/project-name",
    "last_ingested": "TIMESTAMP",
    "sessions_ingested": 5,
    "sessions_total": 8,
    "checkpoints_ingested": 12,
    "memory_artifacts_ingested": 3
  }
}
```

Log line:

```
- [TIMESTAMP] COPILOT_HISTORY_INGEST projects=N sessions=M checkpoints=C pages_updated=X pages_created=Y mode=append|full
```

hot.md example: "Ingested 5 Copilot sessions across 2 projects; surfaced patterns in API design and testing strategy."

## Privacy extras

- `data.reasoningOpaque` / `data.reasoningText` in assistant events is internal reasoning — skip entirely, never copy to wiki

## Reference

See `.skills/copilot-history-ingest/references/copilot-data-format.md` for detailed data structure documentation.

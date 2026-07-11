# Pi adapter — wiki-history-ingest

Pi coding agent session history. Data for the shared procedure in `../SKILL.md`. Pi sessions are stored as structured JSONL with a tree layout — follow the active branch, extract durable knowledge, and compile it.

## Config

- `PI_HISTORY_PATH` — defaults to `~/.pi/agent/sessions` (or the path set by `PI_CODING_AGENT_SESSION_DIR`)

## Before you start

**Session knowledge closure:** Pi session files are the only factual source for this ingest. Do not add background knowledge from model training, other tools, package docs, local files, or the current conversation unless that fact appears in the selected session entries. If outside context seems useful, mark it as an open question or skip it — never present it as extracted session knowledge.

## Data layout

```
~/.pi/agent/sessions/
├── --<cwd-path>--/                    # Working directory with / replaced by -
│   └── <timestamp>_<uuid>.jsonl       # Session JSONL file
└── ...
```

The session filename contains an ISO timestamp and UUID. The parent directory encodes the working directory where the session was created.

### Session JSONL format

Each `.jsonl` file is a sequence of JSON objects. The first line is always a `session` header; subsequent lines are tree entries with `id` and `parentId`.

Key entry types:

| `type` | Purpose | Ingest? |
|---|---|---|
| `session` | Header with `cwd`, `version`, `id`, `timestamp` | Metadata only |
| `message` | Conversation turn (`user`, `assistant`, `toolResult`, `bashExecution`, etc.) | **Primary source** |
| `session_info` | Display name set via `/name` | For session title |
| `compaction` | Context compaction summary | **High signal** |
| `branch_summary` | Summary when switching branches via `/tree` | **High signal** |
| `model_change` | Model switch event | Skip |
| `thinking_level_change` | Thinking level change | Skip |
| `custom` | Extension state (not in LLM context) | Skip |
| `custom_message` | Extension-injected message | Context only |
| `label` | User bookmark/label | Skip |

Message roles inside `message` entries:

- `user` — user input; `content` is string or `(TextContent \| ImageContent)[]`
- `assistant` — assistant response; `content` is `(TextContent \| ThinkingContent \| ToolCall)[]`
- `toolResult` — tool execution result; `content` is `(TextContent \| ImageContent)[]`
- `bashExecution` — bash command + output; `command`, `output`, `exitCode`
- `branchSummary` — branch switch summary; `summary` string
- `compactionSummary` — compaction summary; `summary` string

## Sources ranked by value

1. **`message` entries (`user` + `assistant`)** — full conversation transcripts; rich but noisy
2. **`compaction` entries** — pre-synthesized summaries of older context; gold
3. **`branch_summary` entries** — summaries of abandoned branches; good signal
4. **`bashExecution` entries** — concrete commands run; useful for workflow patterns
5. **`session_info` entries** — session name for topic inference

Skip `model_change`, `thinking_level_change`, `custom` (extension state), and `label` entries.

## What to scan (Step 1)

```bash
# List all session files
find ~/.pi/agent/sessions -name "*.jsonl" -type f

# Or with custom path
find "$PI_HISTORY_PATH" -name "*.jsonl" -type f
```

For each session file, record in the inventory:

- `path` — absolute path
- `cwd` — decoded from parent directory name (`--<path>--` → `/path`)
- `session_name` — from the latest `session_info` entry (if any)
- `modified_at` — file mtime
- `already_ingested` — presence in `.manifest.json`

Delta report format: "Found N Pi sessions across K projects. Delta: X new, Y modified."

## Parsing and extraction (Step 2)

For each selected session file, read it line by line. Because sessions use a tree structure, build the active branch first:

1. Parse all entries into a map by `id`
2. Find the current leaf (the entry with no children, or the last `message` entry)
3. Walk `parentId` chain from leaf to root to get the active path
4. Reverse the path so it's chronological

### Extraction rules

From the active path, extract:

- **`session` header** — `cwd`, `timestamp`, `parentSession` (if forked)
- **`session_info`** — `name` field for session title/topic inference
- **`message` entries with `role: "user"`** — extract `content` text (skip images)
- **`message` entries with `role: "assistant"`** — extract `text` content blocks; skip `thinking` blocks (noise); note `toolCall` blocks (they reveal what the agent actually did)
- **`message` entries with `role: "toolResult"`** — summarize outcomes, not full output
- **`message` entries with `role: "bashExecution"`** — extract command + exit code; recurring commands reveal build/test/deploy workflows
- **`compaction` entries** — read `summary` verbatim; it's already distilled
- **`branch_summary` entries** — read `summary` verbatim; captures abandoned approaches

### Evidence ledger

As you parse, build a private evidence ledger before writing any wiki page. Each durable fact or decision you may write must carry at least one source reference:

```
pi:<session-file-basename>#<entry-id>
```

If an entry lacks an `id`, use `pi:<session-file-basename>:line<N>` from the JSONL line number. Keep the cited text snippet or summarized observation next to the reference while drafting so you can verify claims before writing.

### Skip / noise filters

- `thinking` content blocks — internal reasoning, not durable knowledge
- Image content blocks — skip unless the user explicitly asks for image transcription
- Raw tool outputs longer than 500 chars — summarize the outcome
- Token accounting (`usage` fields) — metadata only
- Repeated plan echoes or status updates

## Clustering notes (Step 3)

- Merge recurring patterns across dates and projects **only when each pattern member has evidence ledger references**
- Use the `cwd` from the session header to infer project scope
- Use `session_info.name` as a topic hint when available
- Drop any cluster whose key claims cannot be traced back to the selected session files

## Writing rules extras (Step 4)

- Preserve session-specific decision context when it explains why an approach was chosen; do not flatten it into generic tool advice.
- Add a source reference comment near every extracted paragraph or bullet:
  ```markdown
  - Durable fact from the session. <!-- source: pi:2026-06-01T120000_abcd.jsonl#entry-123 -->
  ```
  Multiple sources are comma-separated. These comments are the audit trail; do not omit them for extracted claims.

## Provenance guidance (Step 4)

- Extracted claims use no inline marker by default, but must have a nearby source reference comment.
- `compaction` and `branch_summary` entries are pre-distilled — treat as mostly extracted, with source reference comments.
- Conversation distillation is mostly `^[inferred]` — you're synthesizing from dialogue or inferring from tool calls, and it still needs source references to the turns that support the synthesis.
- Use `^[ambiguous]` when sessions conflict or a compaction summary contradicts later conversation turns.

### Source verification gate

Before writing any page, verify the draft against the evidence ledger:

1. Every claim (extracted / ^[inferred] / ^[ambiguous]) has at least one `pi:...` source reference; extracted claims must use a nearby `<!-- source: pi:... -->` comment.
2. Every source reference points to a selected session file and an entry on the active branch (or a cited `compaction` / `branch_summary`).
3. Proper nouns, tool names, command names, filenames, URLs, package names, and error strings in claims appear in the cited entry text or command fields. Use literal search (`grep`/`rg`) on the session file for distinctive strings when in doubt.
4. If a claim cannot be verified, either delete it or mark it `^[inferred]` / `^[ambiguous]` with the supporting source refs; never leave unverifiable content without one of these markers (unmarked implies extracted).
5. Do not write facts learned from the model's training data or the current agent session unless they are explicitly present in the Pi session evidence.

## Manifest and log (Step 5)

`source_type` value: `pi_session`. `project` is the inferred project name from the decoded `cwd`.

Top-level summary block:

```json
{
  "pi": {
    "source_path": "~/.pi/agent/sessions/",
    "last_ingested": "TIMESTAMP",
    "sessions_ingested": 12,
    "sessions_total": 40,
    "pages_created": 5,
    "pages_updated": 12
  }
}
```

Log line:

```
- [TIMESTAMP] PI_HISTORY_INGEST sessions=N pages_updated=X pages_created=Y mode=append|full
```

hot.md example: "Ingested 12 Pi sessions across 3 projects; surfaced patterns in CLI tooling and API design."

## Privacy extras

- Summarize bash outputs that contain paths, environment variables, or secrets
- Do not quote raw `toolCall` arguments verbatim if they contain sensitive data

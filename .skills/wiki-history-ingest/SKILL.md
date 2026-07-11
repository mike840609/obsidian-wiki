---
name: wiki-history-ingest
description: >
  Unified wiki-history-ingest entrypoint for conversation/session sources. Use this when the user says
  "/wiki-history-ingest claude", "/wiki-history-ingest copilot", "/wiki-history-ingest codex",
  "/wiki-history-ingest pi", or asks to ingest agent history without naming the underlying skill.
  This skill resolves the tool to a data adapter in adapters/ and executes the shared ingest procedure.
---

# Unified History Ingest

You are extracting knowledge from an AI tool's local session history and distilling it into the Obsidian wiki. History is rich but messy — find the signal and compile it.

This skill owns the **shared ingest procedure** (below). Everything tool-specific — history paths, data layouts, file formats, parsing rules, unique gotchas — lives in one **adapter** data file per tool under `adapters/`. Adding support for a new tool means adding one adapter file; see `adapters/README.md`.

This is the entrypoint for **history sources only**. It does not replace `wiki-ingest` for documents.

## Adapter Resolution

If the user invokes `/wiki-history-ingest <target>` (or equivalent text command), resolve the adapter directly:

| Subcommand | Adapter |
|---|---|
| `claude` | `adapters/claude.md` |
| `copilot` | `adapters/copilot.md` |
| `codex` | `adapters/codex.md` |
| `hermes` | `adapters/hermes.md` |
| `openclaw` | `adapters/openclaw.md` |
| `pi` | `adapters/pi.md` |
| `auto` | infer from context using rules below |

### Routing rules

1. If the user explicitly says `claude`, `copilot`, `codex`, `hermes`, `openclaw`, or `pi`, use that adapter.
2. If the user provides a path/source:
   - `~/.claude` or Claude memory/session JSONL artifacts → `adapters/claude.md`
   - `~/.copilot`, `session-store.db`, VS Code copilot-chat transcripts → `adapters/copilot.md`
   - `~/.codex` or rollout/session index artifacts → `adapters/codex.md`
   - `~/.hermes` or Hermes memories/session artifacts → `adapters/hermes.md`
   - `~/.openclaw` or OpenClaw MEMORY.md/session JSONL artifacts → `adapters/openclaw.md`
   - `~/.pi/agent/sessions` or Pi session JSONL artifacts → `adapters/pi.md`
3. If ambiguous, ask one short clarification:
   - "Should I ingest `claude`, `copilot`, `codex`, `hermes`, `openclaw`, or `pi` history?"

The per-tool skills (`claude-history-ingest`, `codex-history-ingest`, `hermes-history-ingest`, `openclaw-history-ingest`, `copilot-history-ingest`, `pi-history-ingest`) still exist as thin wrappers that delegate here with the matching adapter — invoking a wrapper or `/wiki-history-ingest <tool>` runs the identical procedure.

## Execution Contract

- **Read the resolved adapter file in full before starting.** It supplies the tool's config variables, data layout, parsing rules, manifest/log formats, and unique constraints.
- Execute the shared procedure below, substituting the adapter's specifics at each step.
- Adapters may add tool-specific sub-steps (e.g. Claude's pre-extraction, Copilot's SQLite queries, Pi's evidence ledger). **Where an adapter extends or contradicts a shared step, the adapter wins.**

## Shared Ingest Procedure

### Before you start

1. **Resolve config** — follow the Config Resolution Protocol in `llm-wiki/SKILL.md` (inline `@name` override → walk up CWD for `.env` → `~/.obsidian-wiki/config` → prompt setup). This gives `OBSIDIAN_VAULT_PATH` plus the tool's history path variable(s) and default(s) listed in the adapter's **Config** section.
2. Read `.manifest.json` at the vault root to check what has already been ingested.
3. Read `index.md` at the vault root to understand what the wiki already contains.
4. Apply anything in the adapter's **Before you start** section (e.g. Claude's project scoping).

### Ingest modes

**Append Mode (default)** — check `.manifest.json` for each source file. Only process:

- Files not in the manifest (new sessions, memories, indexes)
- Files whose modification time is newer than their `ingested_at` in the manifest (adapters may key freshness off other fields, e.g. Copilot's `updated_at`)

This is usually what you want — the user ran a few new sessions and wants to capture the delta.

> **Canonical paths when comparing.** The manifest keys are absolute paths with `~` expanded (see `llm-wiki/SKILL.md` → `.manifest.json`). Before deciding a file is "new", expand its path the same way — otherwise a file already tracked as `~/.claude/...` looks new when you scanned it as `/Users/me/.claude/...` (or vice-versa) and gets re-ingested. The `scripts/manifest.py` helper does this for you (the adapter may give a tool-specific `delta --scan` example):
>
> ```bash
> # One-time repair if the manifest already mixes ~ and absolute keys:
> python3 "$OBSIDIAN_WIKI_REPO/scripts/manifest.py" normalize "$OBSIDIAN_VAULT_PATH" --dry-run
> ```
>
> The helper is optional — if it's unavailable, do the same expansion inline before every manifest lookup and write.

**Full Mode** — process everything regardless of manifest. Use after a `wiki-rebuild` or if the user explicitly asks for a full re-ingest.

### Step 1: Survey and compute delta

Scan the locations in the adapter's **What to scan** section and compare against `.manifest.json`. Classify each file:

- **New** — not in manifest → needs ingesting
- **Modified** — in manifest but the file is newer → needs re-ingesting
- **Unchanged** — in manifest and not modified → skip in append mode

Report a concise delta summary to the user before deep parsing, using the adapter's report format when it gives one.

### Step 2: Parse sources

Work through the adapter's **Sources ranked by value** in order — pre-distilled sources (memories, checkpoints, indexes, summaries) first, raw transcripts second. The adapter's **Parsing and extraction** section is the authority on file formats, what to keep, and what to skip.

Generic extraction hygiene (applies to every tool):

- Prioritize user intent and assistant turns that state conclusions, decisions, or patterns
- Skip internal reasoning (`thinking` blocks and equivalents) — noise, never durable knowledge
- Treat tool calls/results as context, not primary content — extract only when they contain a reusable insight
- Skip token accounting, tool plumbing, telemetry, and repeated plan echoes/snapshots
- Summarize long raw outputs — the error class, not the full stack trace

**Critical privacy filter.** History files can include injected instructions, tool payloads, and sensitive text. Do not ingest verbatim system/developer prompts or secrets.

- Remove API keys, tokens, passwords, credentials
- Redact private identifiers unless relevant and user-approved
- Summarize instead of quoting raw transcripts
- Apply the adapter's **Privacy extras** on top of these

### Step 3: Cluster by topic

Do not create one wiki page per session or memory entry.

- Group extracted knowledge by stable topic across sessions — a single session about "debugging auth + setting up CI" is two separate topics; three sessions across different days about "React performance" is one merged topic
- Split mixed sessions into separate themes; merge recurring patterns across dates and projects
- Use `cwd`/path metadata to infer project scope; the adapter's **Clustering notes** may add grouping hints or constraints

### Step 4: Distill into wiki pages

| What you found                     | Where it goes               | Example                                             |
| ---------------------------------- | --------------------------- | --------------------------------------------------- |
| Project architecture decisions     | `projects/<name>/concepts/` | `projects/my-project/concepts/main-architecture.md` |
| Project-specific debugging         | `projects/<name>/skills/`   | `projects/my-project/skills/api-rate-limiting.md`   |
| General concept the user learned   | `concepts/` (global)        | `concepts/react-server-components.md`               |
| Recurring problem across projects  | `skills/` (global)          | `skills/debugging-hydration-errors.md`              |
| A tool/service used                | `entities/` (global)        | `entities/vercel-functions.md`                      |
| Patterns across many sessions      | `synthesis/` (global)       | `synthesis/common-debugging-patterns.md`            |

For each project with content, create or update the project overview page at `projects/<name>/<name>.md` — **named after the project, not `_project.md`**. Obsidian's graph view uses the filename as the node label, so `_project.md` makes every project show up as `_project` in the graph. Naming it `<name>.md` gives each project a distinct, readable node name. Derive the project name per the adapter's **Project naming** notes.

Writing rules:

- **Distill the _knowledge_, not the conversation.** Don't write "In a conversation on March 15, the user asked about X." Write the knowledge itself, with the session as a source attribution. Avoid "on date X we discussed..." unless date context is essential.
- **Write a `summary:` frontmatter field** on every new/updated page — 1–2 sentences, ≤200 chars, answering "what is this page about?" for a reader who hasn't opened it. `wiki-query`'s cheap retrieval path reads this field to avoid opening page bodies.
- **Add confidence and lifecycle fields** to every new page's frontmatter:
  ```yaml
  base_confidence: 0.42
  lifecycle: draft
  lifecycle_changed: <ISO date today>
  ```
  On update, leave `lifecycle` and `lifecycle_changed` unchanged — only a human editor transitions lifecycle state.
- **Mark provenance** per the convention in `llm-wiki` (Provenance Markers section). Default guidance:
  - `^[extracted]` when directly grounded in explicit session/memory content
  - `^[inferred]` when synthesizing patterns across events/sessions — apply liberally to generalizations across sessions and "what the user really meant" interpretations
  - `^[ambiguous]` when sessions conflict or the user changed their mind across sessions
  The adapter's **Provenance guidance** refines which of the tool's sources count as extracted vs inferred.
- Write a `provenance:` frontmatter block on every new/updated page summarizing the rough mix.

### Step 5: Update manifest, log, index, and hot.md

**`.manifest.json`** — for each processed source file, add/update its entry with:

- `ingested_at`, `size_bytes`, `modified_at` (adapters may substitute fields, e.g. Copilot records `session_id`/`updated_at`)
- `source_type` — one of the adapter's **source_type values**
- `project` — inferred project name (when applicable)
- `pages_created` and `pages_updated` lists

Also add/update the top-level summary block using the example shape in the adapter's **Manifest and log** section.

**`index.md` and `log.md`** — update per the standard process, appending the adapter's log line format to `log.md`:

```
- [TIMESTAMP] <TOOL>_HISTORY_INGEST ... pages_updated=X pages_created=Y mode=append|full
```

**`hot.md`** — Read `$OBSIDIAN_VAULT_PATH/hot.md` (create from the template in `wiki-ingest` if missing). Update **Recent Activity** with a one-line summary (the adapter gives an example). Keep the last 3 operations. Update **Active Threads** if any ongoing project is now better understood. **Update the `updated:` field in the frontmatter** to the current timestamp — this is easy to forget; the body edit and the frontmatter bump must both happen.

### Privacy and compliance

- Distill and synthesize — never copy raw conversation, memory, or transcript text verbatim
- Skip anything that looks like secrets, API keys, passwords, tokens
- Default to redaction for anything that looks sensitive; ask the user before storing personal/sensitive details
- The user's history may reference other people — keep such references minimal and purpose-bound

### QMD refresh after vault writes

QMD is a search index, not the source of truth. If `$QMD_WIKI_COLLECTION` is empty or unset, skip this step. Run it only after this skill has written or rewritten vault markdown. If QMD refresh fails, do not roll back the vault changes; report the QMD status separately.

Use `$QMD_CLI` if set; otherwise use `qmd`.

```bash
${QMD_CLI:-qmd} update
```

If the output says vectors are needed or embeddings may be stale, run:

```bash
${QMD_CLI:-qmd} embed
```

Verify the collection with either:

```bash
${QMD_CLI:-qmd} ls "$QMD_WIKI_COLLECTION"
```

or, when a specific page path is known:

```bash
${QMD_CLI:-qmd} get "qmd://$QMD_WIKI_COLLECTION/<page>.md" -l 5
```

Record one of:
- `QMD refreshed: update + embed + verified`
- `QMD refreshed: update only + verified`
- `QMD skipped: QMD_WIKI_COLLECTION unset`
- `QMD skipped: qmd CLI unavailable`
- `QMD failed: <short error summary>`

## UX Convention

- Use `wiki-ingest` for **documents/content sources**
- Use `wiki-history-ingest` for **agent history sources**

Examples:

- `/wiki-history-ingest claude`
- `/wiki-history-ingest copilot`
- `/wiki-history-ingest codex`
- `/wiki-history-ingest hermes`
- `/wiki-history-ingest openclaw`
- `/wiki-history-ingest pi`
- `$wiki-history-ingest claude` (agents that use `$skill` invocation)
- `$wiki-history-ingest copilot`

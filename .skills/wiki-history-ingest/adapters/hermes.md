# Hermes adapter — wiki-history-ingest

Hermes agent history. Data for the shared procedure in `../SKILL.md`. Hermes stores both free-form memories and structured session transcripts — focus on durable knowledge, not operational telemetry.

## Config

- `HERMES_HISTORY_PATH` — defaults to `~/.hermes` (or `$HERMES_HOME` for non-default profiles)

## Data layout

Hermes stores all local artifacts under `~/.hermes/`.

```
~/.hermes/
├── memories/                          # Persistent agent memories (markdown or JSON)
│   └── *.md / *.json
├── skills/                            # Installed skills (read-only for ingest purposes)
│   └── <skill-name>/SKILL.md
├── sessions/                          # Session transcripts (if session logging is enabled)
│   └── YYYY-MM-DD/
│       └── <session-id>.jsonl
├── config.yaml                        # User config (model, theme, paths)
└── .hub/                              # Skills Hub state (lock.json, audit.log, quarantine/)
```

## Sources ranked by value

1. `memories/*.md` / `memories/*.json` — highest signal; curated persistent knowledge the agent accumulated
2. `sessions/**/*.jsonl` — structured turn-by-turn transcripts; rich but noisy
3. `config.yaml` — metadata only (model preferences, paths); rarely worth ingesting

Skip `.hub/` internals (audit/quarantine state) and the `skills/` directory (source material, not user knowledge).

## What to scan (Step 1)

- `~/.hermes/memories/`
- `~/.hermes/sessions/**/` (if present)

## Parsing and extraction (Step 2)

### Parse memories first

Memories are the highest-value source. Hermes writes them as either:

- **Markdown** — structured prose with optional frontmatter; ingest directly
- **JSON** — `{"content": "...", "created_at": "...", "tags": [...]}` records

For each memory:

- Extract the core knowledge claim
- Note any tags Hermes attached (they often map to wiki categories)
- Merge into the appropriate wiki page rather than creating one memory = one page

### Session JSONL

Each session JSONL line is an event envelope. Common shapes:

```json
{"role": "user", "content": "..."}
{"role": "assistant", "content": "..."}
{"type": "tool_use", "name": "...", "input": {...}}
{"type": "tool_result", "content": "..."}
```

Extraction rules:

- Treat `tool_use` / `tool_result` pairs as context, not primary content
- Extract user intent from high-signal turns; skip low-information follow-ups

## Clustering notes (Step 3)

- Group memories by stable topic (concept, tool, project, technique)
- Use file paths or session `cwd` metadata to infer project scope when available

## Provenance guidance (Step 4)

- `^[extracted]` when directly grounded in explicit memory/session content
- `^[inferred]` when synthesizing patterns across multiple memories
- `^[ambiguous]` when memories conflict

## Manifest and log (Step 5)

`source_type` values: `hermes_memory` | `hermes_session`

Top-level summary block:

```json
{
  "hermes": {
    "source_path": "~/.hermes/",
    "last_ingested": "TIMESTAMP",
    "memories_ingested": 42,
    "sessions_ingested": 7,
    "pages_created": 5,
    "pages_updated": 12
  }
}
```

Log line:

```
- [TIMESTAMP] HERMES_HISTORY_INGEST memories=N sessions=M pages_updated=X pages_created=Y mode=append|full
```

hot.md example: "Ingested 42 Hermes memories and 7 sessions; dominant themes: reasoning strategies, tool use patterns."

## Reference

See `.skills/hermes-history-ingest/references/hermes-data-format.md` for field-level notes and extraction guidance.

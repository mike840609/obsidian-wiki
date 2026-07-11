# OpenClaw adapter — wiki-history-ingest

OpenClaw agent history. Data for the shared procedure in `../SKILL.md`. OpenClaw stores both a structured long-term MEMORY.md and per-session JSONL transcripts — focus on durable knowledge, not operational telemetry.

## Config

- `OPENCLAW_HISTORY_PATH` — defaults to `~/.openclaw`

## Data layout

OpenClaw stores all local artifacts under `~/.openclaw/`.

```
~/.openclaw/
├── openclaw.json                          # Global config
├── credentials/                           # Auth tokens (skip entirely)
├── workspace/                             # Agent workspace
│   ├── MEMORY.md                          # Long-term memory (loaded every session)
│   ├── DREAMS.md                          # Optional dream diary / summaries
│   └── memory/
│       ├── YYYY-MM-DD.md                  # Daily notes (today + yesterday auto-loaded)
│       └── ...
└── agents/
    └── <agentId>/
        ├── agent/
        │   └── models.json                # Agent config (skip)
        └── sessions/
            ├── sessions.json              # Session index
            └── <sessionId>.jsonl          # Session transcript (JSONL, append-only)
```

## Sources ranked by value

1. `workspace/MEMORY.md` — highest signal; long-term durable facts the agent accumulated
2. `workspace/memory/YYYY-MM-DD.md` — daily notes; recent entries often contain active project context
3. `agents/*/sessions/<id>.jsonl` — session transcripts; rich but noisy
4. `agents/*/sessions/sessions.json` — session index for inventory and timestamps
5. `workspace/DREAMS.md` — optional summaries; ingest if present

Skip `credentials/` entirely. Skip `agents/*/agent/models.json` (runtime config, not user knowledge).

## What to scan (Step 1)

- `~/.openclaw/workspace/MEMORY.md`
- `~/.openclaw/workspace/DREAMS.md` (if present)
- `~/.openclaw/workspace/memory/*.md`
- `~/.openclaw/agents/*/sessions/sessions.json`
- `~/.openclaw/agents/*/sessions/*.jsonl`

## Parsing and extraction (Step 2)

### Parse MEMORY.md first

`MEMORY.md` is the highest-value source. It is plain markdown, human-readable and human-editable. It typically contains:

- Durable facts about the user's preferences, environment, and recurring patterns
- Decisions and context the agent was told to remember
- Project-specific notes the agent accumulated over many sessions

Read it in full and extract concept-level knowledge. Do not create one wiki page per MEMORY.md entry — cluster by topic.

### Parse daily notes

`workspace/memory/YYYY-MM-DD.md` files contain time-stamped notes from that day's sessions. Prioritize recent files (last 30–90 days). Extract:

- Active project context and decisions made
- Patterns or techniques discovered
- Recurring blockers or solved problems

Older daily notes have diminishing signal — summarize in bulk rather than extracting line-by-line.

### Session JSONL

Each session file is JSONL (append-only, one JSON object per line):

```json
{"role": "user",      "content": "...", "timestamp": "..."}
{"role": "assistant", "content": "...", "timestamp": "..."}
{"role": "tool",      "name": "...",   "content": "...", "timestamp": "..."}
```

Extraction rules:

- Extract user intent from high-signal turns; skip low-information follow-ups
- Cross-reference the `sessions.json` index to get session names/labels before opening individual transcripts

## Clustering notes (Step 3)

- Merge recurring patterns across dates and agents
- Use session `cwd` or workspace path to infer project scope when available

## Provenance guidance (Step 4)

- `^[extracted]` when directly grounded in explicit session/memory content
- `^[inferred]` when synthesizing patterns across multiple sessions
- `^[ambiguous]` when sessions conflict

## Manifest and log (Step 5)

`source_type` values: `openclaw_memory` | `openclaw_daily_note` | `openclaw_session` | `openclaw_dreams`

Additional per-file manifest field: `agent_id` — agent directory name (when applicable).

Top-level summary block:

```json
{
  "openclaw": {
    "source_path": "~/.openclaw/",
    "last_ingested": "TIMESTAMP",
    "memory_updated_at": "TIMESTAMP",
    "daily_notes_ingested": 14,
    "sessions_ingested": 23,
    "pages_created": 6,
    "pages_updated": 18
  }
}
```

Log line:

```
- [TIMESTAMP] OPENCLAW_HISTORY_INGEST memory=updated daily_notes=N sessions=M pages_updated=X pages_created=Y mode=append|full
```

hot.md example: "Ingested OpenClaw MEMORY.md and 14 daily notes; surfaced automation patterns and multi-agent coordination knowledge."

## Reference

See `.skills/openclaw-history-ingest/references/openclaw-data-format.md` for field-level notes and parsing guidance.

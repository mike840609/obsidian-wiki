---
name: openclaw-history-ingest
description: >
  Ingest OpenClaw agent history into the Obsidian wiki. Use this skill when the user wants to mine
  their past OpenClaw sessions for knowledge, import their ~/.openclaw folder, extract insights from
  previous OpenClaw conversations, or says things like "process my OpenClaw history", "add my OpenClaw
  sessions to the wiki", "ingest ~/.openclaw", or "what have I worked on in OpenClaw". Also triggers
  when the user mentions OpenClaw session logs, MEMORY.md, daily notes, or ~/.openclaw/workspace.
---

# OpenClaw History Ingest — Session & Memory Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/openclaw.md` — the OpenClaw adapter: history path (`OPENCLAW_HISTORY_PATH`, default `~/.openclaw`), data layout, MEMORY.md / daily notes / session JSONL parsing, and gotchas.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest openclaw`.

Tool reference material stays at `references/openclaw-data-format.md` in this directory (linked from the adapter).

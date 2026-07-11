---
name: pi-history-ingest
description: >
  Ingest Pi coding agent session history into the Obsidian wiki. Use this skill when the user wants to mine
  their past Pi sessions for knowledge, import their ~/.pi/agent/sessions folder, extract insights from
  previous coding sessions, or says things like "process my Pi history", "add my Pi sessions to the wiki",
  "ingest ~/.pi", or "what have I worked on in Pi". Also triggers when the user mentions Pi sessions,
  Pi agent history, ~/.pi/agent/sessions, or Pi conversation logs.
---

# Pi History Ingest — Session Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/pi.md` — the Pi adapter: history path (`PI_HISTORY_PATH`, default `~/.pi/agent/sessions`), tree-structured session JSONL parsing, the evidence ledger, the source verification gate, and the session-knowledge-closure constraint.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest pi`.

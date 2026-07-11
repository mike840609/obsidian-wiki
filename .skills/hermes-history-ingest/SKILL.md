---
name: hermes-history-ingest
description: >
  Ingest Hermes agent history into the Obsidian wiki. Use this skill when the user wants to mine
  their past Hermes sessions for knowledge, import their ~/.hermes folder, extract insights from
  previous Hermes conversations, or says things like "process my Hermes history", "add my Hermes
  memories to the wiki", "ingest ~/.hermes", or "what have I worked on in Hermes". Also triggers
  when the user mentions Hermes memories, Hermes sessions, ~/.hermes/memories, or Hermes skill logs.
---

# Hermes History Ingest — Conversation & Memory Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/hermes.md` — the Hermes adapter: history path (`HERMES_HISTORY_PATH`, default `~/.hermes`), data layout, memory and session JSONL parsing, and gotchas.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest hermes`.

Tool reference material stays at `references/hermes-data-format.md` in this directory (linked from the adapter).

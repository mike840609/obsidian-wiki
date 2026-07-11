---
name: codex-history-ingest
description: >
  Ingest Codex CLI conversation history into the Obsidian wiki. Use this skill when the user wants to mine
  their past Codex sessions for knowledge, import their ~/.codex folder, extract insights from previous coding
  sessions, or says things like "process my Codex history", "add my Codex conversations to the wiki", or
  "what have I discussed in Codex before". Also triggers when the user mentions .codex sessions, rollout files,
  session_index.jsonl, or Codex transcript logs.
---

# Codex History Ingest — Conversation Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/codex.md` — the Codex adapter: history path (`CODEX_HISTORY_PATH`, default `~/.codex`), data layout, session index and rollout JSONL parsing, and gotchas.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest codex`.

Tool reference material stays at `references/codex-data-format.md` in this directory (linked from the adapter).

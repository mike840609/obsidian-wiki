---
name: copilot-history-ingest
description: >
  Ingest GitHub Copilot CLI session history into an Obsidian wiki as distilled knowledge pages. Use this skill
  when the user wants to capture their Copilot CLI sessions into a personal wiki — extracting architecture
  decisions, debug notes, and patterns into searchable Obsidian pages. Triggers on phrases like "ingest my
  copilot sessions into obsidian", "add my copilot history to my wiki", "pull my copilot session history into
  the vault", "capture what I've learned from copilot into obsidian", "just the new sessions since last time",
  or "mine patterns across my copilot sessions". Also triggers when the user mentions session-store.db,
  ~/.copilot/session-state, or VS Code copilot-chat transcripts in the context of building a wiki or knowledge
  base. Does NOT trigger for general copilot usage questions, searching sessions, or backing up history.
---

# Copilot History Ingest — Conversation Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/copilot.md` — the Copilot adapter: history paths (`COPILOT_HISTORY_PATH`, default `~/.copilot/session-state`, plus `session-store.db` and VS Code workspace storage), data layouts, SQLite queries, event JSONL parsing, and gotchas.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest copilot`.

Tool reference material stays at `references/copilot-data-format.md` in this directory (linked from the adapter).

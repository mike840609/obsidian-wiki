---
name: claude-history-ingest
description: >
  Ingest Claude Code conversation history into the Obsidian wiki. Use this skill when the user wants to mine
  their past Claude conversations for knowledge, import their ~/.claude folder, extract insights from
  previous coding sessions, or says things like "process my Claude history", "add my conversations to the wiki",
  "what have I discussed with Claude before". Also triggers when the user mentions their .claude folder,
  Claude projects, session data, past conversation logs, local-agent-mode sessions, or audit logs.
---

# Claude History Ingest — Conversation Mining

This skill is a thin wrapper. All logic lives in the adapter-driven `wiki-history-ingest` skill:

1. Read `.skills/wiki-history-ingest/SKILL.md` — the shared ingest procedure.
2. Read `.skills/wiki-history-ingest/adapters/claude.md` — the Claude adapter: history paths (`CLAUDE_HISTORY_PATH`, default `~/.claude`, plus desktop-app sessions), data layout, JSONL parsing, pre-extraction, sampling heuristics, and gotchas.
3. Execute the shared procedure with the adapter's specifics. Where the adapter extends or contradicts a shared step, the adapter wins.

Equivalent invocation: `/wiki-history-ingest claude`.

Tool reference material stays at `references/claude-data-format.md` in this directory (linked from the adapter).

# History Ingest Adapters

One data file per supported tool. Each adapter captures **only what varies between tools**; the shared ingest procedure lives once in `../SKILL.md`.

**Adding support for a new tool = adding one adapter file here** (plus, optionally, a thin wrapper skill directory for direct routing). No procedure logic is duplicated.

Each adapter provides these sections (omit any that don't apply):

| Section | What it holds |
|---|---|
| Config | History path env var(s) and default(s) |
| Before you start | Extra setup steps beyond the shared ones |
| Data layout | Directory/file structure of the tool's history |
| Sources ranked by value | What to read first |
| What to scan (Step 1) | Concrete globs/commands/queries for the survey, and the delta report format |
| Parsing and extraction (Step 2) | File formats, what to keep, what to skip |
| Clustering notes (Step 3) | Tool-specific grouping hints or constraints |
| Project naming (Step 4) | How to derive project names from the tool's metadata |
| Provenance guidance (Step 4) | Which of the tool's sources count as extracted vs inferred |
| Manifest and log (Step 5) | `source_type` values, summary block shape, log line format, hot.md example |
| Privacy extras | Tool-specific redaction rules |
| Reference | Pointer to the tool's `references/` data-format doc |

Adapters are data, not procedure. If you find yourself writing workflow steps in an adapter that would apply to every tool, hoist them into `../SKILL.md` instead.

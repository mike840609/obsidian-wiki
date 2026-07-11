#!/usr/bin/env bash
set -euo pipefail

# Claude Code SessionStart hook — prints the vault's hot.md to stdout so it
# lands in agent context at session start (warm start, no vault crawl).
#
# Config resolution order (mirrors llm-wiki/SKILL.md protocol):
#   1. Walk up from CWD looking for .env with OBSIDIAN_VAULT_PATH
#   2. Fall back to ~/.obsidian-wiki/config
#   3. Exit 0 silently if nothing resolves — never block session start

_find_config() {
  local dir="$PWD"
  while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.env" ]] && grep -q "OBSIDIAN_VAULT_PATH" "$dir/.env" 2>/dev/null; then
      echo "$dir/.env"
      return
    fi
    dir="$(dirname "$dir")"
  done
  [[ -f "$HOME/.obsidian-wiki/config" ]] && echo "$HOME/.obsidian-wiki/config"
  return 0
}

CONFIG_FILE="$(_find_config)"
[[ -n "$CONFIG_FILE" ]] || exit 0

# Extract the value without sourcing arbitrary code; strip surrounding quotes.
VAULT=$( (grep -E '^OBSIDIAN_VAULT_PATH=' "$CONFIG_FILE" || true) \
  | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

[[ -n "$VAULT" && -f "$VAULT/hot.md" ]] || exit 0

echo "## Wiki hot cache (auto-loaded from $VAULT/hot.md)"
echo ""
cat "$VAULT/hot.md"

#!/usr/bin/env bash
# Claude Code Toolkit — setup script
# Symlinks commands, builds Go tools, configures env vars

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "==> Setting up Claude Code Toolkit"
echo "    Repo:   $REPO_DIR"
echo "    Target: $CLAUDE_DIR"
echo ""

mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/scripts"

# --- Symlink commands ---
echo "==> Linking commands..."
for f in "$REPO_DIR/commands/"*.md; do
  name=$(basename "$f")
  target="$CLAUDE_DIR/commands/$name"
  if [[ -L "$target" ]]; then
    echo "  [skip]   commands/$name (already linked)"
  else
    [[ -f "$target" ]] && mv "$target" "$target.bak" && echo "  [backup] commands/$name"
    ln -s "$f" "$target"
    echo "  [linked] commands/$name"
  fi
done

# --- Build and install Go tools ---
echo ""
echo "==> Building Go tools..."
for tool_dir in "$REPO_DIR/tools/"/*/; do
  tool_name=$(basename "$tool_dir")
  if [[ ! -f "$tool_dir/go.mod" ]]; then
    continue
  fi
  echo "  [build]  $tool_name"
  (cd "$tool_dir" && go build -o "$CLAUDE_DIR/scripts/$tool_name" .)
  echo "  [ok]     ~/.claude/scripts/$tool_name"
done

# --- GitLab credentials ---
echo ""
SHELL_RC="$HOME/.zshrc"
[[ -f "$HOME/.bashrc" && ! -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.bashrc"

if grep -q "GITLAB_TOKEN" "$SHELL_RC" 2>/dev/null; then
  echo "==> GITLAB_TOKEN already set in $SHELL_RC, skipping."
else
  echo "==> GitLab credentials setup"
  read -rp "    GITLAB_HOST (e.g. https://gitlab.company.com): " GL_HOST
  read -rp "    GITLAB_TOKEN (Personal Access Token, needs read_api): " GL_TOKEN
  {
    echo ""
    echo "# Claude Code Toolkit — GitLab"
    echo "export GITLAB_HOST=$GL_HOST"
    echo "export GITLAB_TOKEN=$GL_TOKEN"
  } >> "$SHELL_RC"
  echo "  Saved to $SHELL_RC — run: source $SHELL_RC"
fi

echo ""
echo "==> Done! Available commands in Claude Code:"
for f in "$REPO_DIR/commands/"*.md; do
  echo "    /$(basename "$f" .md)"
done

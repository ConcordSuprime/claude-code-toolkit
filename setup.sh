#!/usr/bin/env bash
# Claude Code Toolkit — setup script
# Creates symlinks from this repo into ~/.claude/

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "==> Setting up Claude Code Toolkit"
echo "    Repo: $REPO_DIR"
echo "    Target: $CLAUDE_DIR"
echo ""

# Create target dirs
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/scripts"

# Symlink commands
for f in "$REPO_DIR/commands/"*.md; do
  name=$(basename "$f")
  target="$CLAUDE_DIR/commands/$name"
  if [[ -L "$target" ]]; then
    echo "  [skip]   commands/$name (already linked)"
  elif [[ -f "$target" ]]; then
    echo "  [backup] commands/$name -> commands/$name.bak"
    mv "$target" "$target.bak"
    ln -s "$f" "$target"
    echo "  [linked] commands/$name"
  else
    ln -s "$f" "$target"
    echo "  [linked] commands/$name"
  fi
done

# Symlink scripts
for f in "$REPO_DIR/scripts/"*; do
  name=$(basename "$f")
  target="$CLAUDE_DIR/scripts/$name"
  if [[ -L "$target" ]]; then
    echo "  [skip]   scripts/$name (already linked)"
  elif [[ -f "$target" ]]; then
    echo "  [backup] scripts/$name -> scripts/$name.bak"
    mv "$target" "$target.bak"
    ln -s "$f" "$target"
    echo "  [linked] scripts/$name"
  else
    ln -s "$f" "$target"
    echo "  [linked] scripts/$name"
  fi
done

# Make scripts executable
chmod +x "$REPO_DIR/scripts/"*.sh 2>/dev/null || true

echo ""

# Setup GitLab credentials
SHELL_RC="$HOME/.zshrc"
[[ -f "$HOME/.bashrc" && ! -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.bashrc"

if grep -q "GITLAB_TOKEN" "$SHELL_RC" 2>/dev/null; then
  echo "==> GITLAB_TOKEN already set in $SHELL_RC, skipping."
else
  echo "==> GitLab credentials setup"
  read -rp "    GITLAB_HOST (e.g. https://gitlab.company.com): " GL_HOST
  read -rp "    GITLAB_TOKEN (Personal Access Token, needs read_api): " GL_TOKEN
  echo "" >> "$SHELL_RC"
  echo "# Claude Code Toolkit — GitLab" >> "$SHELL_RC"
  echo "export GITLAB_HOST=$GL_HOST" >> "$SHELL_RC"
  echo "export GITLAB_TOKEN=$GL_TOKEN" >> "$SHELL_RC"
  echo "  Added to $SHELL_RC"
  echo "  Run: source $SHELL_RC"
fi

echo ""
echo "==> Done! Available commands in Claude Code:"
for f in "$REPO_DIR/commands/"*.md; do
  name=$(basename "$f" .md)
  echo "    /$name"
done

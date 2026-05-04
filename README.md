# Claude Code Toolkit

Shared Claude Code commands and Go tools for the team.

## Structure

```
commands/        # Claude Code slash commands (.md files)
tools/           # Go utilities, each in its own subdirectory
  gitlab-review/ # GitLab MR/commit fetcher for code review
setup.sh         # One-time setup: symlinks + builds tools + configures env
```

## Setup

```bash
git clone git@github.com:ConcordSuprime/claude-code-toolkit.git
cd claude-code-toolkit
bash setup.sh
source ~/.zshrc
```

The script will:
- Symlink `commands/` into `~/.claude/commands/`
- Build all Go tools from `tools/` and place binaries in `~/.claude/scripts/`
- Ask for your `GITLAB_HOST` and `GITLAB_TOKEN` and save them to `~/.zshrc`

## Available Commands

### `/mr-review <URL>`

Code review for a GitLab Merge Request or a specific commit.

```
# Full MR
/mr-review https://gitlab.company.com/group/project/-/merge_requests/42

# Specific commit
/mr-review https://gitlab.company.com/group/project/-/merge_requests/42/diffs?commit_id=abc123
```

Produces a structured report: Critical Issues / Warnings / Suggestions / Library Recommendations / Positive Notes.

## Keeping Up to Date

```bash
cd claude-code-toolkit
git pull
bash setup.sh   # rebuilds tools if needed
```

## GitLab Token

Create a Personal Access Token:
`https://YOUR_GITLAB_HOST/-/user_settings/personal_access_tokens`

Required scopes: `read_api`, `read_repository`

## Adding a New Tool

1. Create `tools/<tool-name>/` with `main.go` and `go.mod`
2. `setup.sh` will automatically build and install it on next run
3. Reference it in a command as `~/.claude/scripts/<tool-name>`

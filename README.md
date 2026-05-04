# Claude Code Toolkit

Shared Claude Code commands and scripts for the team.

## Setup

```bash
git clone https://github.com/YOUR_ORG/claude-code-toolkit.git
cd claude-code-toolkit
bash setup.sh
```

The script will:
- Symlink commands into `~/.claude/commands/`
- Symlink scripts into `~/.claude/scripts/`
- Ask for your `GITLAB_HOST` and `GITLAB_TOKEN` and add them to `~/.zshrc`

After setup, reload your shell:
```bash
source ~/.zshrc
```

## Available Commands

### `/mr-review <MR_URL>`

Code review for a GitLab Merge Request or specific commit.

**Examples:**
```
/mr-review https://gitlab.company.com/group/project/-/merge_requests/42
/mr-review https://gitlab.company.com/group/project/-/merge_requests/42/diffs?commit_id=abc123
```

**What it does:**
- Fetches MR diff, description, and `go.mod` via GitLab API
- Reviews against Go best practices
- Highlights where existing project libraries can be used
- Produces a structured report: Critical Issues / Warnings / Suggestions / Library Recommendations / Positive Notes

## Keeping Up to Date

```bash
cd claude-code-toolkit
git pull
```

Symlinks point to the repo files directly, so a `git pull` is all you need.

## GitLab Token

Create a Personal Access Token at:
`https://YOUR_GITLAB_HOST/-/user_settings/personal_access_tokens`

Required scopes: `read_api`, `read_repository`

## Structure

```
commands/        # Claude Code slash commands (.md files)
scripts/         # Helper scripts called by commands
setup.sh         # One-time setup: creates symlinks + configures env vars
```

## Adding New Commands

1. Add a `.md` file to `commands/`
2. Add any helper scripts to `scripts/`
3. Run `bash setup.sh` again to link the new files
4. Push to GitHub — teammates run `git pull` to get the update

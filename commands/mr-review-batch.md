Run inline code review on the last N merged MRs for a GitLab project.

Usage: /mr-review-batch <project_path> [branch] [N]

Examples:
- /mr-review-batch oes/core/go/barge-operations
- /mr-review-batch oes/core/go/barge-operations master 5

Arguments: $ARGUMENTS

## Step 1 — Parse arguments

Extract from "$ARGUMENTS":
- `project_path` (required, e.g. `oes/core/go/barge-operations`)
- `branch` (optional, default: `master`)
- `N` (optional, default: `10`)

## Step 2 — List merged MRs

Run:
```
~/.claude/scripts/gitlab-review list <project_path> <branch> <N>
```

This outputs lines: `<IID>\t<date>\t<author>\t<url>`

## Step 3 — Review each MR and post inline comments

For each MR URL from the list:

1. Fetch the MR data:
   ```
   ~/.claude/scripts/gitlab-review <MR_URL>
   ```

2. Review the diff using the Go architecture rules from your global CLAUDE.md:
   - Architecture violations (layer boundaries)
   - Critical bugs (silent errors, panics, data loss)
   - Warnings (incorrect error types, missing context propagation)
   - Suggestions (library recommendations, N+1 queries)

   **Skip:** empty lines, whitespace, gofmt-fixable formatting.

3. Build findings JSON (only items pinnable to a file+line in the diff):
   ```json
   {
     "findings": [
       {
         "file": "path/to/file.go",
         "line": 42,
         "line_type": "new",
         "severity": "critical|warning|suggestion",
         "body": "Explanation with corrected code example if applicable."
       }
     ]
   }
   ```

4. Post findings:
   ```
   echo '<JSON>' | ~/.claude/scripts/gitlab-review post <MR_URL>
   ```

   If a finding cannot be mapped to a specific line, skip it — do not post vague comments.

## Step 4 — Summary report

After processing all MRs, print a summary table:

| MR | Author | Posted | Failed | Top Issues |
|----|--------|--------|--------|------------|
| !21 | V.Korobov | 3 | 0 | silent error in handler, missing ctx |
| !19 | Vyacheslav Kim | 1 | 0 | N+1 query in service |

Note: each comment will be marked as `🤖 Claude Code Review` so authors know it's automated.

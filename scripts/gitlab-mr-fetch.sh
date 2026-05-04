#!/usr/bin/env bash
# Fetches GitLab MR or commit data for Claude code review
# Usage:
#   ./gitlab-mr-fetch.sh <MR_URL>
#   ./gitlab-mr-fetch.sh <MR_URL_with_commit_id>

URL="$1"
TOKEN="${GITLAB_TOKEN}"
HOST="${GITLAB_HOST:-https://oes-gitlab.oeswork.io}"

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <MR_URL or commit URL>"
  exit 1
fi

if [[ -z "$TOKEN" ]]; then
  echo "Error: GITLAB_TOKEN not set"
  exit 1
fi

# Temp files
TMP_MR=$(mktemp /tmp/mr_info.XXXXXX.json)
TMP_CHANGES=$(mktemp /tmp/mr_changes.XXXXXX.json)
TMP_GOMOD=$(mktemp /tmp/mr_gomod.XXXXXX.txt)
trap 'rm -f "$TMP_MR" "$TMP_CHANGES" "$TMP_GOMOD"' EXIT

# Parse project path (same for both URL types)
PROJECT_PATH=$(echo "$URL" | sed -E 's|https?://[^/]+/||' | sed -E 's|/-/.*||')
PROJECT_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PROJECT_PATH', safe=''))")
API="$HOST/api/v4/projects/$PROJECT_ENCODED"

# Detect mode: commit or MR
COMMIT_SHA=$(echo "$URL" | grep -oE 'commit_id=([a-f0-9]+)' | cut -d= -f2)

if [[ -n "$COMMIT_SHA" ]]; then
  # --- COMMIT MODE ---
  MR_IID=$(echo "$URL" | grep -oE 'merge_requests/[0-9]+' | grep -oE '[0-9]+')

  # Fetch commit info
  curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
    "$API/repository/commits/$COMMIT_SHA" > "$TMP_MR"
  if [[ ! -s "$TMP_MR" ]]; then
    echo "Error: could not fetch commit info" >&2; exit 1
  fi

  # Fetch commit diff
  curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
    "$API/repository/commits/$COMMIT_SHA/diff?per_page=50" > "$TMP_CHANGES"
  if [[ ! -s "$TMP_CHANGES" ]]; then
    echo "Error: could not fetch commit diff" >&2; exit 1
  fi

  # Get target branch from MR for go.mod
  if [[ -n "$MR_IID" ]]; then
    TARGET_BRANCH=$(curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
      "$API/merge_requests/$MR_IID" | python3 -c "import sys,json; print(json.load(sys.stdin)['target_branch'])" 2>/dev/null || echo "main")
  else
    TARGET_BRANCH="main"
  fi

  curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
    "$API/repository/files/go.mod/raw?ref=$TARGET_BRANCH" > "$TMP_GOMOD" 2>/dev/null \
    || echo "(go.mod not found)" > "$TMP_GOMOD"

  python3 /Users/il/.claude/scripts/gitlab-mr-format.py "$URL" "$TMP_MR" "$TMP_CHANGES" "$TMP_GOMOD" "commit" "$COMMIT_SHA"

else
  # --- MR MODE ---
  MR_IID=$(echo "$URL" | grep -oE '[0-9]+$')

  curl -sf --header "PRIVATE-TOKEN: $TOKEN" "$API/merge_requests/$MR_IID" > "$TMP_MR"
  if [[ ! -s "$TMP_MR" ]]; then
    echo "Error: could not fetch MR info (check token and URL)" >&2; exit 1
  fi

  curl -sf --header "PRIVATE-TOKEN: $TOKEN" "$API/merge_requests/$MR_IID/changes" > "$TMP_CHANGES"
  if [[ ! -s "$TMP_CHANGES" ]]; then
    echo "Error: could not fetch MR changes" >&2; exit 1
  fi

  TARGET_BRANCH=$(python3 -c "import json; d=json.load(open('$TMP_MR')); print(d['target_branch'])")
  curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
    "$API/repository/files/go.mod/raw?ref=$TARGET_BRANCH" > "$TMP_GOMOD" 2>/dev/null \
    || echo "(go.mod not found)" > "$TMP_GOMOD"

  python3 /Users/il/.claude/scripts/gitlab-mr-format.py "$URL" "$TMP_MR" "$TMP_CHANGES" "$TMP_GOMOD" "mr"
fi

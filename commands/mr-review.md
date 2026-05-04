Perform a Go code review for the GitLab MR at: $ARGUMENTS

First, run this shell command to fetch MR data:
```
~/.claude/scripts/gitlab-review "$ARGUMENTS"
```

Read the output and perform a thorough code review using the instructions below.
If the output contains a `CLAUDE.md (project architecture)` section — use it as the primary architecture reference for this project. Otherwise use the default architecture rules below.

---

## Go Code Review Instructions

You are an experienced Go developer performing a code review. Use the MR context to produce a structured review report.

**Do NOT report:** empty lines, whitespace/indentation, extra spaces, formatting issues that `gofmt` would fix automatically. Focus only on logic, correctness, and architecture.

### 1. Architecture Compliance

Check that the code follows the layered architecture:

```
handlers/  →  usecases/  →  service  →  repository
```

Violations to flag:
- Business logic inside HTTP handlers
- DB queries outside repository layer
- Handler calling repository directly (bypassing service)
- Usecase skipping service and going straight to repository
- Cross-domain dependencies (module A importing module B's internal types directly)

### 2. Go Best Practices

- Error handling: every error must be handled or explicitly ignored with a comment
- `context.Context` must be first argument and propagated through call chains
- Goroutines must have a clear owner and shutdown path via context
- Errors from all function calls must not be silently discarded (including cron `AddJob`, etc.)
- Interface usage: accept interfaces, return concrete types
- No global mutable state unless clearly justified

### 3. Error Handling Convention

- User-facing errors: use `gokittypes.NewBadRequest` / `gokittypes.NewNotFound`
- Plain `fmt.Errorf` → results in HTTP 500
- Handlers must unwrap with `errors.As(err, &clientErr)` to return correct status codes
- "Not found" from GORM (`gorm.ErrRecordNotFound`) must map to 404, not 500

### 4. Project Libraries — suggest using existing deps when relevant

- `go-chi/chi` — HTTP routing, middleware, route grouping
- `gorm.io/gorm` — ORM; use transactions, avoid N+1 queries, use `Preload` not manual joins
- `confluent-kafka-go` — Kafka; check producer/consumer lifecycle management
- `google/uuid` — UUID generation; prefer over manual ID generation
- `getsentry/sentry-go` — error reporting; important errors should be sent to Sentry
- `go-playground/validator` — struct validation; use instead of manual checks
- `hibiken/asynq` — async task queue; use for background jobs
- `robfig/cron/v3` — cron scheduler; `AddJob` returns error, must not ignore
- `oes-gitlab.oeswork.io/oes/go/go-kit` — internal toolkit; check if relevant helpers exist

### 5. Security

- No sensitive data in logs
- SQL only via GORM (no raw string concatenation)
- Input validation before processing

### 6. Observability

- Important operations should have log entries
- Errors should be reported to Sentry where appropriate

---

## Output Format

```markdown
# Code Review: <Title>

**Branch:** source → target
**Author:** name
**Reviewed files:** N

## Summary
One paragraph overall impression.

## Architecture Violations 🏗️
Cases where layer boundaries or project conventions are broken.

## Critical Issues 🔴
Bugs, data loss risks, panics, silent errors — must fix before merge.

## Warnings 🟡
Issues that should be fixed but are not blockers.

## Suggestions 💡
Nice-to-have improvements and refactoring ideas.

## Library Recommendations 📦
Specific places where existing project dependencies can be used instead of custom code.

## Positive Notes ✅
What was done well.
```

Save the review to `/tmp/mr-review-$MR_ID.md` and display the full content.

Perform a Go code review for the GitLab MR at: $ARGUMENTS

First, run this shell command to fetch MR data:
```
~/.claude/scripts/gitlab-review "$ARGUMENTS"
```

Read the output and perform a thorough code review using the instructions below.

---

## Go Code Review Instructions

You are an experienced Go developer performing a code review. Use the MR context to produce a structured review report.

### What to check

**Do NOT report:** empty lines count, whitespace/indentation style, extra spaces, formatting issues that `gofmt` would fix automatically. Focus only on logic, correctness, and architecture.

**1. Go Best Practices**
- Error handling: errors must be handled or explicitly ignored with a comment; avoid bare `_`
- No naked returns in long functions
- Context propagation: `context.Context` should be first arg and passed through call chains
- Goroutines: every goroutine must have a clear owner and shutdown path; check for leaks
- Defer correctness: watch for defer inside loops
- Interface usage: accept interfaces, return concrete types
- Naming: exported names must be clear without package prefix
- No global mutable state unless clearly justified

**2. Project Libraries — suggest using existing deps when relevant**
- `go-chi/chi` — HTTP routing, middleware, route grouping
- `gorm.io/gorm` — ORM; use transactions, avoid N+1 queries
- `confluentinc/confluent-kafka-go` — Kafka; check producer/consumer lifecycle management
- `google/uuid` — UUID generation; prefer over manual ID generation
- `getsentry/sentry-go` — error reporting; important errors should be sent to Sentry
- `go-playground/validator` — struct validation; use instead of manual checks
- `hibiken/asynq` — async task queue; use for background jobs
- `paulmach/orb` — geo types; use for coordinates instead of raw float64 pairs
- `oes-gitlab.oeswork.io/oes/go/go-kit` — internal toolkit; check if relevant helpers exist

**3. Architecture & Design**
- Separation of concerns: handler / service / repository layers must be respected
- No business logic in HTTP handlers
- Database queries only in repository layer
- No hardcoded values that should be config

**4. Security**
- No sensitive data in logs
- SQL via GORM only (no raw string concatenation)
- Input validation before processing

**5. Observability**
- Important operations should have log entries
- Errors should be reported to Sentry where appropriate

---

## Output Format

```markdown
# Code Review: <MR Title>

**Branch:** source → target
**Author:** name
**Reviewed files:** N

## Summary
One paragraph overall impression.

## Critical Issues 🔴
Issues that must be fixed before merge.

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

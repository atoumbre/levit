# Structured concurrency — implemented in 0.1.0

This former proposal is superseded by the shipped task contracts and
[cumulative migration guide](../MIGRATION_0.1.0.md#structured-tasks).

Controllers own a supervisor root. Workflow/child groups default to
`cancelOnError`; an explicit supervisor policy keeps siblings running. A group's
result waits for its body and all descendants, including cleanup. Only leaf
tasks consume slots, so coordination works with a single-slot engine. Deadlines
inherit the earliest limit and include queue time.

The pending queue defaults to 256 entries; `maxPending: null` explicitly opts out.
Joining/replacing pending entries does not consume another entry. Each priority
is FIFO; weighted scheduling prevents starvation. The six conflict policies
remain. Results are `Future<T>`; successful nullable data is not cancellation.
Typed outcomes distinguish success, failure, cancellation, dropping and supersession.

`LevitRetryPolicy` requires an error classifier and uses capped exponential
backoff with jitter; cancellation/deadline failures are not retried. Isolate
entrypoints propagate cancellation through their existing channel and drain exit.
Task-tree metadata is reactive; monitor integration is an optional app adapter.

See [save/upload](../examples/task_board/lib/save_upload.dart),
[task API](../packages/kits/levit_dart/lib/src/utilities/task_group.dart), and
[contract tests](../packages/kits/levit_dart/test/utilities/structured_task_contract_test.dart).
Cancellation remains cooperative. This is in-process structured work, not a
durable workflow scheduler. No compatibility layer for the old retry flags or
nullable cancellation results is retained.

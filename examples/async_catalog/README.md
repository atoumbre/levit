# Searchable async catalog

Run `flutter run -d chrome` from this package.
Run `flutter test` for deterministic controller and lifetime regressions.

The route owns `CatalogController`, which owns its repository, task engine and
LevitAsyncMap. Query keys contain search text and page number. Search resets to
page zero; previous/next navigation reuses retained pages. Refresh keeps the same
handle and shows retained rows while loading or reporting a failure.

Star a row to update an application-owned overlay immediately. Enable **Reject
next save** to see rollback; successful saves persist in the demo repository.
Concurrent saves for the same row are disabled. Mutation state belongs to the
controller, not the query framework. No network or credentials are required.

Repository delays support cancellation. Route cleanup waits for query/save task
finally blocks before closing the repository. Tests cover pagination, refresh
identity, immediate optimistic updates, rollback and cleanup ordering.

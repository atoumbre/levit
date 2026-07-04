# Agent instructions

When building, refactoring, reviewing, or explaining Levit code in this
repository, follow the project LLM guidance before improvising patterns.

## Which doc to read

| Situation | Document |
| :-- | :-- |
| Routine edits, quick orientation | [`LLM-Short.txt`](./LLM-Short.txt) |
| Scopes, stores, async DI, middleware, unfamiliar APIs | [`LLM.txt`](./LLM.txt) |
| Architecture rationale and tradeoffs | [`WHY_LEVIT.md`](./WHY_LEVIT.md) |
| Runnable reference patterns | [`examples/`](./examples) |
| Public API details | Inline DartDoc + package READMEs |

Start with `LLM-Short.txt`. Open `LLM.txt` when the short doc is not enough.

## Core rules (always)

1. Identify the lifetime boundary first (app, route, feature, subtree, test).
2. Prefer kit imports: `levit_flutter` (Flutter) or `levit` (pure Dart).
3. In Flutter widgets, resolve deps with `context.levit.find` — not bare
   `Levit.find` when an `LScope` is in the tree.
4. Call `Levit.enableAutoLinking()` in Flutter `main()` before `runApp`.
5. Keep business logic in controllers/stores; keep widgets thin.
6. Use `LWatch` for focused reactive rebuilds.

## Repo checks

```bash
melos run format
melos run analyze --no-select
melos run test --no-select
melos run test:flutter --no-select
melos run ci --no-select
```

When changing public APIs, update DartDoc and the relevant package README.

# Contributing to Levit

First off, thank you for considering contributing to Levit! It's people like you that make Levit such a great tool for the community.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct. Please act professionally and respectfully at all times.

## How Can I Contribute?

### Reporting Bugs

-   **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/softilab/levit/issues).
-   If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/softilab/levit/issues/new). Be sure to include a **title and clear description**, as well as as much relevant information as possible, and a **code sample** or an **executable test case** demonstrating the expected behavior that is not occurring.

### Suggesting Enhancements

-   Open a new issue with the **enhancement** label.
-   Explain why this enhancement would be useful to most Levit users.

### Pull Requests

1.  Fork the repo and create your branch from `main`.
2.  If you've added code that should be tested, add tests.
3.  If you've changed APIs, update the relevant documentation (`README.md`, package READMEs, and inline DartDoc as needed).
4.  Ensure formatting, analysis, and tests pass before opening the PR.

## Development Setup

Levit is a monorepo managed by **Melos**.

### Prerequisites

-   Dart SDK
-   Flutter SDK
-   Melos (`dart pub global activate melos`)

### Bootstrap

To link all local packages and install dependencies:

```bash
melos bootstrap
```

### Running Checks

Use the workspace scripts from the repository root:

```bash
melos run ci --no-select
melos run coverage --no-select
melos run publish:dry-run --no-select
```

For focused local checks, use:

```bash
melos run analyze --no-select
melos run test --no-select
melos run test:flutter --no-select
```

## Style Guide

-   We follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
-   We value **explicit over implicit**. Code should be easy to read and understand.
-   We prioritize **correctness over convenience**.

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

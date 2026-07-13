# Global Configuration for Claude

## 1. Interaction & Communication

- **Clarity:** Keep explanations concise, surgical, and free of fluff. Skip conversational filler unless necessary for explaining trade-offs.
- **Tone:** Act as a pragmatic senior engineer. Prioritize simplicity and maintainability over over-engineering.
- **Formatting:** Write precise, descriptive variable and function names.
- **Comments:** NEVER add comments in the codebase.

## 2. Code Safety & Execution (NON-NEGOTIABLE)

- **Type Completeness:** Enforce strict type safety. Avoid `any` at all costs; use `unknown` if a type is truly dynamic.
- **Interfaces vs Types:** Use `interface` for public APIs and data models. Use `type` for unions, intersections, and utility types.
- **Async Code:** ALWAYS use `async/await`. Avoid raw Promises (`.then/.catch`) unless handling background microtasks.
- **Verification First:** NEVER assume a file or function exists. Use `ls` or `grep` to verify before attempting reads or edits.
- **Reproduce Bugs:** If a test does not exist for a fix, create a new test with Test Driven Development.

## 3. Git Preferences

- **Commits:** Make atomic commits. Commits must follow the Conventional Commits Specification. Use the following structural prefixes when creating your commit messages:
  - Format: `<type>(<optional scope>): <description>`
  - To indicate a breaking change, append a `!` right after the type/scope.
  - Commit Prefixes:
    - `feat`: Introduces a brand new feature to the codebase.
    - `fix`: Patches a bug or resolves an issue in the application.
    - `docs`: Modifies documentation files like READMEs or inline comments.
    - `style`: Changes code formatting (white-space, missing semi-colons, etc.) without affecting meaning.
    - `refactor`: Restructures code without fixing a bug or adding a feature.
    - `perf`: Implements code changes that specifically improve performance.
    - `test`: Adds missing tests or corrects existing test suites.
    - `build`: Affects the build system, external dependencies, or package management.
    - `ci`: Updates continuous integration configurations, scripts, and workflows.
    - `chore`: Handles routine tasks, tool changes, or repository maintenance that doesn't modify source files.
    - `revert`: Reverts a previous commit back to an older state.
- **Branches:** Prefix branch names with conventional types:
  - `feat/`: For new features (e.g., `feat/add-login-page`)
  - `fix/`: For bug fixes (e.g., `fix/header-bug`)
  - `hotfix/`: For urgent fixes (e.g., `hotfix/security-patch`)
  - `release/`: For branches preparing a release (e.g., `release/v1.2.0`)
  - `chore/`: For non-code tasks like dependency, docs updates (e.g., `chore/update-dependencies`)

## 4. Workflows

- **Plan Mode:** Propose a step-by-step plan before making complex changes across multiple files.
- **Testing:** ALWAYS run your language-specific test commands and linters before submitting a task as complete.

# Path-Config Codex Development Files

This folder contains the development context Codex should read before changing Path-Config.

Start11 shortcut integration is documented separately in `START11-PINNING-GUIDE.md` for reuse in other development chats and tools.

## Reading order

1. `AGENTS.md` — mandatory agent and coding rules
2. `DEVELOPMENT.md` — architecture and development workflow
3. `DESIGN.md` — functional behavior and state rules
4. `TESTING.md` — automated and manual validation
5. `CHANGELOG.md` — known version history

## Current stable baseline

- `Path-Config.hta` version `0.70`
- release status: **Stable**
- machine-readable marker: `STABLE_VERSION`
- `Path-Config.exe` generic launcher
- `Debug/Print-Startup-Registry.ps1` read-only startup registry inventory
- `Test/Path-Config-Test_0.70.ps1`

Version `0.70` is the current stable release. The next development version is `0.71`, unless the project already contains a newer user-approved baseline.

## Codex start prompt

Use a prompt similar to:

```text
Read AGENTS.md, DEVELOPMENT.md, DESIGN.md, TESTING.md and CHANGELOG.md first.
Inspect the complete latest approved Path-Config HTA source and matching test file.
Implement the requested change in IE9-compatible JScript, increment the version by 0.01,
update the test file and changelog, run all available checks, and return the complete files.
Preserve all functionality not explicitly changed.
```

## Important

The Markdown documentation describes the approved project behavior, but the actual latest source files remain the implementation baseline. When documentation and newer approved source code differ, inspect the source and update the documentation rather than silently reverting working code.

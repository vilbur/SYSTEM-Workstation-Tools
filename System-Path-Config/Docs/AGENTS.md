# Path-Config Codex Agent Instructions

## Project

Path-Config is a standalone AutoHotkey v1 application for storing and applying Windows path-related configuration.

Current approved baseline:

- `Path-Config.ahk`
- `Path-Config-Test_0.04.ahk`

Continue development only from the latest approved baseline. Never rebuild from memory when the current source files are available.

## Mandatory workflow

1. Read all project Markdown files before editing code.
2. Inspect the complete latest `.ahk` source and test file.
3. Preserve all existing functionality unless the task explicitly removes it.
4. Increment the version by exactly `0.01` for every delivered code change.
5. Keep the canonical source filename as `Path-Config.ahk` and update all matching version references:
   - test filename
   - internal version string
   - GUI version label
   - test expectations
   - changelog
6. Deliver the complete updated `.ahk` file, not patch snippets, when more than two code areas change.
7. Keep the application standalone. Do not add external `#Include` dependencies.
8. Update `Path-Config.ahk` in place only when the user has approved the new version; keep Git history as the recoverable baseline.
9. Verify the actual delivered files before claiming completion.

## AutoHotkey language requirements

This project uses AutoHotkey v1, not AutoHotkey v2.

Required:

- Use AutoHotkey v1 command and expression syntax.
- Function declarations use `functionName(parameters)` syntax.
- Never write the word `function` before a function declaration.
- Never write `then` after `if`.
- Avoid AutoHotkey v2-only functions and syntax.
- Avoid undefined helper functions.
- Preserve labels required by GUI `gLabel` handlers.
- Keep opening and closing braces balanced.
- Use `UseErrorLevel` where command failure must be detected.
- Quote file paths safely.

## UI rules

Preserve the current dark UI style:

- Segoe UI
- approximately 16 px outer margins
- approximately 26–32 px control height
- dark edits and controls
- fake text-based dark buttons where already used
- highlighted `CONFIG` and `APPLY` mode controls
- consistent row alignment

The fixed first tab is always named `Paths`.

The `Paths` tab:

- must remain the first tab
- is not dynamic
- cannot be renamed
- cannot be deleted
- must not shift or corrupt internal dynamic program-tab indices

## Fixed Paths row data

Each persistent row contains exactly these logical fields:

- `path`
- `env_var`
- `run_as_admin`
- `run_on_startup`

The row UI contains:

- file path edit
- Browse button
- Env var edit
- Run as Admin checkbox
- Run on startup checkbox
- Delete button for rows after the first

At least one row must always exist.

## Apply behavior

Applying fixed Paths rows must process every row independently.

Environment variable:

- write non-empty variable names to `HKCU\Environment`
- value is the row file path
- broadcast the Windows environment-change message after changes

Run as Admin:

- launch the selected file immediately during apply
- use AutoHotkey v1 elevation behavior such as `*RunAs`
- report missing or invalid paths as errors

Run on startup:

- manage current-user startup entries under:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- use only the dedicated value-name prefix owned by Path-Config:
  `PathConfig_Path_`
- remove obsolete Path-Config-owned startup entries during apply
- never delete unrelated startup values
- when Run as Admin and Run on startup are both enabled, the startup command must request elevation

`APPLY PATHS` applies only the fixed Paths rows.

`APPLY ALL` applies fixed Paths rows and all dynamic program tabs.

## Persistence rules

The main settings file is `Path-Config.ini`.

Fixed rows are stored independently in `[PersistentPaths]`.

Version 0.04 fields use keys equivalent to:

- `<row>_Path`
- `<row>_EnvVar`
- `<row>_RunAsAdmin`
- `<row>_RunOnStartup`

Preserve migration from version 0.03, where each row may exist as a plain numeric key containing only the path.

Do not change existing dynamic program-tab INI sections unless the task explicitly requires it.

## Dynamic program tabs

Dynamic program tabs remain separate from the fixed `Paths` tab.

They support existing sections for:

- Paths
- environment variables
- executables
- links
  - shortcut
  - symlink
  - hardlink

Preserve add, rename, delete, save, load, apply, and migration behavior.

## Safety rules

- Do not delete arbitrary registry values.
- Do not delete arbitrary files.
- Do not modify startup entries without the `PathConfig_Path_` prefix.
- Do not apply configurations from the automated parser/static test.
- Do not require administrator privileges merely to open the manager UI.
- Elevate only the specific requested launch action.

## Required validation before delivery

Run or perform all available checks:

1. AutoHotkey v1 parser test.
2. Static required-string/function checks.
3. GUI label-reference checks.
4. Brace and quote balance checks.
5. INI save/load field checks.
6. v0.03 migration checks.
7. Startup prefix isolation checks.
8. Confirm no external includes.
9. Confirm no AHK v2 syntax.
10. Confirm both delivered files contain the correct new version.

Report honestly when Windows runtime testing could not be executed.

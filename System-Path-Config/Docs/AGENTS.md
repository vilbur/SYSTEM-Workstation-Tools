# Path-Config Codex Agent Instructions

## Project

Path-Config is a standalone Windows HTA application (HTML and legacy-compatible JScript) for storing and applying Windows path-related configuration. `Path-Config.exe` is a generic launcher that loads the adjacent HTA source.

Current approved baseline:

- `Path-Config.hta` version `0.29`
- `Path-Config.exe`
- `Test/Path-Config-Test_0.29.ps1`

Continue development only from the latest approved baseline. Never rebuild from memory when the current source files are available.

## Mandatory workflow

1. Read all project Markdown files before editing code.
2. Inspect the complete latest `.hta` source and test file.
3. Preserve all existing functionality unless the task explicitly removes it.
4. Increment the version by exactly `0.01` for every delivered code change.
5. Keep the canonical source filename as `Path-Config.hta` and update all matching version references:
   - test filename
   - internal version string
   - GUI version label
   - test expectations
   - changelog
6. Deliver the complete updated `.hta` file, not patch snippets, when more than two code areas change.
7. Keep the application standalone. Do not add external web, script, or package dependencies.
8. Update `Path-Config.hta` in place only when the user has approved the new version; keep Git history as the recoverable baseline.
9. Verify the actual delivered files before claiming completion.

## HTA and JScript requirements

Required:

- Keep JScript compatible with the Internet Explorer 9 HTA engine.
- Avoid modern JavaScript syntax and browser APIs unsupported by that engine.
- Keep all runtime code inside the standalone HTA.
- Avoid undefined helper functions and preserve handlers referenced from generated HTML.
- Keep opening and closing braces and quotes balanced.
- Use guarded COM calls and report operational failures.
- Quote filesystem and command-line paths safely.
- Run background status checks and maintenance commands with hidden window style `0`; only user-requested target launches and pickers may be visible.
- maintain the cooperative launcher heartbeat/relaunch bridge; stable source updates reload the HTA after unsaved edits are saved

## UI rules

Preserve the current dark UI style:

- Segoe UI
- approximately 16 px outer margins
- approximately 26–32 px control height
- dark edits and controls
- fake text-based dark buttons where already used
- highlighted `CONFIG` and `APPLY` mode controls
- consistent row alignment
- maximized file-path edits in path rows, with exact 16 px horizontal gaps and no inherited control margins between adjacent controls
- larger icon-only Config-mode checkboxes

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
- Browse button using full-PC native file/folder dialogs
- first browse starts at `C:\`; later dialogs in the same session start at the last selected directory
- Env var edit
- Run as Admin checkbox
- Run on startup checkbox
- fixed-size burger menu opened by either left-click or right-click, with Move to New Tab and Delete Row actions; Delete Row remains disabled for the first row
- one leftmost ordering button: left-click moves down and right-click moves up
- right-click context-menu suppression on the ordering button
- cursor follow-up to the merged ordering button on the moved row
- left edge alignment for the ordering button and right edge alignment for the burger menu

At least one row must always exist.

## Apply behavior

Applying fixed Paths rows must process every row independently.

Environment variable:

- write non-empty variable names to `HKCU\Environment`
- value is the row file path
- broadcast the Windows environment-change message after changes

Run as Admin:

- manage the per-user `RUNASADMIN` compatibility property under `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
- add or remove only the `RUNASADMIN` token while preserving other compatibility flags
- require an existing `.exe` when enabling the property
- perform property status checks without flashing a console window
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

Their Paths section uses the same row controls as the fixed tab:

- file path and Browse
- environment variable
- Run as Admin
- Run on startup
- Delete for rows after the first

They also preserve the existing sections for environment variables, executables, and links (shortcut, symlink, and hardlink). Existing dynamic `_Name`/`_Val` path rows must migrate into the new path-row fields.

Preserve add, rename, delete, save, load, apply, and migration behavior.

## Safety rules

- Do not delete arbitrary registry values.
- Do not delete arbitrary files.
- Do not modify startup entries outside the application-owned `PathConfig_Path_` and `PathConfig_Program_` prefixes.
- Do not apply configurations from the automated parser/static test.
- Do not require administrator privileges merely to open the manager UI.
- Elevate only the specific requested launch action.

## Required validation before delivery

Run or perform all available checks:

1. Windows JScript parser test of the embedded script.
2. Static required-string/function checks.
3. Generated-HTML handler-reference checks.
4. Brace and quote balance checks.
5. INI save/load field checks.
6. v0.03 migration checks.
7. Startup prefix isolation checks.
8. Confirm no external dependencies.
9. Confirm background command capture uses hidden window style `0` and does not use `WScript.Shell.Exec`.
10. Confirm the source and matching test contain the correct new version.

Report honestly when Windows runtime testing could not be executed.

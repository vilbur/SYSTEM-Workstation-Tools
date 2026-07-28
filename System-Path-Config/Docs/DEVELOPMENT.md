# Path-Config Development Guide

## Current baseline

The latest approved version is `0.29`.

Primary files:

- `Path-Config.hta`
- `Path-Config.exe` (generic HTA launcher)
- `Test/Path-Config-Test_0.29.ps1`
- `Path-Config.ini` at runtime

The next code delivery must be version `0.30` unless another version has already been approved in the repository.

## Product purpose

Path-Config is a Windows configuration manager implemented as a standalone HTA with Internet Explorer 9-compatible JScript. It stores reusable path-related settings and applies them through a dark GUI.

There are two configuration areas:

1. A fixed, non-dynamic first tab named `Paths`.
2. Dynamic program tabs whose Paths section mirrors the fixed Paths row controls, followed by the existing environment-variable, executable, and link sections.

## High-level runtime flow

1. Start the script.
2. Load the INI file and migrate legacy data when necessary.
3. Build the fixed `Paths` tab as UI tab index 1.
4. Build dynamic program tabs after it.
5. Preserve separate internal indexing for dynamic tabs.
6. Allow editing in `CONFIG` mode.
7. Present apply actions in `APPLY` mode.
8. Capture visible control values before tab changes, reloads, saves, or applies.
9. Save current data and selected tab state.
10. Apply only the requested scope.
11. Maintain heartbeat and relaunch-request files for the cooperative launcher bridge, and reload the HTA after a stable source update once no unsaved edits remain.

## State model

Important global state is expected to include equivalents of:

- script version
- INI path
- legacy INI path
- current mode
- current UI tab
- current dynamic program tab
- dynamic tab names
- dynamic tab data
- persistent Paths rows
- GUI handles and theme values

The fixed UI tab index and dynamic program-tab index are different concepts.

Recommended invariant:

- UI tab 1 is `Paths`.
- UI tab N greater than 1 maps to dynamic tab index `N - 1`.

Never use the UI index directly to access dynamic tab data.

## Persistent Paths row schema

Conceptual object:

```text
{
    path: "C:\\Path\\Program.exe",
    env_var: "PROGRAM_EXE",
    run_as_admin: 0 or 1,
    run_on_startup: 0 or 1
}
```

Rules:

- Empty rows are allowed while editing.
- The first row cannot be deleted.
- Additional rows can be added and deleted.
- Browse uses a full-PC native dialog, starts at `C:\` on first use, and reuses the last selected directory for later file and folder dialogs in the current session.
- The environment-variable name is optional.
- Both checkboxes are independent.

## Dynamic program path rows

Each Programs tab stores path rows with the same four logical fields as a persistent row. Loading accepts the former `<row>_Name` and `<row>_Val` keys as migration sources for `env_var` and `path`. Program startup entries use the separate `PathConfig_Program_` prefix and are reconciled within the selected tab, or globally before Apply All.

## Apply scope

### Apply Paths

Processes only fixed Paths rows.

For every row:

1. Read and trim all four fields.
2. Write the environment variable when both name and path are non-empty.
3. Create a managed startup entry when enabled and valid.
4. Set or remove the Windows `RUNASADMIN` compatibility property for configured executable paths.
5. Accumulate success and error counts.
6. Broadcast environment changes once after processing all rows.

### Apply Current Tab

Applies only the selected dynamic program tab.

When `Paths` is selected, the fixed Paths-specific apply action should be used instead of treating it as a dynamic tab.

### Apply All

1. Apply fixed Paths rows.
2. Apply every dynamic program tab.
3. Broadcast environment changes once when anything changed.
4. Report persistent-row errors without hiding dynamic configuration results.

## Startup ownership

Path-Config owns only registry values whose names start with:

```text
PathConfig_Path_
```

On apply:

1. Enumerate current-user Run values.
2. Collect only values with the owned prefix.
3. Remove those owned values.
4. Recreate values for currently enabled rows.

This prevents stale entries and avoids touching unrelated startup software.

## Environment variables

Target:

```text
HKCU\Environment
```

The user-provided Env var text is the registry value name.

The selected path is the registry value data.

After one or more successful changes, broadcast `WM_SETTINGCHANGE` with `Environment` to notify Windows applications.

## Administrator compatibility property and startup elevation

Apply behavior:

- store per-user executable compatibility flags under `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
- add or remove only the `RUNASADMIN` token while preserving unrelated flags
- query, write, and delete compatibility values through hidden commands so status rendering does not flash a console window

Elevated startup:

- use a startup command capable of requesting `RunAs`
- PowerShell `Start-Process -Verb RunAs` is acceptable in the current design
- quote and escape apostrophes and spaces safely

Expected Windows behavior: an elevated startup row may produce a UAC prompt after login.

## Migration

Version 0.03 stored fixed paths as plain numbered values in `[PersistentPaths]`.

Version 0.04 stores four keys per row.

Loading must:

1. Try `<row>_Path`.
2. Fall back to the old numeric `<row>` key.
3. Default missing new fields to empty or false.
4. Convert the loaded row into the current object schema.
5. Ensure one empty row exists when nothing was loaded.

## Change procedure

For each requested update:

1. Confirm the latest approved version in the actual files.
2. Keep the source filename `Path-Config.hta` and create the matching next-version PowerShell test file under `Test/`.
3. Update internal and visible version markers.
4. Implement the smallest coherent change.
5. Update migration only when persistence changes.
6. Expand the test script for every new control, field, handler, and action.
7. Run static and parser validation.
8. Inspect generated files directly.
9. Update `CHANGELOG.md`.
10. Deliver complete files.

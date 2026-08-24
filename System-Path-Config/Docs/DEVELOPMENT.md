# Path-Config Development Guide

## Current stable baseline

The latest approved stable version is `0.70`. The root `STABLE_VERSION` marker must remain `0.70` until the user explicitly promotes a newer release.

Primary files:

- `Path-Config.hta`
- `Path-Config.exe` (generic HTA launcher)
- `Debug/Print-Startup-Registry.ps1` (read-only startup registry inventory)
- `Test/Path-Config-Test_0.70.ps1`
- `Path-Config.ini` at runtime

The next code delivery must be version `0.71` unless another version has already been approved in the repository.

## Product purpose

Path-Config is a Windows configuration manager implemented as a standalone HTA with Internet Explorer 9-compatible JScript. It stores reusable path-related settings and applies them through a dark GUI.

There are two configuration areas:

1. A fixed, non-dynamic first tab displayed as `Common`.
2. Dynamic program tabs whose Paths section mirrors the fixed Paths row controls, followed by the existing environment-variable, executable, and link sections.

## High-level runtime flow

1. Start the script.
2. Load the INI file and migrate legacy data when necessary.
3. Build the fixed `Common` tab as UI tab index 1.
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

- UI tab 1 is `Common`.
- UI tab N greater than 1 maps to dynamic tab index `N - 1`.

Never use the UI index directly to access dynamic tab data.

## Persistent Paths row schema

Conceptual object:

```text
{
    path: "C:\\Path\\Program.exe",
    env_var: "PROGRAM_EXE",
    run_as_admin: 0 or 1,
    run_on_startup: 0 or 1,
    menu: 0 or 1
}
```

Rules:

- Empty rows are allowed while editing.
- The first row cannot be deleted.
- Additional rows can be added and deleted.
- Browse uses Windows Forms `OpenFileDialog` for files and the native Windows `IFileOpenDialog` Common Item Dialog in folder-selection mode for folders, both with full-PC access. A populated path field supplies its own folder as the initial location; an empty field falls back to the last successfully selected directory, or `C:\` before any selection. A centralized post-selection sanitizer capitalizes direct drive letters for every browsed path and gives folder results exactly one trailing backslash. In Config mode, typed path-like values use the same drive-letter rule and gain a trailing backslash when their expanded value is an existing directory; raw `%NAME%` references remain intact. Every file/folder picker button also exposes `Find in Explorer` on right-click; the action reads its adjacent live field, expands configured and Windows environment references, validates the target, and opens visible Explorer with it selected.
- File Path remains at least 560 px wide; Environment Variable uses its restored 20% column and Links Link Name keeps its earlier 15% column. Fixed Paths and all dynamic-tab table actions use compact fixed-width columns sized to their controls, so the 10 px padding on each adjacent cell produces an exact visible 20 px gap; the first and last controls align flush to the left and right row edges. The window is capped at half the available display width, with horizontal scrolling retained when the minimum layout is wider. Switching between the fixed and dynamic tabs must preserve the current outer window size and must not invoke content fitting. Section Add buttons sit beside their labels on the left.
- The environment-variable name is optional.
- All three checkboxes are independent.

## Dynamic program path rows

Each Programs tab stores path rows with the same five logical fields as a persistent row. Loading accepts the former `<row>_Name` and `<row>_Val` keys as migration sources for `env_var` and `path`. Program startup entries use the separate `PathConfig_Program_` prefix and are reconciled within the selected tab, or globally before Apply All.

## Apply scope

Every error-free Apply action redraws the selected Apply-mode view from live Windows state with ender(true), preserving the current outer window size. Apply Paths and Apply All retain their earlier ordinary redraw when errors occur so partial state remains visible; a failed selected-tab Apply keeps its current view while the result alert reports errors.

### Apply Paths

Processes only fixed Paths rows.

For every row:

1. Read and trim all five fields.
2. Write the environment variable when both name and path are non-empty.
3. Create a managed startup entry when enabled and valid.
4. Set or remove the Windows `RUNASADMIN` compatibility property for configured executable paths.
5. Accumulate success and error counts.
6. Broadcast environment changes once after processing all rows.

### Apply Current Tab

Applies only the selected dynamic program tab.

When `Common` is selected, the fixed Paths-specific apply action should be used instead of treating it as a dynamic tab.

### Apply All

1. Apply fixed Paths rows.
2. Apply every dynamic program tab.
3. Broadcast environment changes once when anything changed.
4. Report persistent-row errors without hiding dynamic configuration results.

## Startup ownership and existing entries

Path-Config owns Run values whose names start with `PathConfig_Path_` or `PathConfig_Program_`. Those values and their approval records are reconciled only inside the selected prefix scope.

Before creating an owned fallback for a row, Path-Config resolves every non-owned current-user Run command to its executable target. One exact normalized path match is reused without changing its value name, data type, command, or arguments. Path-Config writes only that value name's `StartupApproved\Run` state: `020000000000000000000000` for On, or `03` plus reserved bytes and a current FILETIME for Off. Multiple exact matches are treated as ambiguous and left unchanged.

If no non-owned match exists, checked rows retain the earlier owned Run-value behavior. Unchecked rows leave no owned value after scoped cleanup. Apply-mode STARTUP status reads the same live Run and StartupApproved data, treating a Run value without an approval record as On, which mirrors Windows Settings > Apps > Startup.

## Environment variables

Target:

```text
HKCU\Environment
```

The user-provided Env var text is the registry value name. Path values may contain native `%NAME%` references.

For validation and actions, Path-Config builds a case-insensitive variable map from fixed path rows, every Programs path row, and every Programs Environment Variables row. It follows Apply All order, so later Path-Config definitions win, and only then falls back to the current Windows process environment. Nested values are resolved recursively; unknown and cyclic references remain unresolved.

Raw values remain in the INI. Registry values containing `%NAME%` are written as `REG_EXPAND_SZ`; plain values remain `REG_SZ`.

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

## Start11 Menu pins

When Menu is enabled, Path-Config accepts an existing `.exe` or an existing `.lnk` whose target exists. Executables and configured `.lnk` files use one canonical unsuffixed shortcut name under the current user pinned Start Menu directory. Before addition, Path-Config removes registry entries that reference a same-name conflicting shortcut, deletes that conflicting file, and removes other pinned-directory shortcuts with the requested target-and-arguments signature. It then creates or copies the canonical shortcut while preserving configured shortcut targets and arguments. A correct existing canonical shortcut and its custom-group registration are reused.

Apply synchronizes the checkbox with live Start11 state. Checked rows are ensured present, including detection of items moved into custom Start11 groups; unchecked rows remove numeric registrations recursively from the Start11 group trees and delete only pinned-directory shortcuts with the exact same resolved target and arguments. Every operation refreshes registry state and verifies the result. When Admin is enabled, a shortcut must resolve to an executable; the executable RUNASADMIN property is set and verified on that target before the shortcut is accepted.
## Migration

Version 0.03 stored fixed paths as plain numbered values in `[PersistentPaths]`.

Current rows store five logical fields; older files without `_Menu` load it as false.

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

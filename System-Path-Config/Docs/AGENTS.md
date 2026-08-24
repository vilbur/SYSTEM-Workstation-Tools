# Path-Config Codex Agent Instructions

## Project

Path-Config is a standalone Windows HTA application (HTML and legacy-compatible JScript) for storing and applying Windows path-related configuration. `Path-Config.exe` is a generic launcher that loads the adjacent HTA source.

Current approved baseline:

- `Path-Config.hta` version `0.65`
- `Path-Config.exe`
- `Test/Path-Config-Test_0.65.ps1`

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
- render Save State as two distinct states: clean uses grey font, default cursor, resting v0.39 surface, no hover response, and no click handler; dirty restores the original v0.39 base class, white font, pointer/hover behavior, and direct save action; never use the native disabled attribute; auto-save pending Config edits before entering Apply and remain in Config if saving fails
- in IE9-mode HTA, track input, keyup, propertychange, and change so typing/pasting immediately marks real value changes dirty; filter non-value property events
- consistent row alignment
- a window no wider than half the display, file-path edits at least 560 px wide, restored 20% Environment Variable columns, preserved 15% Config-mode Link Name columns and compact Source/Link path/Type Links rows in Apply mode, compact fixed-width row-action columns across fixed Paths and every dynamic-tab section that produce exact visible 20 px gaps, flush outer controls, section Add buttons beside their labels on the left, and no inherited control margins
- preserve the exact current outer window size when switching tabs; tab selection must not schedule content fitting, resizing, or recentering
- larger icon-only Config-mode checkboxes
- ADMIN, STARTUP, and MENU headers use 8 px side padding for 16 px between adjacent labels and are orange, green, and blue respectively
- every path-row checkbox exposes an action-specific tooltip
- Apply-mode Boolean status values are icon-only: render YES as a green `✔` when matching or a red `✘` when mismatching; render every NO and N/A state as a blank cell while preserving its match/mismatch class and tooltip
- orange Source and Link folder/path values when the Source item's containing directory matches the configured Link folder

The fixed first tab is always displayed as `Common`. Its existing persistent-path storage and apply scope remain unchanged.

The `Common` tab:

- must remain the first tab
- is not dynamic
- cannot be renamed
- cannot be deleted
- must not shift or corrupt internal dynamic program-tab indices
- remains permanently first while program tabs may be reordered left or right and retain their complete data and active selection

## Fixed Paths row data

Each persistent row contains exactly these logical fields:

- `path`
- `env_var`
- `run_as_admin`
- `run_on_startup`
- `menu`

The row UI contains:

- file path edit
- Browse button using native Windows Forms file/folder dialogs with full-PC access
- Browse starts at the current field path when populated; an empty field uses the last selected directory, falling back to `C:\` before any selection; every returned path capitalizes its drive letter and folder results end with one trailing backslash
- in Config mode, every path-like edit capitalizes a direct drive letter and gains a trailing backslash when its expanded value is an existing directory; raw `%NAME%` references remain intact
- every file/folder Browse button opens a right-click menu containing `Find in Explorer`; it reads the adjacent live path, expands `%NAME%` references, and selects an existing target in Explorer
- Env var edit
- Run as Admin checkbox
- Run on startup checkbox
- Menu checkbox
- fixed-size burger menu opened by either left-click or right-click, with Move to New Tab and Delete Row actions; Delete Row remains disabled for the first row
- one rightmost ordering button: left-click moves down and right-click moves up
- right-click context-menu suppression on the ordering button
- cursor follow-up to the merged ordering button on the moved row
- left edge alignment for the burger menu and right edge alignment for the ordering button

At least one row must always exist.

## Apply behavior

Applying fixed Paths rows must process every row independently.

Environment variable:

- accept native `%NAME%` references in every path-like field, including `%username%` and `%GoogleDrive%`
- resolve names case-insensitively and recursively, leaving unknown or cyclic references safely unresolved
- collect variables from fixed path rows, Programs path rows, and Programs Environment Variables sections
- give Path-Config definitions priority over existing Windows environment variables; within Path-Config, later definitions in Apply All order win
- preserve raw `%NAME%` references in the INI and write expandable environment values as `REG_EXPAND_SZ`
- write non-empty variable names to `HKCU\Environment`
- broadcast the Windows environment-change message after changes

Run as Admin:

- manage the per-user `RUNASADMIN` compatibility property under `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
- add or remove only the `RUNASADMIN` token while preserving other compatibility flags
- require an existing `.exe` when enabling the property
- perform property status checks without flashing a console window
- report missing or invalid paths as errors

Start11 Menu:

- when Menu is checked, accept either an existing `.exe` or an existing `.lnk` whose target exists
- copy configured `.lnk` files into the current user pinned Start Menu directory without overwriting a different shortcut
- preserve a configured shortcut's target and arguments
- resolve Start11 registry pins through their `.lnk` target-and-arguments signature before deciding a pin is missing
- create a new shortcut for configured executables only when needed
- register the shortcut in both Start11 pin groups with the next numeric value and correct suffix
- synchronize unchecked Menu rows to absent by removing only exact matching registrations and shortcuts
- when Admin is checked, require an executable target and set and verify RUNASADMIN on that resolved target before accepting the shortcut as ready
Run on startup:

- manage current-user startup entries under:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- resolve the executable target of existing current-user Run commands and compare normalized paths exactly
- when exactly one non-PathConfig Run value matches the configured executable, preserve its value name and command and synchronize only its `StartupApproved\Run` state
- write the 12-byte enabled state beginning with `02` for checked rows and the disabled state beginning with `03` plus a current FILETIME for unchecked rows
- report multiple matching non-PathConfig Run values as an ambiguity and modify none of them
- when no non-PathConfig Run value matches, retain the dedicated `PathConfig_Path_` or `PathConfig_Program_` owned-entry behavior
- remove obsolete Path-Config-owned startup entries and approval records only inside the selected owned prefix scope
- show Apply-mode STARTUP from the live matching Windows Startup Apps state
- never rewrite or delete a matched non-PathConfig Run value and never delete unrelated approval values
- when Run as Admin and Run on startup are both enabled, an owned fallback startup command must request elevation

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
- `<row>_Menu`

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
- Do not rewrite or delete startup Run values outside the application-owned prefixes; only an exact unique executable match may have its `StartupApproved\Run` On/Off state synchronized.
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

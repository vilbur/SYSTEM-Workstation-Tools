# Path-Config Testing Guide

## Test files

The test file version must always match the source version.

Current pair:

- `Path-Config.hta` version `0.39`
- `Test/Path-Config-Test_0.39.ps1`

The canonical source filename remains `Path-Config.hta`; versioned PowerShell tests are stored under `Test/`, and the test filename advances with each version.

## Automated test safety

The automated test must not:

- apply registry configuration
- launch configured applications
- create startup entries
- remove startup entries
- delete files

It may:

- inspect source text
- validate required strings
- validate generated-HTML handler and function names
- run a Windows JScript parser-only check
- perform read-only status checks
- create and remove temporary parser-output or capture files

## Static checks

Check for all of the following:

### Version

- correct source filename
- correct test filename
- correct internal version string
- no obsolete previous filename in the new source

### Language and silent status checks

- IE9-compatible JScript syntax
- no external script or web dependencies
- no references to undefined generated-HTML handlers
- no `WScript.Shell.Exec`, which can flash a console window
- captured status commands use `WScript.Shell.Run` with hidden window style `0`
- temporary capture output is removed in a `finally` block

### Fixed tab

- tab string starts with `Paths`
- fixed tab builder exists
- dynamic tab builder starts after fixed tab
- tab rename/delete handlers guard UI tab 1
- right-click dynamic tab menu is disabled on UI tab 1

### Row controls

- file path control
- Browse control
- Env var control
- Run as Admin checkbox
- Run on startup checkbox
- file-path edits at least 560 px wide in both path tables, supported by the minimum table canvas and half-display-width window
- compact fixed-width action columns and exact visible 20 px horizontal spacing between adjacent controls in fixed Paths and every dynamic-tab section, without inherited button margins or unused percentage-column space
- larger icon-only Config-mode checkboxes
- left-aligned ordering button and right-aligned burger menu
- Add Path handler
- Delete Path handler
- combined leftmost Move Path control
- left-click down and right-click up handlers
- right-click context-menu suppression
- moved-row cursor destination and hidden cursor-position command
- burger row menu, Move to New Tab and Delete Row handlers, unique tab naming, complete-row transfer, and fixed-row invariant
- source-update detection, unsaved-change deferral, HTA reload, launcher heartbeat/relaunch bridge, and unload cleanup
- native Windows Forms file/folder Browse handlers and centralized selected-path sanitization
- Apply Paths handler

### Persistence

- row `_Path` key
- row `_EnvVar` key
- row `_RunAsAdmin` key
- row `_RunOnStartup` key
- v0.03 numeric-key fallback
- default first empty object row

### Apply methods

- persistent apply dispatcher
- environment write target
- environment-change broadcast
- administrator compatibility-property read/write/delete methods
- managed startup cleanup
- managed startup creation
- startup command builder
- apply-result reporting

### Safety

- startup cleanup filters by `PathConfig_Path_`
- no broad deletion of all Run values
- environment target is HKCU, not HKLM
- startup target is HKCU, not HKLM
- `%NAME%` expansion is case-insensitive, nested, cycle-safe, and preserves unknown names
- Path-Config dialog definitions override Windows environment values
- expandable registry values use `REG_EXPAND_SZ`

## Parser test

Extract the embedded JScript block and parse it with the installed Windows Script Host `cscript.exe` without initializing the HTA or applying configuration actions.

Parser success does not replace runtime UI testing.

## Manual runtime test matrix

### 1. First launch

- Start without an existing `Path-Config.ini`.
- Confirm `Paths` is the first tab.
- Confirm one empty fixed row exists.
- Confirm the window is no wider than half the available display and File Path remains at least 560 px wide in both fixed and Programs path tables.
- Confirm Environment Variable uses its restored 20% column and Links Target Name keeps its earlier 15% column.
- Confirm the first and last controls align flush with the left and right row edges.
- Confirm every adjacent row control has the same visible 20 px horizontal gap in fixed Paths and all dynamic-tab sections, including compact Browse, D/F, checkbox, move, menu, and Delete controls; confirm paired D/F buttons also have 20 px between them and section action buttons align to the right edge.
- Confirm both checkboxes are visibly larger and have no Yes caption.
- Confirm the move button is aligned left and the burger menu is aligned right.
- Confirm dynamic program tabs still appear after it.

### 2. Save and reload

Enter values in one fixed row:

```text
Path: harmless executable
Env var: PATH_CONFIG_TEST_EXE
Run as Admin: unchecked
Run on startup: unchecked
```

Save, close, reopen, and confirm every value is restored.

Repeat with both checkboxes checked.

### 3. Add and delete rows

- Add at least three rows.
- Confirm each row has all four fields.
- Confirm the combined ordering control is the first control on every row.
- Left-click it to move a row down and right-click it to move a row up.
- Confirm right-click does not open a context menu.
- Confirm the path, Env var, Run as Admin, and Run on startup values stay together.
- Confirm the first row cannot move up and the last row cannot move down.
- Confirm the mouse cursor follows the combined ordering button to the moved row after a valid move.
- Delete the middle row.
- Save and reopen.
- Confirm the moved order and all remaining row values and flags are restored.
- Confirm every row has a same-sized burger menu in place of the old X button.
- Confirm both left-click and right-click open the same menu showing Move to New Tab and Delete Row, with no browser context menu.
- Move a populated row to a new tab and confirm all four fields transfer, the source row disappears, and the new tab opens.
- Confirm duplicate inferred tab names receive a numeric suffix.
- Confirm moving the only fixed row leaves one empty Paths row.
- Confirm Delete Row remains disabled for the first row and deletes later rows.

### 4. Browse

- On the first file or folder browse, confirm the native Windows dialog starts at `C:\`.
- Confirm the dialog can navigate drives, Desktop, and the full PC rather than being rooted at the Path-Config program directory.
- Browse to a file with spaces and a lowercase drive letter and confirm the full path is stored with an uppercase drive letter.
- Open another file or folder browser and confirm it starts at the directory selected previously.
- Select a folder and confirm its drive letter is uppercase and its trailing backslash is removed; confirm a drive root remains valid as `C:\`, then confirm the next browser remembers the sanitized directory.
- Save and reopen.

### 5. Environment variable

Use a temporary variable name such as:

```text
PATH_CONFIG_TEST_EXE
```

Apply Paths.

Verify:

- value exists under `HKCU\Environment`
- value data equals the selected path
- the apply result reports an environment update

Remove the temporary test value manually after testing.

### 6. Run as Admin

Use a harmless executable.

- enable Run as Admin
- disable Run on startup
- Apply Paths
- confirm the executable has a per-user `RUNASADMIN` value under AppCompatFlags `Layers`
- switch to Apply mode and confirm the column remains labeled `Run as admin`
- confirm the displayed `Yes`/`No` reflects the checkbox state
- confirm the value is green when the Windows property matches and red when it differs
- confirm the property status is shown without a helper console window
- disable Run as Admin and apply again
- confirm only the `RUNASADMIN` token is removed

### 7. Run on startup

- disable Run as Admin
- enable Run on startup
- Apply Paths
- inspect `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- confirm one `PathConfig_Path_` value exists
- confirm its command is correctly quoted

Then uncheck Run on startup and apply again.

Confirm the owned value is removed.

### 8. Elevated startup

- enable both flags
- Apply Paths
- confirm the startup command uses an elevation-capable command
- do not require a full reboot unless explicitly testing login behavior

### 9. Startup isolation

Create or identify an unrelated current-user Run value.

Apply Paths.

Confirm the unrelated value remains unchanged.

### 10. Invalid targets

Test:

- empty row with all actions disabled
- missing path with Run as Admin enabled
- missing path with Run on startup enabled
- Env var supplied with empty path

Expected:

- idle empty row is skipped
- enabled path-dependent actions report errors
- no invalid startup value is created
- an empty path shows a neutral `N/A` administrator-property status rather than a green match

### 11. Programs-tab Paths controls

For every Programs tab, confirm the Paths section contains the same file path, Browse, Env var, Run as Admin, Run on startup, and row-delete controls as the fixed Paths tab. Save, reload, and apply a harmless row. Confirm older `_Name`/`_Val` rows load into Env var and file path without data loss.

### 12. Dynamic-tab regression

Verify:

- add dynamic tab
- rename dynamic tab
- delete dynamic tab
- save and restore dynamic data
- apply current dynamic tab
- apply all dynamic tabs
- fixed Paths selection does not corrupt dynamic current-tab state

### 13. Source-update restart

- Open Path-Config without unsaved edits and update `Path-Config.hta` to a newer version.
- Confirm the running HTA reloads into the new version.
- Repeat with an unsaved UI edit and confirm restart waits with a save-to-restart status.
- Save and confirm the pending reload then occurs automatically.
- Launch `Path-Config.exe` while Path-Config is already running and confirm the cooperative relaunch request is consumed.
- Confirm heartbeat and relaunch-request files are cleaned up on an ordinary close.

## Delivery verification

Before completion, open the delivered source and test files and verify:

- `Path-Config.hta` internal and visible version
- matching versioned PowerShell test filename
- required controls
- required methods
- migration logic
- startup prefix
- correct registry targets
- no stale earlier code accidentally packaged

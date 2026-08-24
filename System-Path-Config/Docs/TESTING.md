# Path-Config Testing Guide

## Test files

Create a new permanent test file only when a change needs new lasting regression coverage; small layout changes may reuse the latest full suite with focused temporary checks.

Current source and latest full regression suite:

- `Path-Config.hta` development version `0.72`
- `Test/Path-Config-Test_0.72.ps1`
- stable release marker: `STABLE_VERSION` = `0.70`

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
- run `Debug/Print-Startup-Registry.ps1 -PassThru`, which only opens registry keys for reading
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
- Menu checkbox
- file-path edits at least 560 px wide in both path tables, supported by the minimum table canvas and half-display-width window
- compact fixed-width action columns and exact visible 20 px horizontal spacing between adjacent controls in fixed Paths and every dynamic-tab section, without inherited button margins or unused percentage-column space
- larger icon-only Config-mode checkboxes
- left-aligned burger menu and right-aligned ordering button
- Add Path handler
- Delete Path handler
- combined rightmost Move Path control
- left-click down and right-click up handlers
- right-click context-menu suppression
- moved-row cursor destination and hidden cursor-position command
- burger row menu, Move to New Tab and Delete Row handlers, unique tab naming, complete-row transfer, and fixed-row invariant
- source-update detection, unsaved-change deferral, HTA reload, launcher heartbeat/relaunch bridge, and unload cleanup
- native Windows Forms file/folder Browse handlers and centralized selected-path sanitization
- shared right-click Find in Explorer menu on every Browse/D/F picker button, using the live adjacent path with environment expansion, empty-value disabling, existence validation, and visible non-blocking Explorer selection
- Apply Paths handler

### Persistence

- row `_Path` key
- row `_EnvVar` key
- row `_RunAsAdmin` key
- row `_RunOnStartup` key
- row `_Menu` key
- v0.03 numeric-key fallback
- default first empty object row

### Apply methods

- persistent apply dispatcher
- environment write target
- environment-change broadcast
- administrator compatibility-property read/write/delete methods
- managed startup cleanup
- managed startup creation
- scoped `StartupApproved\Run` cleanup
- owned enabled-state REG_BINARY creation
- existing current-user Run command parsing and exact executable-target matching
- live StartupApproved On/Off status reading
- unique existing-entry approval synchronization without Run-command rewrites
- timestamped disabled-state creation and owned-entry fallback
- startup command builder
- apply-result reporting
- existing `.lnk` source resolution, collision-safe copying, target-and-arguments duplicate detection, and resolved executable administrator handling

### Safety

- startup cleanup filters by `PathConfig_Path_`
- Startup Apps cleanup accepts only `PathConfig_Path_` or `PathConfig_Program_` values and respects the selected prefix scope; non-owned approval writes require one exact unique executable match
- no broad deletion of all Run or StartupApproved values
- matched non-owned Run values retain their original name, command, type, and arguments
- ambiguous non-owned executable matches are reported and left unchanged
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
- Confirm `Common` is the first tab and program tabs cannot be named `Common` or `Paths`.
- Confirm one empty fixed row exists.
- Confirm the window is no wider than half the available display and File Path remains at least 560 px wide in both fixed and Programs path tables.
- Record the current outer window width and height, switch repeatedly between Paths and Programs tabs, and confirm both dimensions remain exactly unchanged with no incremental height growth or recentering.
- Confirm Environment Variable uses its restored 20% column and Links Link Name keeps its earlier 15% column.
- Confirm the first and last controls align flush with the left and right row edges.
- Confirm every adjacent row control has the same visible 20 px horizontal gap in fixed Paths and all dynamic-tab sections, including compact Browse, D/F, checkbox, move, menu, and Delete controls; confirm paired D/F buttons also have 20 px between them and section Add buttons sit beside their labels on the left.
- Confirm all three checkboxes are visibly larger and have no Yes caption.
- Confirm ADMIN, STARTUP, and MENU are orange, green, and blue, with 16 px between adjacent labels.
- Hover each checkbox and confirm its administrator, sign-in startup, or Start11 menu tooltip appears.
- Confirm Apply-mode YES statuses display `✔` in green when matching and `✘` in red when mismatching; confirm every NO and N/A status is blank.
- In Config mode, confirm existing paths retain the normal field border and missing paths use a red border.
- On a program tab in Apply mode, confirm APPLY {TAB NAME} appears immediately left of MODE: APPLY and no duplicate appears below the tab content.
- Confirm the burger menu is aligned left and the position button is aligned right.
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

Repeat with all three checkboxes checked.

### 3. Add and delete rows

- Add at least three rows.
- Confirm each row has all five fields.
- Confirm the combined ordering control is the first control on every row.
- Left-click it to move a row down and right-click it to move a row up.
- Confirm right-click does not open a context menu.
- Confirm the path, Env var, Run as Admin, Run on startup, and Menu values stay together.
- Confirm the first row cannot move up and the last row cannot move down.
- Confirm the mouse cursor follows the combined ordering button to the moved row after a valid move.
- Delete the middle row.
- Save and reopen.
- Confirm the moved order and all remaining row values and flags are restored.
- Confirm every row has a same-sized burger menu in place of the old X button.
- Confirm both left-click and right-click open the same menu showing Move to New Tab and Delete Row, with no browser context menu.
- Move a populated row to a new tab and confirm all five fields transfer, the source row disappears, and the new tab opens.
- Confirm duplicate inferred tab names receive a numeric suffix.
- Confirm moving the only fixed row leaves one empty Paths row.
- Confirm Delete Row remains disabled for the first row and deletes later rows.

### 4. Browse

- On the first file or folder browse, confirm the native Windows dialog starts at `C:\`.
- Confirm the dialog can navigate drives, Desktop, and the full PC rather than being rooted at the Path-Config program directory.
- Browse to a file with spaces and a lowercase drive letter and confirm the full path is stored with an uppercase drive letter.
- In Config mode, type a lowercase direct-drive directory and confirm the drive becomes uppercase and the existing directory ends with `\`; repeat with a `%NAME%`-based directory and confirm the variable text is preserved.
- Browse to a directory with and without a trailing separator and confirm the stored folder ends with exactly one `\`.
- Open another file or folder browser and confirm it starts at the directory selected previously.
- Select a folder and confirm its drive letter is uppercase and its trailing backslash is removed; confirm a drive root remains valid as `C:\`, then confirm the next browser remembers the sanitized directory.
- Right-click each Browse/D/F picker type in fixed Paths, Programs Paths, Environment Variables, Executables, and Links; confirm the same menu opens with `Find in Explorer`.
- Confirm `Find in Explorer` selects the currently typed adjacent file or folder, including a valid `%NAME%` path that has not been saved yet.
- Confirm the item is disabled for an empty field and a missing target reports an error without changing the row.
- Confirm left-click still opens the original file or folder picker.
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
- switch to Apply mode and confirm the column remains labeled `Admin`
- confirm a checked value displays a green `✔` when Windows matches or a red `✘` when it does not, while every unchecked and N/A value remains blank
- confirm the value is green when the Windows property matches and red when it differs
- confirm the property status is shown without a helper console window
- disable Run as Admin and apply again
- confirm only the `RUNASADMIN` token is removed

### Start11 Menu

Use a harmless executable. Enable Menu, confirm Apply mode reports the live pin as missing, then Apply and verify that the shortcut appears in the user pinned Start Menu folder and Start11 without restarting Explorer. Apply again and confirm there are no duplicates. Move the pin into a custom Start11 group, return to/reload Apply mode, and confirm MENU remains YES and another Apply does not recreate a root duplicate. Enable Admin, apply again, and confirm launching the shortcut requests elevation.

Repeat with an existing `.lnk` that has command-line arguments. First place a different-target shortcut with the same filename and a requested-target ` (2).lnk` duplicate in the pinned Start Menu folder, with Start11 registrations for both. Confirm Apply removes both exact registrations and files, copies the source to the unsuffixed canonical filename without altering the original, preserves its target and arguments, registers that one canonical shortcut in Start11, and does not create a duplicate on the second Apply. If Admin is enabled, confirm RUNASADMIN is applied to the shortcut's resolved executable target. Uncheck Menu and Apply; confirm matching registrations and the matching pinned-directory shortcut are removed, unrelated pins remain, and MENU becomes NO. Apply again and confirm removal is idempotent. Recheck Menu and confirm it can be added again.
### 7. Run on startup

First use an executable that already has exactly one non-PathConfig value under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

- record that Run value's name, type, command, and arguments
- open Windows Settings > Apps > Startup and note its current state
- confirm Apply mode STARTUP mirrors the live Windows state
- check Run on startup and Apply Paths; confirm the existing Run value is unchanged and its matching `StartupApproved\Run` data is `020000000000000000000000`
- reopen Windows Settings and confirm the existing app is On without a duplicate PathConfig entry
- uncheck Run on startup and apply; confirm the Run value is still unchanged, its approval data begins with `03000000` and contains a timestamp, and Windows Settings shows Off

Then use an executable with no matching non-PathConfig Run value.

- check Run on startup and apply
- confirm one correctly quoted `PathConfig_Path_` fallback exists and its approval data is `020000000000000000000000`
- uncheck and apply again
- confirm the owned Run value and matching owned approval value are removed

If two non-owned Run values resolve to the same executable, confirm Apply reports an ambiguity and changes neither approval value.

### 8. Elevated startup

- enable both flags
- Apply Paths
- confirm the startup command uses an elevation-capable command
- do not require a full reboot unless explicitly testing login behavior

### 9. Startup isolation

Create or identify an unrelated current-user Run value whose executable does not match any Path-Config row. Apply Paths and confirm both its Run value and approval state remain unchanged. For a uniquely matching existing entry, confirm only its approval state changes and its Run command remains byte-for-byte unchanged.

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
- an empty path shows a blank neutral administrator-property status rather than a green match

### 11. Programs-tab Paths controls

For every Programs tab, confirm the Paths section contains the same file path, Browse, Env var, Run as Admin, Run on startup, Menu, and row-delete controls as the fixed Paths tab. Save, reload, and apply a harmless row. Confirm older `_Name`/`_Val` rows load into Env var and file path without data loss.

### 12. Dynamic-tab regression

Verify:

- add dynamic tab
- rename dynamic tab
- delete dynamic tab
- save and restore dynamic data
- apply current dynamic tab; after an error-free result, confirm the selected Apply-mode status redraws immediately without switching tabs and the outer window size does not change
- apply all dynamic tabs; after an error-free result, confirm live status redraws immediately without changing the outer window size
- apply fixed Paths successfully and confirm it performs the same size-preserving live-status redraw
- add a Link after a row with a filled Link folder and confirm only that Link folder is prefilled; confirm Source and Link name stay empty and Type defaults to Symlink
- add another Link after a blank Link folder and confirm the new Link folder remains blank
- type or browse a Link Source while Link Name is empty and confirm Link Name defaults to the Source file or folder name
- enter a custom Link Name, change the Source, and confirm the custom Link Name is preserved
- replace a managed file symlink with a regular file while its .default backup already exists, Apply again, and confirm the current file moves to .default.2 before the symlink is recreated
- confirm CONFIG labels read Source, Link folder, Link name, and Type
- confirm every Links row has a rightmost arrow after Delete; left-click moves the complete row down, right-click moves it up, and the cursor follows the moved row
- save and reload, then confirm the reordered Links sequence persists; confirm no arrow appears in Apply mode
- set Source to an item whose containing directory equals Link folder using different letter case, slash direction, or a %NAME% reference; confirm Source and Link folder turn orange
- switch to Apply mode and confirm Source and the combined Link path remain orange
- change Link folder to a different directory and confirm the orange warning clears
- in Apply mode, confirm Links shows only Source, Link path, and Type, with no separate Link name column
- fixed Paths selection does not corrupt dynamic current-tab state
- move the selected program tab left and right from both toolbar and right-click menu; confirm its full data and selection follow it
- confirm boundary actions disable and no program tab can move before `Common`
- save and reload; confirm the reordered tab sequence persists

### 13. Save-state and mode transition

- Open Config mode without pending edits and confirm Save State uses grey font, the resting v0.39 border/background, default cursor, no hover response, and no click action.
- Type into a path field without leaving it and confirm Save State immediately restores the original v0.39 base class, white font, pointer cursor, hover response, and direct manual-save action.
- Repeat by pasting with the mouse and confirm Save State unfreezes immediately.
- Save manually and confirm Save State returns to the separate frozen state with no native disabled shadow.
- Make another edit, switch from Config to Apply, and confirm Path-Config.ini is saved before Apply mode opens.
- Simulate or cause a save failure and confirm the window remains in Config mode with an error status.

### 14. Source-update restart

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

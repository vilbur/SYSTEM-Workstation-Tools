# Path-Config Testing Guide

## Test files

The test file version must always match the source version.

Current pair:

- `Path-Config.ahk`
- `Path-Config-Test_0.04.ahk`

The next code version should produce a matching pair such as:

- `Path-Config.ahk`
- `Path-Config-Test_0.05.ahk`

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
- validate labels and function names
- run an AutoHotkey parser-only check
- create and remove temporary parser-output files

## Static checks

Check for all of the following:

### Version

- correct source filename
- correct test filename
- correct internal version string
- no obsolete previous filename in the new source

### Language

- no `#Include`
- no AutoHotkey v2-only arrow functions
- no `function name()` declaration syntax
- no `then` after `if`
- no references to undefined project helper functions

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
- Add Path handler
- Delete Path handler
- Browse handler
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
- elevated launch method
- managed startup cleanup
- managed startup creation
- startup command builder
- apply-result reporting

### Safety

- startup cleanup filters by `PathConfig_Path_`
- no broad deletion of all Run values
- environment target is HKCU, not HKLM
- startup target is HKCU, not HKLM

## Parser test

Use the installed AutoHotkey v1 executable to parse the source without running normal configuration actions.

The existing project test approach may use AutoHotkey v1 parser facilities such as `/iLib`.

Parser success does not replace runtime UI testing.

## Manual runtime test matrix

### 1. First launch

- Start without an existing `Path-Config.ini`.
- Confirm `Paths` is the first tab.
- Confirm one empty fixed row exists.
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
- Delete the middle row.
- Save and reopen.
- Confirm remaining rows and flags are correct.
- Confirm the first row cannot be deleted.

### 4. Browse

- Browse to a file with spaces in its path.
- Confirm the full path is stored.
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
- confirm one UAC elevation request occurs
- confirm the target starts

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

### 11. Dynamic-tab regression

Verify:

- add dynamic tab
- rename dynamic tab
- delete dynamic tab
- save and restore dynamic data
- apply current dynamic tab
- apply all dynamic tabs
- fixed Paths selection does not corrupt dynamic current-tab state

## Delivery verification

Before completion, open the delivered source and test files and verify:

- filenames
- internal versions
- required controls
- required methods
- migration logic
- startup prefix
- correct registry targets
- no stale earlier code accidentally packaged

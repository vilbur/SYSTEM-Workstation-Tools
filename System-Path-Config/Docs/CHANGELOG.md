# Path-Config Changelog

## 0.16

Clarified the Run as Admin presentation in Apply mode.

- the column label now remains `Run as admin`
- displayed `Yes` or `No` always reflects the saved checkbox state
- green still indicates that Windows matches the configured state
- red still indicates a mismatch
- empty paths remain neutral `N/A`
- added `Test/Path-Config-Test_0.16.ps1` regression coverage for every match and mismatch combination

## 0.15

Corrected the Run as Admin status shown in Apply mode for empty path rows.

- empty paths now display a neutral gray `N/A` status
- prevents an empty configured value and absent Windows property from appearing as a green match
- added `Test/Path-Config-Test_0.15.ps1` regression coverage

## 0.14

Added the fixed Paths row controls to every dynamic Programs tab.

- Programs path rows now include file path, Browse, Env var, Run as Admin, Run on startup, and Delete controls
- preserved the existing Environment Variables, Executables, and Links sections
- migrated older Programs `_Name`/`_Val` path rows into the new fields
- saved Programs path rows with path, environment-variable, administrator, and startup fields
- applied the new controls per program tab, using scoped `PathConfig_Program_` startup entries
- added `Path-Config-Test_0.14.ps1` coverage for the new controls, persistence, migration, and startup isolation

## 0.13

Prevented auxiliary console windows from appearing during executable and status checks.

- replaced `WScript.Shell.Exec` status capture with synchronous hidden `WScript.Shell.Run`
- captures standard output and error through an application-owned temporary file
- guarantees temporary capture cleanup with `finally`
- preserves intentionally visible configured-target launches and file/folder pickers
- confirmed the existing executable is a generic launcher and requires no rebuild for HTA source updates
- added `Path-Config-Test_0.13.ps1` with static, handler-reference, and Windows JScript parser checks

## 0.04

Delivered from the approved working `0.01` base as:

- `Path-Config.ahk`
- `Path-Config-Test_0.04.ahk`

Fixed `Paths` rows were expanded to contain:

- file path
- Browse control
- Env var field
- Run as Admin checkbox
- Run on startup checkbox

Added fixed Paths apply behavior:

- writes per-user environment variables under `HKCU\Environment`
- launches selected targets elevated with AutoHotkey v1 `*RunAs`
- manages current-user startup entries under the Run registry key
- uses the dedicated startup prefix `PathConfig_Path_`
- removes obsolete Path-Config-owned startup entries during apply
- preserves elevation in startup commands when both flags are enabled
- applies every row independently and reports aggregate results

Persistence changes:

- each row stores path, Env var, elevation flag, and startup flag
- preserves migration from the plain-path version 0.03 format
- leaves dynamic program-tab INI sections unchanged

Testing changes:

- added structural checks for all new controls and methods
- parser/static tests do not apply registry or startup changes

## 0.03

Added a fixed first tab named `Paths`.

- separate from dynamic program tabs
- cannot be renamed or deleted
- includes a first persistent file-path row
- includes Browse and Add File Path controls
- supports additional removable rows
- stores data in `[PersistentPaths]`
- remembers fixed and dynamic tab selection without corrupting dynamic indices
- validates fixed paths using the existing path-colour system

## 0.02

Updated the interface to match the dark AHK UI template.

- standardized margins and control heights
- dark edits and controls
- fake dark buttons
- CONFIG and APPLY mode controls
- consistent alignment
- preserved dynamic program-tab behavior

## 0.01

Initial standalone Path-Config application.

- multiple dynamic program tabs
- path rows
- environment-variable rows
- executable rows
- shortcut, symlink, and hardlink rows
- INI save/load
- configuration apply methods
- initial legacy data migration
- standalone AutoHotkey v1 implementation

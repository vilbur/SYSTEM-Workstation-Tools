# Path-Config Changelog

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

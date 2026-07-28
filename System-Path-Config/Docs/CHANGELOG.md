# Path-Config Changelog

## 0.29

Replaced app-directory-rooted path browsing with remembered full-PC native dialogs.

- the first file or folder dialog starts at `C:\`
- later dialogs in the same session start at the last successfully selected directory
- file and folder selections share the remembered location
- folder browsing is rooted at the Desktop/PC tree instead of the Path-Config directory
- file browsing uses a native Open File dialog with executable filtering where requested
- picker helper processes remain hidden while the user-requested dialogs stay visible
- removed the legacy HTML file input and Shell.Application folder picker
- added `Test/Path-Config-Test_0.29.ps1` static, runtime, helper-capture, handler, and parser coverage
## 0.28

Corrected all path-row control gaps to 16 px.

- uses 8 px table-cell padding on both sides of every internal control boundary
- retains the path-specific zero button-margin override so buttons do not add extra spacing
- preserves flush-left move-button and flush-right burger-menu alignment
- added Test/Path-Config-Test_0.28.ps1 uniform-spacing and parser coverage

## 0.27

Applied the same 0.5 px gap between every control in each path row.

- removed the inherited 6 px left margin from all small path-row buttons
- makes field-to-button, button-to-field, checkbox, move, delete, and menu spacing consistent
- preserves the global small-button style outside path rows
- added Test/Path-Config-Test_0.27.ps1 margin-normalization and parser coverage

## 0.26

Reduced the horizontal gap between adjacent path-row controls to 0.5 px.

- uses 0.25 px cell padding on each side of an internal control boundary
- preserves flush-left move-button and flush-right burger-menu alignment
- added Test/Path-Config-Test_0.26.ps1 exact-spacing and parser coverage

## 0.25

Set the horizontal gap between adjacent path-row controls to exactly 16 px.

- changed path-table cell padding from 7 px to 8 px per side
- preserved flush-left move-button and flush-right burger-menu alignment
- added Test/Path-Config-Test_0.25.ps1 exact-spacing and parser coverage

## 0.24

Expanded and rebalanced the path-row controls.

- maximized the file-path edit width in both the fixed Paths tab and Programs tabs
- added equal wide horizontal spacing between adjacent controls
- removed the `Yes` captions and enlarged Config-mode checkboxes to 20 px
- aligned the fixed-row move button to the left edge and burger menu to the right edge
- added `Test/Path-Config-Test_0.24.ps1` layout, spacing, checkbox, edge-alignment, handler, and parser coverage

## 0.23

Enabled the fixed Paths row burger menu on right-click.

- left-click and right-click now open the same Move to New Tab / Delete Row menu
- suppresses the browser context menu through the existing menu handler
- preserves the v0.22 cooperative launcher bridge and runtime files
- added `Test/Path-Config-Test_0.23.ps1` left/right-click, handler, launcher-bridge, and parser coverage

## 0.22

Adopted the cooperative launcher bridge present in the live workspace baseline.

- rebuilt `Path-Config.exe` from `dev/Path-Config-Launcher.ahk`
- added heartbeat and relaunch-request files for communication with an already-running HTA
- changed controlled restart to save when necessary and reload the running HTA
- added periodic bridge maintenance and unload cleanup

## 0.21

Replaced the fixed Paths row Delete button with a burger action menu.

- keeps the row action button at a fixed 30 px size and uses a burger icon
- adds Move to New Tab and Delete Row menu items
- Move to New Tab copies path, Env var, Run as Admin, and Run on startup into a new Programs tab
- removes the transferred source row and activates the new tab
- derives a safe unique tab name from the path or environment-variable name
- leaves one empty fixed row when the only row is moved
- preserves the existing rule that the first row cannot be deleted directly
- added `Test/Path-Config-Test_0.21.ps1` menu, transfer, naming, invariant, handler, and parser coverage

## 0.20

Merged fixed Paths row ordering into one leftmost control.

- moved the ordering control to the first column of each fixed Paths row
- left-click moves the complete row down
- right-click moves the complete row up and suppresses the context menu
- keeps Delete as a separate right-side action
- follows the merged button with the mouse cursor after a valid move
- added `Test/Path-Config-Test_0.20.ps1` layout, click-direction, context-menu, cursor-follow, ordering, and parser coverage

## 0.19

Added automatic full restart when a new HTA source version lands.

- waits for the source file to remain stable before restarting
- launches the generic `Path-Config.exe` through a delayed hidden command
- closes the old HTA instance instead of performing an in-place page reload
- defers restart while UI changes are unsaved and restarts automatically after they are saved
- bypasses the normal exit prompt only during the controlled restart
- reports a status error when the launcher is missing or restart cannot be scheduled
- added `Test/Path-Config-Test_0.19.ps1` watcher, deferral, launcher, close, and parser regression coverage

## 0.18

Made the mouse cursor follow fixed Paths row-order controls.

- assigns stable destinations to the Up and Down controls after rerendering
- preserves the cursor's position within the clicked control while following the moved row
- accounts for any window repositioning performed by automatic content fitting
- uses a non-blocking hidden Windows cursor-position command
- leaves the cursor unchanged when the same direction is no longer available at a boundary
- added `Test/Path-Config-Test_0.18.ps1` coordinate, destination, hidden-launch, and ordering regression coverage

## 0.17

Added editable row ordering to the fixed Paths tab.

- Config mode now shows Up and Down controls where a row can move
- moves the complete row, including path, Env var, Run as Admin, and Run on startup values
- preserves the visible order through the existing INI save sequence
- keeps ordering controls hidden in Apply mode
- added `Test/Path-Config-Test_0.17.ps1` complete-row and boundary regression coverage

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

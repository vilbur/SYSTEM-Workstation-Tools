# Path-Config Changelog

## 0.83

Recovered automatically from stale links and missing symlink privileges.

- removes only destination reparse points whose recorded targets are all missing
- preserves valid symlinks, junctions, ordinary targets, and canonical .default backups
- validates the source and Link folder before invoking mklink
- retries an exit-code-1 symbolic-link command with a visible UAC elevation prompt
- keeps helper windows hidden and UI paths displayed with single native backslashes
- adds Test/Path-Config-Test_0.83.ps1 parser and full regression coverage

## 0.82

Normalized path separators after environment-variable expansion.

- removes hidden doubled separators introduced where a variable value and configured suffix meet
- applies the same normalization to validation and all Apply operations
- fixes existing sources such as %GoogleDrive%\ProgramsData when GoogleDrive itself ends with a separator
- adds Test/Path-Config-Test_0.82.ps1 parser and full regression coverage

## 0.81

Restored native Windows path separators with duplicate-separator cleanup.

- keeps path controls untouched while the user is typing or pasting
- normalizes only after the control loses focus
- converts forward slashes to native backslashes and collapses repeated backslashes to one
- safely changes paths such as Dir\\.Subdir to Dir\.Subdir
- adds Test/Path-Config-Test_0.81.ps1 parser and full regression coverage

## 0.80

Made path editing safe for dot-prefixed directories.

- preserves the exact text in path controls while the user is typing or pasting
- normalizes paths only after the control loses focus
- stores normalized path separators as `/`, preventing sequences such as `\.` from being interpreted as escapes
- keeps drive-letter capitalization and existing-directory trailing-separator behavior
- adds `Test/Path-Config-Test_0.80.ps1` parser and full regression coverage

## 0.79

Improved Apply result readability and error reporting.

- separates every Apply completion-summary line with a blank line
- creates a fresh `ERRORS-Log.md` beside Path-Config only when the current Apply run records failures
- writes only failed entries to the dedicated error log and opens it after the result dialog is dismissed
- removes a stale `ERRORS-Log.md` at the start of the next Apply run
- adds `Test/Path-Config-Test_0.79.ps1` parser and full regression coverage

## 0.78

Stopped creating duplicate Link target backups.

- keeps the first `<link path>.default` file or folder as the canonical backup
- removes a replacement regular target when that canonical backup already exists, allowing the configured link to be recreated
- never creates numbered `.default.2`, `.default.3`, or later backup copies
- adds `Test/Path-Config-Test_0.78.ps1` parser and full regression coverage

## 0.77

Disabled Apply actions while Apply is running.

- immediately disables and greys all visible Apply buttons before work starts
- defers the operation once so the disabled state can repaint
- prevents overlapping Apply actions and preserves the lock through Apply-mode rerenders
- restores the buttons through guaranteed cleanup after success or failure
- adds Test/Path-Config-Test_0.77.ps1 running-state, failure-restoration, parser, and full regression coverage

## 0.76

Reordered Common row controls.

- moves ADMIN, STARTUP, MENU, and START MENU NAME after Environment variable
- uses the same order in Config and Apply modes
- preserves row data, persistence, actions, spacing, and the edge-aligned menu and Move buttons
- adds `Test/Path-Config-Test_0.76.ps1` parser and regression coverage

## 0.75

Added Start Menu Name to Common rows and aligned the Common Apply action.

- adds a 15% START MENU NAME field after MENU on every Common row
- persists the optional value as `<row>_LinkName` in `[PersistentPaths]`
- uses the custom name for the canonical Start11 shortcut while an empty value retains the source-derived name
- transfers Start Menu Name when a Common row moves to a new program tab
- moves `APPLY PATHS` from the Common footer to immediately before `MODE: APPLY`
- adds `Test/Path-Config-Test_0.75.ps1` full parser and regression coverage

## 0.74

Refined the program Paths Start Menu naming control.

- moves the MENU checkbox before the custom-name edit, producing STARTUP, MENU, START MENU NAME
- renames the visible LINK NAME label to START MENU NAME in Config and Apply modes
- preserves the existing _LinkName persistence key and Start11 naming behavior for compatibility
- reuses the v0.72 suite with focused temporary order and label checks; no permanent test file was added

## 0.73

Added a configurable Start11 shortcut name to program Paths rows.

- adds a 15% LINK NAME edit between STARTUP and MENU in Config mode and shows its saved value in Apply mode
- stores the optional value as <row>_LinkName in each program tab's _Paths section
- uses the custom name for the canonical Start11 shortcut while an empty value retains the executable-derived name
- removes a trailing .lnk and replaces invalid filename characters before creating the shortcut
- shortens only the program Paths File path edit from a 560 px to a 500 px minimum to keep the existing row width
- preserves Common-row layout, older configuration loading, spacing, and the stable v0.70 marker
- reuses the v0.72 suite with focused temporary schema, layout, and runtime checks; no permanent test file was added

## 0.72

Refined Apply-mode action placement and Config-mode path validation styling.

- moves `APPLY {TAB NAME}` from the program-tab footer to immediately left of `MODE: APPLY`
- keeps the current-tab action visible only on program tabs in Apply mode
- removes the green border from valid Config-mode paths while retaining the red border for missing paths
- adds `Test/Path-Config-Test_0.72.ps1` regression coverage for the new placement and validation styling, while retaining the v0.71 Links ordering checks

## 0.71

Added Links row ordering controls.

- adds the Common-tab arrow interaction to every Links row in Config mode
- left-click moves a complete Link row down and right-click moves it up
- places the arrow at the far right after Delete and keeps the cursor with the moved row
- preserves Apply-mode layout and persists the reordered Links sequence
- reused the v0.70 suite with focused temporary checks; no permanent test file was added

## 0.70

**Release status: Stable**

Canonicalized Start11 shortcut addition by removing filename conflicts and duplicates.

- uses the unsuffixed configured source or executable base name under the current user pinned Start Menu directory
- removes Start11 registry values referencing a same-name conflicting shortcut before deleting that file
- removes other pinned-directory shortcuts and registrations with the requested target-and-arguments signature
- preserves and reuses a correct canonical shortcut, including a pin moved into a custom Start11 group
- added `Test/Path-Config-Test_0.70.ps1` conflict deletion, duplicate cleanup, canonical creation, repeat-add, parser, and full regression coverage

## 0.69

Refreshed live Apply-mode status after successful actions.

- redraws successful Apply Paths and Apply All results from live state while preserving the current outer window size
- adds the missing successful refresh after applying the selected program tab
- preserves the existing ordinary redraw for partial Apply Paths and Apply All results when errors occur
- added `Test/Path-Config-Test_0.69.ps1` Apply refresh success/error runtime behavior, v0.68 action styling, parser, and full regression coverage

## 0.68

Accented Apply action buttons in green.

- applies the existing success-green palette to Apply All, Apply Paths, and the selected program-tab Apply action
- preserves button size, spacing, behavior, and the Apply-mode selector color

## 0.67

Restored repeatable file-symlink creation when backups already exist.

- chooses the first available .default, .default.2, .default.3, and later backup name
- preserves a regular file or folder that replaced a managed link before recreating it
- prevents an earlier .default backup from blocking Apply
- added Test/Path-Config-Test_0.67.ps1 collision handling, runtime behavior, parser, and full regression coverage

## 0.66

Added default Link Name autofill.

- fills an empty Link Name from the selected or typed Source file or folder name
- preserves a custom Link Name when Source changes
- handles trailing separators on folder Source paths
- added Test/Path-Config-Test_0.66.ps1 static, runtime behavior, parser, and full regression coverage

## 0.65

Added a read-only startup registry debug inventory.

- added `Debug/Print-Startup-Registry.ps1` to print startup commands from current-user and machine-wide 32-bit and 64-bit registry views
- includes Run, RunOnce, RunOnceEx, policy Run, Windows Load/Run, Winlogon, and Windows StartupApproved records
- decodes standard On/Off approval bytes, disabled timestamps, raw approval data, registry value types, and exact registry paths
- leaves unknown approval codes visible with their raw bytes and never writes to the registry
- added `Test/Path-Config-Test_0.65.ps1` parser, read-only safety, runtime inventory, v0.64 tab-order, and full regression coverage

## 0.64

Added program-tab reordering.

- added left/right controls for the selected program tab in Config mode
- added the same Move tab left/right actions to the tab right-click menu
- keeps Common permanently first and disables movement at both program-tab boundaries
- preserves the moved tab's complete keyed configuration, active selection, saved order, and current window size
- reused the v0.63 full regression suite with focused temporary ordering and parser checks; no permanent test file was added

## 0.63

Mirrored existing Windows Startup Apps entries by executable path.

- resolves current-user Run commands and reuses one exact unique non-PathConfig executable match
- preserves the matched Run value's name, type, command, and arguments while synchronizing only its StartupApproved state
- writes On as `020000000000000000000000` and Off as `03` plus a current FILETIME
- reports ambiguous matching Run entries without changing them
- retains PathConfig-owned startup creation and cleanup when no existing entry matches
- shows Apply-mode STARTUP from live Windows Run and StartupApproved state
- added `Test/Path-Config-Test_0.63.ps1` parser, static, live-state, On/Off, ambiguity, fallback, and full regression coverage

## 0.62

Replaced Apply-mode YES/NO/N/A labels with compact status symbols.

- changed matching YES to a green `✔`
- changed mismatching YES to a red `✘`
- made every NO and N/A state visually blank while preserving its status class and tooltip
- added `Test/Path-Config-Test_0.62.ps1` regression coverage

## 0.61

Normalized Config-mode paths and renamed the fixed tab.

- renamed the fixed first tab label from `Paths` to `Common` while preserving its persistent-path behavior
- reserved both `Common` and legacy `Paths` names for the fixed tab
- capitalized direct drive letters in typed and browsed path values
- added one trailing backslash when a Config-mode path resolves to an existing directory
- made folder Browse results end with exactly one trailing backslash
- added `Test/Path-Config-Test_0.61.ps1` regression coverage

## 0.60

Made Start11 MENU a repeatable live synchronization.

- refreshes Start11 registry state before each add/remove operation and each UI render
- detects pins recursively across the standard and custom Start11 groups
- shows MENU YES/NO from the real current Start11 registration rather than the saved checkbox or an older cache snapshot
- ensures checked rows are present and removes unchecked rows by exact resolved shortcut target-and-arguments signature
- deletes only matching shortcuts from the pinned Start Menu directory and verifies both addition and removal
- added `Test/Path-Config-Test_0.60.ps1` live-state, custom-group, repeat-add, repeat-remove, fixed/Programs sync, parser, and full regression coverage

## 0.59

Added existing Windows shortcut files to Start11 Menu pinning.

- accepts an existing `.exe` or `.lnk` with an existing target when Menu is checked
- copies configured `.lnk` files collision-safely into the current user pinned Start Menu folder
- preserves shortcut targets and command-line arguments and uses both for duplicate detection
- registers and verifies copied shortcuts in both Start11 groups
- resolves Admin status through `.lnk` files to their executable target
- added `Test/Path-Config-Test_0.59.ps1` full regression, approved 0.58 layout, shortcut-copy, signature, administrator-target, and parser coverage

## 0.58

Reordered fixed Persistent Paths row controls.

- changed the left-to-right order to Menu button, ADMIN, STARTUP, MENU, Browse, File path, Environment variable, and position
- applied the same column order in CONFIG and APPLY modes
- preserved all existing control widths, 20 px gaps, handlers, values, and edge alignment
- reused the v0.57 full regression suite with focused temporary v0.58 layout and parser checks; no permanent test file was added

## 0.57

Stopped incremental window-height growth when switching tabs.

- added a render flag that suppresses content fitting when the caller must preserve the current outer window size
- makes every fixed or dynamic tab selection render with size preservation enabled
- prevents tab changes from scheduling resizeTo or moveTo through fitWindowToContent
- retains startup sizing and content fitting for non-tab operations that genuinely change layout
- allows taller tab content to use the existing scroll behavior without changing the window dimensions
- added Test/Path-Config-Test_0.57.ps1 tab-size-preservation, conditional-fit, parser, and full regression coverage
## 0.56

Synchronized Path-Config startup entries with the Windows Startup Apps status.

- removes stale `StartupApproved\Run` records only for Path-Config-owned startup names during reconciliation
- writes the Windows enabled binary state for every successfully created fixed or Programs startup entry
- preserves unrelated Startup Apps approval records and continues using the isolated `PathConfig_Path_` and `PathConfig_Program_` namespaces
- added `Test/Path-Config-Test_0.56.ps1` ownership, enabled-state, parser, and full regression coverage

## 0.55

Renamed the startup status header.

- replaced START with STARTUP in both fixed and program path tables
- preserved the green header styling, checkbox behavior, persistence, and Apply status values
- added `Test/Path-Config-Test_0.55.ps1` label, parser, and full regression coverage

## 0.54

Made full boolean status words a permanent UI contract.

- ADMIN, START, and MENU status cells always display the complete uppercase words YES and NO
- added a dedicated non-truncating boolean-status style with no ellipsis or clipping
- preserved neutral N/A status where a boolean check does not apply
- documented the permanent prohibition against shortened Y/N values
- added Test/Path-Config-Test_0.54.ps1 full-value, no-ellipsis, parser, and full regression coverage
## 0.53

Refined the ADMIN, START, and MENU path controls.

- renamed the visible Startup header to START
- added 16 px spacing between adjacent ADMIN, START, and MENU labels
- colors ADMIN orange, START green, and MENU blue
- added action-specific tooltips to all three checkboxes in fixed and Programs path rows
- added Test/Path-Config-Test_0.53.ps1 spacing, color, tooltip, parser, and full regression coverage
## 0.52

Added declarative Start11 Menu pinning to fixed and Programs path rows.

- added a saved Menu checkbox directly after Startup
- shows Apply-mode pin status by resolving Start11 shortcuts to target executables
- creates a collision-safe shortcut in the current user pinned Start Menu folder when missing
- ensures both Stardock Start11 registry groups contain the shortcut with the next numeric value and correct suffix
- preserves existing pins when Menu is unchecked and avoids duplicate entries
- sets and verifies RUNASADMIN before accepting an Admin-enabled Menu shortcut
- reports ready and created pin counts in Apply results and the adjacent log
- added Test/Path-Config-Test_0.52.ps1 regression coverage
## 0.51

Fixed Save State remaining frozen while editing path fields in the IE9-mode HTA.

- listens for keyup so keyboard edits unfreeze Save State immediately without waiting for focus loss
- listens for propertychange so paste and MSHTML value changes are detected immediately
- retains input and change listeners for other supported edit paths
- marks state dirty only when captureElement confirms the field value actually changed
- ignores validation class and other non-value property events to prevent false unsaved changes
- preserved the separate v0.39 available state, frozen appearance, direct save action, and Config-to-Apply auto-save
- added Test/Path-Config-Test_0.51.ps1 immediate-edit, paste-event, false-positive filtering, parser, and full regression coverage
## 0.50

Separated Save State into a true frozen state and the original available state.

- frozen state uses grey font, default cursor, the resting v0.39 surface, no hover response, and no click handler
- available state restores the exact v0.39 base class, white font, pointer cursor, hover response, and direct saveState(true) action
- removes the shared guarded handler so transitioning back to available restores the original behavior completely
- continues to avoid the native disabled attribute and its unwanted MSHTML shadow
- preserved dirty-state tracking, Config-to-Apply auto-save, and save-failure handling
- added Test/Path-Config-Test_0.50.ps1 separate-state, handler-transition, v0.39-surface, parser, and full regression coverage
## 0.49

Restored the complete v0.39 Save State button appearance and changed clean-state freezing to application logic.

- preserves the exact v0.39 border, background, dimensions, and hover surface
- removes the native HTML disabled attribute that caused MSHTML to draw an unwanted shadow
- changes only the font to grey while no changes are pending
- routes clicks through a guarded handler that performs no save while frozen
- restores the normal white font and saving action immediately when state becomes dirty
- preserved Config-to-Apply auto-save and save-failure handling
- added Test/Path-Config-Test_0.49.ps1 v0.39-surface, no-native-disabled, guarded-click, parser, and full regression coverage
## 0.48

Added an orange warning when Source and Link locations use the same directory.

- compares the Source item's containing directory with Link folder
- expands `%NAME%` references and normalizes case, slash direction, and trailing separators before comparison
- colors both Source and Link folder orange in Config mode when they match
- colors Source and the combined Link path orange in Apply mode when they match
- leaves empty and different directories on their existing validation colors
- added `Test/Path-Config-Test_0.48.ps1` normalized comparison, live-input, orange Config/Apply rendering, Symlink-default, auto-save, handler, parser, and full regression coverage
## 0.47

Changed the default type for newly added Links to Symlink.

- new Link rows now select Symlink instead of Shortcut
- preserves the inherited Link folder and empty Source/Link name defaults
- preserves types stored in existing and migrated Link rows
- added `Test/Path-Config-Test_0.47.ps1` Symlink-default, Link-folder inheritance, disabled-style, auto-save, handler, parser, and full regression coverage
## 0.46

Refined the disabled Save State appearance.

- restored the normal Save State border and background from the enabled button style
- uses grey font as the only disabled visual change
- removed the custom disabled hover surface that produced a shadowed appearance
- preserved disabled click behavior, dirty-state tracking, and Config-to-Apply auto-save
- added Test/Path-Config-Test_0.46.ps1 text-only disabled-style, parser, and full regression coverage
## 0.45

Improved new-Link defaults and clarified Link terminology throughout the UI.

- prefills a new Link row's Link folder from the immediately previous row when that folder is non-empty
- leaves new Source and Link name values empty and retains the Shortcut type default
- keeps Link folder empty when the previous row has no folder
- renamed CONFIG labels to Link folder and Link name
- renamed the combined APPLY label to Link path
- renamed the native folder-picker title to Select link folder
- added `Test/Path-Config-Test_0.45.ps1` Link-folder inheritance, clear-label, auto-save, handler, parser, and full regression coverage
## 0.44

Tied Config-to-Apply transitions and the Save State button to the unsaved-change state.

- automatically saves pending Config edits before entering Apply mode
- keeps Config mode active and reports a clear status if the automatic save fails
- disables and greys out Save State when no changes are pending
- enables Save State immediately when an editable value or structure changes
- disables Save State again immediately after a successful manual save
- added Test/Path-Config-Test_0.44.ps1 auto-save, failure-path, disabled-button, parser, and full regression coverage
## 0.43

Added a shared right-click menu to every file/folder Browse button.

- adds `Find in Explorer` to fixed Paths, Programs Paths, Environment Variables, Executables, and Links picker buttons
- reads the live adjacent field so unsaved edits are used
- expands configured and Windows `%NAME%` references before locating the target
- disables the action for empty values and reports missing paths without changing configuration
- launches visible non-blocking Explorer with an existing file or folder selected
- preserves every existing left-click file/folder picker action
- added `Test/Path-Config-Test_0.43.ps1` menu coverage for all nine picker buttons, adjacent-field resolution, Explorer selection, handler checks, parser checks, and full regressions
## 0.42

Simplified dynamic-tab APPLY rows.

- removed the redundant Links Target name column from APPLY mode
- shows Links as Source, combined Target, and Type in APPLY mode while preserving the complete CONFIG editor and saved data
- changed administrator and startup status values to uppercase YES and NO
- added `Test/Path-Config-Test_0.42.ps1` APPLY-links layout, uppercase-status, parser, and full regression coverage

## 0.41

Made each Browse dialog start from the path already entered in its own field.

- uses a populated folder path directly and the containing directory of a populated file path
- falls back to the last successfully browsed directory when the field is empty or has no usable location
- retains the initial C:\ fallback before any successful Browse operation
- passes field values through fixed Paths, program Paths, executables, environment values, and link source/target Browse handlers
- added Test/Path-Config-Test_0.41.ps1 field-priority, empty-field fallback, handler, parser, and full regression coverage
## 0.40

Refined dynamic program-tab section labels, ordering, and empty-state layout.

- shortened the path status headers from Run as admin and Run on startup to Admin and Startup
- retained full Yes/No values in Apply mode
- moved Links directly below Paths in every dynamic program tab
- removed visible No entries configured, No executables configured, and No links configured messages while preserving their layout height
- moved every + Add section action beside its heading on the left
- preserved the v0.39 native Windows folder picker and all existing persistence and Apply behavior
- added `Test/Path-Config-Test_0.40.ps1` UI-order, label, empty-state, action-alignment, parser, and regression coverage

## 0.39

Replaced the incompatible upgraded WinForms folder picker with the native Windows Common Item Dialog.

- removed the FolderBrowserDialog.AutoUpgradeEnabled dependency, which is unavailable in some Windows PowerShell/.NET installations
- opened Windows IFileOpenDialog in folder-selection and file-system modes through an embedded, runtime-compiled interop bridge
- preserved the picker title, remembered initial directory, selected-path sanitization, hidden STA helper, and all folder Browse callbacks
- added Test/Path-Config-Test_0.39.ps1, including bridge decoding and compilation plus the full parser and UI regression suite
## 0.38

Upgraded Browse Folder to the modern native Windows folder-selection experience.

- explicitly enabled `FolderBrowserDialog.AutoUpgradeEnabled`
- requested the upgraded Windows Common Item Dialog while retaining folder-only selection
- preserved the remembered starting directory, full Desktop/This PC tree, new-folder action, full-path sanitization, and all fixed/dynamic folder Browse handlers
- retained the hidden STA picker helper so no console window is shown
- added `Test/Path-Config-Test_0.38.ps1` native-upgrade, picker-script, parser, migration, and full regression coverage

## 0.37

Sanitized every path returned by the native Windows Browse dialogs.

- added one centralized post-selection sanitizer used by all file and folder Browse actions
- capitalized drive letters for every browsed path
- removed trailing backslashes from browsed folders, including UNC shares
- preserved required drive-root separators such as `C:\`
- retained native Windows Forms `OpenFileDialog` and `FolderBrowserDialog` controls with full-PC access
- preserved the shared remembered browse directory and all fixed/dynamic Browse handlers
- added `Test/Path-Config-Test_0.37.ps1` sanitizer, drive-root, UNC, native-dialog construction, callback, parser, and regression coverage

## 0.36

Extended the compact fixed-Paths row geometry to every section of dynamic program tabs.

- applied 10 px adjacent-cell padding and exact visible 20 px gaps to Environment Variables, Executables, and Links
- replaced their percentage action columns with compact fixed-width Browse/D/F/Delete columns
- sized dynamic row buttons to 30 px and spaced paired D/F buttons by exactly 20 px
- aligned first fields flush left and Delete buttons flush right
- kept flexible value/path fields, Environment Variable proportions, Target Name at 15%, and the half-display window cap
- preserved all dynamic add, browse, delete, save, load, apply, and migration behavior
- added `Test/Path-Config-Test_0.36.ps1` all-section compact-layout, gap, edge-alignment, handler, parser, and regression coverage

## 0.35

Removed hidden percentage-column space that made path-row control gaps look much larger than 20 px.

- replaced percentage-width move, Browse, checkbox, menu, and Delete columns with compact fixed widths
- sized Browse buttons to 64 px, edge buttons to 30 px, and checkbox columns to their 20 px controls
- kept File Path flexible with its 560 px minimum and kept Environment Variable at 20%
- preserved Target Name at 15% and the half-display window cap
- retained 10 px padding on adjacent cells, now producing an exact visible 20 px gap
- aligned the first and last row buttons flush with the tab-content edges
- added `Test/Path-Config-Test_0.35.ps1` compact-column, visible-spacing, edge-alignment, parser, and regression coverage

## 0.34

Rebalanced the window and restored the earlier secondary-control proportions.

- capped initial and post-render window width at half the available display
- restored Environment Variable to 20% in fixed and Programs path rows
- kept Links Target Name at its earlier 15% width
- restored File Path proportions to 46% in fixed Paths and 48% in Programs while retaining the 560 px minimum
- aligned section action buttons to the right edge of tab content
- preserved exact 20 px gaps between adjacent path-row controls
- added `Test/Path-Config-Test_0.34.ps1` half-width, restored-column, button-alignment, spacing, parser, and regression coverage

## 0.33

Removed the window-width cap so the path-row layout produces an unmistakably wider result on large displays.

- changed initial sizing to the full Windows work-area width
- changed every post-render content fit to retain the full Windows work-area width
- removed the previous 1320 px cap
- preserved the 560 px File Path minimum, exact 20 px gaps, and flush left/right alignment
- added `Test/Path-Config-Test_0.33.ps1` full-width sizing, minimum-width, parser, and regression coverage

## 0.32

Guaranteed a practical minimum width for File Path controls while retaining the wide edge-aligned layout.

- assigned every Config-mode File Path edit a 560 px minimum width
- set path tables to a 1140 px minimum canvas and the page to a 1220 px minimum canvas
- increased both initial and content-fit window targets from 1220 px to 1320 px
- retained horizontal scrolling on smaller displays rather than shrinking File Path below 560 px
- preserved exact 20 px internal gaps and flush left/right outer-control alignment
- added `Test/Path-Config-Test_0.32.ps1` minimum-width, window-size, spacing, parser, and regression coverage

## 0.31

Rebalanced path-tab controls to maximize File Path width and use 20 px gaps.

- increased File Path to 51% in the fixed Paths table and 53% in Programs tabs
- set both Environment Variable columns to 15%, matching the Links Target Name column
- changed internal path-row gaps to exactly 20 px using 10 px padding on each adjacent cell
- aligned the first and last controls flush with the left and right row edges
- preserved zero inherited button margins, checkbox sizing, row ordering, menus, and Apply-mode layout
- added `Test/Path-Config-Test_0.31.ps1` width, matched-column, edge-alignment, spacing, parser, and regression coverage

## 0.30

Added native `%NAME%` environment-variable support throughout path handling.

- resolves Windows variables such as `%username%` and `%GoogleDrive%`
- collects variables from fixed Paths rows, Programs path rows, and Programs Environment Variables rows
- gives Path-Config definitions priority over existing Windows variables, using Apply All order for duplicate definitions
- supports case-insensitive and nested references with cycle and unknown-variable protection
- keeps raw variable syntax in the INI while using resolved paths for validation, startup, administrator properties, launches, and links
- writes referenced environment values as `REG_EXPAND_SZ`
- updates dialog state live so newly typed Path-Config variables are immediately available
- added `Test/Path-Config-Test_0.30.ps1` resolver, priority, persistence, parser, and regression coverage

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

# Path-Config Design Specification

## User-facing modes

### CONFIG

Purpose: edit structure and values.

Expected capabilities:

- add persistent Paths rows
- browse for files
- edit Env var names
- enable or disable Run as Admin
- enable or disable Run on startup
- enable or disable Start11 Menu pinning
- delete persistent rows after the first
- manage dynamic program tabs
- edit dynamic tab configuration rows
- save changes manually while edits are pending; the available state uses the original v0.39 base class, hover, white font, pointer cursor, and direct save action; the clean state is a separate frozen button with grey font, default cursor, resting v0.39 surface, no hover response, and no click handler
- detect value changes immediately in IE9-mode HTA through input, keyup, propertychange, and change events so typing or pasting into a path field unfreezes Save State without waiting for focus loss; ignore non-value property events
- automatically save pending changes before switching from Config to Apply; remain in Config if saving fails

### APPLY

Purpose: execute stored configuration.

Expected capabilities:

- inspect configured values
- apply fixed Paths rows
- apply current dynamic program tab
- apply all configurations

Structural editing controls should be hidden or disabled in Apply mode.

## Source-update restart

Path-Config maintains heartbeat and relaunch-request files used by the cooperative `Path-Config.exe` launcher. A launcher invocation against a running instance writes a relaunch request, which the HTA consumes and handles through its restart path. Stable source updates use the same restart logic. If UI edits are unsaved, restart remains pending until they can be saved; the controlled restart then reloads the running HTA while preserving restart-aware unload handling.

## Fixed Paths tab

The first visible tab is always:

```text
Paths
```

It is a system tab rather than a user-created program tab.

Constraints:

- first position is permanent
- name is reserved
- right-click rename/delete menu must not operate on it
- switching to it must not overwrite the last dynamic tab index
- saving selected UI tab must distinguish it from dynamic tab selection

## Persistent row layout

Required left-to-right control order:

1. fixed-size burger menu containing Move to New Tab and Delete Row
2. Run as Admin checkbox
3. Run on startup checkbox
4. Menu checkbox
5. Browse button
6. file path edit
7. Env var edit
8. one rightmost ordering button (left-click moves down; right-click moves up)

The file-path edit receives the largest available share of the row and has a 560 px minimum width. Environment Variable uses its restored 20% column while Links Link Name keeps its earlier 15% column. Path tables retain a 1270 px minimum canvas and the application window is capped at half the available display width; narrower windows scroll horizontally instead of compressing File Path below its minimum. Compact fixed-width columns fit the 30 px edge buttons, 64 px Browse button, and 20 px checkboxes without unused column space in fixed Paths and Programs Paths; 10 px padding on each adjacent cell therefore produces an exact visible 20 px horizontal gap. Shared button styles must not add extra margins. The first and last controls align flush with the left and right row edges, and section Add buttons sit beside their labels on the left. Config-mode checkboxes are larger and icon-only, without a `Yes` caption. The ADMIN, STARTUP, and MENU labels use orange, green, and blue respectively, with 8 px padding on each side producing 16 px between adjacent labels. Each checkbox provides an action-specific tooltip. Boolean values must always display the complete uppercase words YES and NO. They must never be shortened, ellipsized, or clipped. Every row remains aligned with its column headers. Tab selection rerenders content without resizing or recentering the outer HTA window; repeated tab changes must preserve its exact current dimensions.

## Path browsing

File Browse actions use Windows Forms `OpenFileDialog`. Folder Browse actions use the native Windows `IFileOpenDialog` Common Item Dialog in folder-selection mode. Both provide access to the full PC. A populated path field opens Browse at that field path (or its containing directory for a file). An empty field opens at the last successfully selected directory; before any selection it starts at `C:\`. Every selected path passes through one sanitizer before reaching application state: drive letters are capitalized, forward separators are normalized, and folder results lose trailing backslashes except when the separator is required for a drive root such as `C:\`. UNC share trailing separators are removed. Cancelling a dialog leaves the remembered directory unchanged.

Every file/folder Browse button, including compact D/F controls, opens a shared right-click menu with `Find in Explorer`. The menu reads the live adjacent input rather than stale saved state, disables its action for an empty value, resolves `%NAME%` references, validates that the target exists, and launches visible Windows Explorer with the file or folder selected. Missing paths report an error without changing configuration.

## Programs-tab path rows

Every dynamic Programs tab uses the same minimum-560-px file path, compact 64 px Browse button, restored 20% Env var, larger icon-only Run as Admin, larger icon-only Run on startup, and compact 30 px Delete controls with the same exact visible 20 px horizontal spacing and flush outer alignment. Environment Variables, Executables, and Links also use compact fixed-width D/F/Browse/Delete action columns; paired D/F buttons are separated by exactly 20 px, first fields are flush left, and Delete buttons are flush right. Links keeps Link Name at 15% in Config mode; Apply mode combines Link folder and Link name into one Link path column, so the visible labels are Source, Link path, and Type. Rows are saved inside that tab's `_Paths` section. Legacy `_Name` and `_Val` keys migrate to the new Env var and file path fields.

New Link rows inherit the immediately previous row's non-empty Link folder. Source and Link name remain empty and Type starts as Symlink; if the previous Link folder is blank, the new row stays blank.

Path-Config compares the Source item's containing directory with Link folder after %NAME% expansion, slash normalization, trailing-separator cleanup, and case folding. When they match, Config mode colors both Source and Link folder orange; Apply mode colors Source and the combined Link path orange. Empty or different directories keep their normal validation colors.

Program startup registry values use the dedicated `PathConfig_Program_` namespace so applying a program tab does not remove fixed Paths startup entries.

## Persistent row ordering

In Config mode, one rightmost ordering control appears on every persistent row. Left-click moves the complete row down; right-click moves it up and suppresses the context menu. The file path, environment variable, Run as Admin flag, Run on startup flag, and Menu flag must move together. The reordered array is saved in its visible order. The ordering control is not shown in Apply mode. After a successful move, the mouse cursor follows the merged control on the moved row.

## Persistent row menu

Every fixed Paths row has a fixed-size burger menu on the left. Either left-click or right-click opens the same menu with two actions:

1. `Move to New Tab` creates a uniquely named Programs tab containing the complete row data, removes the source row, and activates the new tab.
2. `Delete Row` uses the existing deletion rule and remains disabled for the first row.

Moving the only fixed row must leave one empty persistent row behind. The new Programs tab starts with the moved path row and empty Environment Variables, Executables, and Links collections.

## Persistent row actions

### Environment-variable action

Condition:

```text
Env var is not empty AND path is not empty
```

Action:

```text
Write HKCU\Environment\<Env var> = <path>
```

An empty Env var does nothing. It must not create a blank registry value name.

Path-like values accept native `%NAME%` references. Resolution is case-insensitive and recursive. Variables configured anywhere in the Path-Config dialog take priority over the existing Windows environment; later Path-Config definitions in Apply All order win. Windows variables such as `%username%` are used as fallback. Unknown and cyclic references remain unresolved instead of being discarded or looping. Raw values remain persisted, and environment registry values containing references use `REG_EXPAND_SZ`.

### Windows administrator compatibility property

Condition:

```text
A persistent row has a non-empty executable path
```

Validation when Run as Admin is enabled:

- target exists
- target is an `.exe` file

Action:

- add the `RUNASADMIN` token when enabled
- remove only the `RUNASADMIN` token when disabled
- preserve all other compatibility flags
- query status without displaying a helper console window
- keep the Apply-mode column label as `Admin`
- display uppercase `YES` or `NO` from the configured Run as Admin checkbox
- color the value green when the Windows property matches and red when it differs
- show a neutral `N/A` status when the path is empty

Failure increases the persistent apply error count.

### Startup action

Condition:

```text
Run on startup is checked
```

Validation:

- path is non-empty
- target exists

Action:

- create a current-user Run value owned by Path-Config
- set the matching Path-Config-owned `StartupApproved\Run` value to the 12-byte enabled state beginning with `02`

When Run as Admin is also checked, store an elevation-capable startup command rather than a plain quoted path.

### Start11 Menu action

When Menu is checked, accept an existing `.exe` or an existing `.lnk` whose target exists. Executables receive a collision-safe generated shortcut only when missing. Configured shortcut files are copied to the pinned Start Menu directory without overwriting a different shortcut, preserving their target and arguments. Existing pins are compared by normalized target plus arguments and registered in both Start11 groups. Apply mode shows green YES for a ready requested pin and red NO when missing. Unchecked Menu rows leave existing pins unchanged. Admin-enabled shortcuts must resolve to an `.exe`; RUNASADMIN is set and verified on that resolved executable before the shortcut is accepted as ready.
## Startup reconciliation

Startup state is declarative.

The desired state comes from the current checked rows, not from incremental button presses.

Apply algorithm:

```text
collect PathConfig-owned Run values
remove collected values
collect PathConfig-owned StartupApproved\Run values in the same apply scope
remove collected approval values
for each enabled startup row
    validate target
    recreate one owned Run value
    write its enabled StartupApproved\Run binary value
```

This ensures unchecked, deleted, or reordered rows do not leave stale startup entries or stale disabled Windows Startup Apps state. Cleanup and writes remain limited to the `PathConfig_Path_` and `PathConfig_Program_` namespaces.

## Apply result

Persistent apply should return structured information equivalent to:

```text
{
    env_changed: true or false,
    admin_property_count: integer,
    admin_removed_count: integer,
    startup_count: integer,
    error_count: integer
}
```

The GUI may summarize this result in a message box.

Do not stop processing all rows because one row fails.

## INI format

Example conceptual section:

```ini
[PersistentPaths]
1_Path=C:\Tools\Tool.exe
1_EnvVar=TOOL_EXE
1_RunAsAdmin=1
1_RunOnStartup=1
1_Menu=1

2_Path=C:\Tools\Other.exe
2_EnvVar=
2_RunAsAdmin=0
2_RunOnStartup=1
2_Menu=0
```

The section must be independent from dynamic program-tab sections.

## Reserved names

At minimum, `Paths` is reserved for the fixed tab and must not be accepted as a dynamic program-tab name.

Case-insensitive comparison is preferred for reserved-name validation.

## Error handling

Apply should report an error when an enabled action requires a target but the target is missing.

An empty row with no enabled action is not an error.

An environment variable with an empty name is skipped.

Registry operations must check `ErrorLevel` where supported.

Run operations must use `UseErrorLevel`.

## Non-goals unless explicitly requested

- system-wide environment variables under HKLM
- scheduled tasks
- Windows services
- startup entries for other user accounts
- deleting unrelated startup values
- automatic elevation of the entire manager
- changing dynamic program-tab persistence as part of fixed Paths work

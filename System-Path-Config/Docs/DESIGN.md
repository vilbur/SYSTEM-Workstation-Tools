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
- delete persistent rows after the first
- manage dynamic program tabs
- edit dynamic tab configuration rows
- save changes

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

1. one leftmost ordering button (left-click moves down; right-click moves up)
2. file path edit
3. Browse button
4. Env var edit
5. Run as Admin checkbox
6. Run on startup checkbox
7. fixed-size burger menu containing Move to New Tab and Delete Row

The file-path edit receives the largest available share of the row and has a 560 px minimum width. Environment Variable uses its restored 20% column while Links Target Name keeps its earlier 15% column. Path tables retain a 1270 px minimum canvas and the application window is capped at half the available display width; narrower windows scroll horizontally instead of compressing File Path below its minimum. Compact fixed-width columns fit the 30 px edge buttons, 64 px Browse button, and 20 px checkboxes without unused column space; 10 px padding on each adjacent cell therefore produces an exact visible 20 px horizontal gap. Shared button styles must not add extra margins. The first and last controls align flush with the left and right row edges, and section action buttons align to the right edge of the tab content. Config-mode checkboxes are larger and icon-only, without a `Yes` caption. Every row remains aligned with its column headers.

## Path browsing

File and folder Browse actions use native Windows dialogs with access to the full PC. The first dialog in an application session starts at `C:\`. After a successful selection, both file and folder dialogs reuse the selected directory as their next starting location. Cancelling a dialog leaves the remembered directory unchanged.

## Programs-tab path rows

Every dynamic Programs tab uses the same minimum-560-px file path, compact 64 px Browse button, restored 20% Env var, larger icon-only Run as Admin, larger icon-only Run on startup, and compact 30 px Delete controls with the same exact visible 20 px horizontal spacing and flush outer alignment. Rows are saved inside that tab's `_Paths` section. Legacy `_Name` and `_Val` keys migrate to the new Env var and file path fields.

Program startup registry values use the dedicated `PathConfig_Program_` namespace so applying a program tab does not remove fixed Paths startup entries.

## Persistent row ordering

In Config mode, one leftmost ordering control appears on every persistent row. Left-click moves the complete row down; right-click moves it up and suppresses the context menu. The file path, environment variable, Run as Admin flag, and Run on startup flag must move together. The reordered array is saved in its visible order. The ordering control is not shown in Apply mode. After a successful move, the mouse cursor follows the merged control on the moved row.

## Persistent row menu

Every fixed Paths row has a fixed-size burger menu on the right. Either left-click or right-click opens the same menu with two actions:

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
- keep the Apply-mode column label as `Run as admin`
- display `Yes` or `No` from the configured Run as Admin checkbox
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

- create current-user Run value owned by Path-Config

When Run as Admin is also checked, store an elevation-capable startup command rather than a plain quoted path.

## Startup reconciliation

Startup state is declarative.

The desired state comes from the current checked rows, not from incremental button presses.

Apply algorithm:

```text
collect PathConfig-owned Run values
remove collected values
for each enabled startup row
    validate target
    recreate one owned value
```

This ensures unchecked, deleted, or reordered rows do not leave stale startup entries.

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

2_Path=C:\Tools\Other.exe
2_EnvVar=
2_RunAsAdmin=0
2_RunOnStartup=1
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

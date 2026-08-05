$ErrorActionPreference = "Stop"

$ExpectedVersion = "0.37"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $ProjectRoot "Path-Config.hta"
$Failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contains {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) {
        $script:Failures.Add($Message)
    }
}

function Assert-NotContains {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -match $Pattern) {
        $script:Failures.Add($Message)
    }
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "Missing source: $SourcePath"
}

$Source = [System.IO.File]::ReadAllText($SourcePath)
Assert-Contains $Source 'var VERSION = "0\.37";' "HTA internal version is not 0.37."
Assert-Contains $Source 'document\.title = "Path-Config v" \+ VERSION' "GUI title does not use the internal version."
Assert-Contains $Source 'HTA edition &middot; v' "Visible HTA version label is missing."
Assert-NotContains $Source 'Admin property matches' "Apply mode still uses the old administrator-property header."
if ([regex]::Matches($Source, '<th>Run as admin</th>').Count -lt 2) {
    $Failures.Add("Run as admin header is not used in both path tables.")
}
Assert-Contains $Source '\(expected \? "Yes" : "No"\)' "Administrator status does not display the configured checkbox state."
Assert-Contains $Source 'data-table path-table' "Path tables do not use the dedicated wide-layout class."
if ([regex]::Matches($Source, 'class="data-table path-table"').Count -lt 2) {
    $Failures.Add("The fixed and Programs path tables do not both use the dedicated layout.")
}
Assert-Contains $Source '<col style="width:40px"><col><col style="width:84px"><col style="width:20%">' "Fixed Paths does not use compact action columns around the flexible File Path."
Assert-Contains $Source '<col><col style="width:84px"><col style="width:20%">' "Programs Paths does not use a compact Browse column around the flexible File Path."
if ([regex]::Matches($Source, '<col style="width:40px"><col style="width:40px"><col style="width:40px">').Count -lt 2) {
    $Failures.Add("Path tables do not use compact checkbox and right-edge button columns.")
}
Assert-Contains $Source '<col style="width:50px"><col style="width:15%"><col style="width:130px"><col style="width:40px">' "Links Target Name column is not preserved at 15% within the compact layout."
Assert-Contains $Source 'html, body\s*\{\s*margin: 0;\s*min-width: 1350px;' "Application canvas is too narrow for restored columns and 560px path controls."
Assert-Contains $Source '\.path-table\s*\{\s*min-width: 1270px;' "Path tables do not preserve enough width for restored columns and path controls."
Assert-Contains $Source '\.path-field\s*\{\s*min-width: 560px;' "File Path edit controls do not have a 560px minimum width."
Assert-Contains $Source 'var className = field === "path" \? "field path-field" : "field";' "Path inputs do not receive the minimum-width class."
Assert-Contains $Source 'var desiredWidth = Math\.max\(1, Math\.floor\(availableWidth / 2\)\);' "Content-fit sizing is not capped at half the display."
Assert-Contains $Source 'var initialWidth = Math\.max\(1, Math\.floor\(screen\.availWidth / 2\)\);' "Initial sizing is not capped at half the display."
Assert-Contains $Source '\.section-action\s*\{\s*float: right;\s*margin-left: 12px;' "Tab section buttons are not aligned to the right."
Assert-Contains $Source '\.path-table td\s*\{\s*padding-right: 10px;\s*padding-left: 10px;' "Path controls do not use an exact 20px horizontal gap."
Assert-Contains $Source '\.path-table td:first-child\s*\{\s*padding-left: 0;\s*text-align: left;' "First path-row control is not flush left."
Assert-Contains $Source '\.path-table td:last-child\s*\{\s*padding-right: 0;\s*text-align: right;' "Last path-row control is not flush right."
Assert-Contains $Source '\.path-table \.button-small\s*\{\s*margin-left: 0;' "Path-row buttons retain the shared 6px left margin."
Assert-Contains $Source '\.path-browse-button\s*\{\s*box-sizing: border-box;\s*width: 64px;\s*padding-right: 0;\s*padding-left: 0;' "Browse buttons do not exactly fill their compact columns."
Assert-Contains $Source '\.move-cell \.button,\s*\.path-table td:last-child \.button-small\s*\{\s*box-sizing: border-box;\s*width: 30px;\s*padding-right: 0;\s*padding-left: 0;' "Edge buttons do not exactly fill their compact columns."
if ([regex]::Matches($Source, 'class="data-table program-table"').Count -lt 3) {
    $Failures.Add("All dynamic-tab non-Path tables do not use the compact row layout.")
}
Assert-Contains $Source '\.program-table\s*\{\s*min-width: 1270px;' "Dynamic-tab tables do not preserve the compact layout canvas."
Assert-Contains $Source '\.program-table td\s*\{\s*padding-right: 10px;\s*padding-left: 10px;' "Dynamic-tab controls do not use exact 20px inter-cell gaps."
Assert-Contains $Source '\.program-table td:first-child\s*\{\s*padding-left: 0;\s*text-align: left;' "Dynamic-tab first controls are not flush left."
Assert-Contains $Source '\.program-table td:last-child\s*\{\s*padding-right: 0;\s*text-align: right;' "Dynamic-tab Delete buttons are not flush right."
Assert-Contains $Source '\.program-table \.button-small\s*\{\s*box-sizing: border-box;\s*width: 30px;\s*margin-left: 0;\s*padding-right: 0;\s*padding-left: 0;' "Dynamic-tab row buttons are not compact 30px controls."
Assert-Contains $Source '\.program-table \.row-action-pair \.button-small \+ \.button-small\s*\{\s*margin-left: 20px;' "Paired D/F buttons do not have an exact 20px gap."
Assert-Contains $Source '<col style="width:20%"><col>''\s*\+\s*''<col style="width:100px"><col style="width:40px">' "Environment Variables rows do not use compact action columns."
Assert-Contains $Source '<col><col style="width:100px"><col style="width:40px">' "Executable rows do not use compact action columns."
Assert-Contains $Source '<col><col style="width:100px"><col>''\s*\+\s*''<col style="width:50px"><col style="width:15%"><col style="width:130px"><col style="width:40px">' "Links rows do not use compact action columns while preserving Target Name."
Assert-Contains $Source '\.path-table \.check-wrap input\s*\{\s*width: 20px;\s*height: 20px;\s*margin: 0;' "Path checkboxes are not enlarged."
Assert-NotContains $Source '> Yes</label>' "Config-mode checkboxes still display the Yes label."
Assert-Contains $Source '\.move-cell\s*\{\s*padding-left: 0 !important;\s*text-align: left;' "Move button is not aligned to the left edge."
Assert-Contains $Source '\.row-menu-cell\s*\{\s*padding-right: 0 !important;\s*text-align: right;' "Row menu button is not aligned to the right edge."
Assert-Contains $Source '<td class="row-menu-cell"><button' "Persistent-row menu does not use the right-edge cell."
Assert-Contains $Source 'var lastBrowseDirectory = "C:\\\\";' "Initial browse directory is not C:\\."
Assert-Contains $Source 'function currentBrowseDirectory\(\)' "Remembered browse-directory resolver is missing."
Assert-Contains $Source 'function rememberBrowseDirectory\(path\)' "Browse-directory memory function is missing."
Assert-Contains $Source 'function sanitizeBrowsedPath\(path, isFolder\)' "Central browsed-path sanitizer is missing."
Assert-Contains $Source 'path = path\.charAt\(0\)\.toUpperCase\(\) \+ path\.substr\(1\)' "Browsed drive letters are not capitalized."
Assert-Contains $Source 'while \(/\\\\\$/.test\(path\) && !/\^\[A-Z\]:\\\\\$/.test\(path\)\)' "Browsed folders do not remove trailing backslashes while preserving drive roots."
Assert-Contains $Source 'sanitizeBrowsedPath\(runPickerScript\(script\), true\)' "Native folder results are not sanitized."
Assert-Contains $Source 'sanitizeBrowsedPath\(runPickerScript\(script\), false\)' "Native file results are not sanitized."
Assert-Contains $Source 'function runPickerScript\(script\)' "Native picker runner is missing."
Assert-Contains $Source 'System\.Windows\.Forms\.OpenFileDialog' "Full-PC file picker is missing."
Assert-Contains $Source 'System\.Windows\.Forms\.FolderBrowserDialog' "Full-PC folder picker is missing."
Assert-Contains $Source '\$dialog\.InitialDirectory=' "File picker does not use the remembered directory."
Assert-Contains $Source '\$dialog\.SelectedPath=' "Folder picker does not use the remembered directory."
Assert-Contains $Source '\$dialog\.RootFolder=\[System\.Environment\+SpecialFolder\]::Desktop' "Folder picker is not rooted at the full Desktop/PC tree."
Assert-Contains $Source 'powershell\.exe -NoProfile -STA -WindowStyle Hidden -Command' "Native picker is not launched in STA mode with a hidden helper window."
Assert-Contains $Source 'PATHCONFIG_PICKER:' "Native picker result marker is missing."
if ([regex]::Matches($Source, 'rememberBrowseDirectory\(path\);').Count -lt 2) {
    $Failures.Add("File and folder pickers do not both remember the selected directory.")
}
Assert-NotContains $Source 'BrowseForFolder\(' "Legacy app-directory-rooted folder picker is still present."
Assert-NotContains $Source 'input\.type = "file"' "Legacy HTML file input is still present."
Assert-NotContains $Source 'new ActiveXObject\("Shell\.Application"\)' "Unused legacy Shell.Application picker dependency remains."

Assert-Contains $Source 'function runCapture\(command\)' "runCapture() is missing."
Assert-NotContains $Source 'wsh\.Exec\s*\(' "WScript.Shell.Exec can flash a console window and must not be used."
Assert-Contains $Source 'wsh\.Run\(hiddenCommand, 0, true\)' "Captured commands are not run synchronously with hidden window style 0."
Assert-Contains $Source 'ExpandEnvironmentStrings\("%ComSpec%"\)' "Hidden capture does not use the configured command shell."
Assert-Contains $Source 'PathConfig-Capture-' "Hidden capture does not use an application-owned temporary filename."
Assert-Contains $Source '2>&1' "Hidden capture does not collect standard error."
Assert-Contains $Source 'fso\.DeleteFile\(tempPath, true\)' "Hidden capture does not clean up its temporary output."
Assert-Contains $Source 'finally\s*\{' "Temporary output cleanup is not protected by finally."

Assert-Contains $Source 'function readRunAsAdminFlags\(path\)' "Administrator-property status check is missing."
Assert-Contains $Source 'if \(!trimText\(path\)\) \{\s*return ''<td><div class="readonly no" title="No path configured">N/A</div></td>'';' "Empty administrator-property status is not neutral."
Assert-Contains $Source 'function writeRunAsAdminFlags\(path, flags\)' "Administrator-property write method is missing."
Assert-Contains $Source 'function deleteRunAsAdminFlags\(path\)' "Administrator-property delete method is missing."
Assert-Contains $Source 'AppCompatFlags\\\\Layers' "Administrator compatibility registry target is missing."
Assert-Contains $Source 'var output = runCapture\(command\)' "Administrator-property status does not use hidden capture."
if ([regex]::Matches($Source, 'return wsh\.Run\(command, 0, true\)').Count -lt 2) {
    $Failures.Add("Administrator-property write/delete commands are not both hidden.")
}
Assert-Contains $Source 'function cleanupOwnedStartup\(result\)' "Managed startup cleanup is missing."
Assert-Contains $Source 'PathConfig_Path_' "Managed startup prefix is missing."
Assert-Contains $Source 'HKCU\\\\Environment\\\\' "Per-user environment registry target is missing."
Assert-Contains $Source 'HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run\\\\' "Per-user startup registry target is missing."
Assert-Contains $Source 'function configuredEnvironmentVariables\(\)' "Path-Config environment collector is missing."
Assert-Contains $Source 'function expandPathVariables\(value, variables\)' "Native %NAME% path expansion is missing."
Assert-Contains $Source 'Object\.prototype\.hasOwnProperty\.call\(variables, key\)' "Configured-variable priority lookup is missing."
Assert-Contains $Source 'wsh\.ExpandEnvironmentStrings\(token\)' "Windows environment fallback is missing."
Assert-Contains $Source 'function environmentRegistryType\(value\)' "Expandable registry-value type selection is missing."
Assert-Contains $Source '"REG_EXPAND_SZ"' "Native expandable environment registry values are missing."
Assert-Contains $Source 'captureElement\(target\);\s*markDirty\(\);' "Live dialog edits do not update configured-variable priority."
Assert-Contains $Source 'path = expandPathVariables\(rawPath, variables\)' "Apply flows do not resolve native variables before path actions."
Assert-Contains $Source 'var src = expandPathVariables\(link\.src, variables\)' "Link sources do not resolve native variables."
Assert-Contains $Source 'path = expandPathVariables\(path\);' "Executable, startup, or administrator paths do not resolve native variables."

Assert-Contains $Source 'function loadState\(\)' "INI load function is missing."
Assert-Contains $Source 'i \+ "_RunAsAdmin"' "Run-as-admin persistence field is missing."
Assert-Contains $Source 'i \+ "_RunOnStartup"' "Run-on-startup persistence field is missing."
Assert-Contains $Source 'legacyKey = String\(i\)' "Legacy persistent-path migration is missing."
Assert-Contains $Source 'tabButton\(0, "Paths"\)' "Fixed Paths tab is not first."
Assert-Contains $Source 'function movePersistent\(index, direction\)' "Persistent-row move handler is missing."
Assert-Contains $Source 'function movePersistentUp\(index\)' "Persistent-row right-click Move up handler is missing."
Assert-Contains $Source 'id="persistentMove_' "Combined persistent-row move destination is missing."
Assert-Contains $Source 'title="Left click: move down; right click: move up"' "Combined move-control guidance is missing."
Assert-Contains $Source 'onclick="movePersistent\(' "Combined move control does not move down on left-click."
Assert-Contains $Source 'oncontextmenu="return movePersistentUp\(' "Combined move control does not move up on right-click."
Assert-Contains $Source '<thead><tr><th></th><th>File path' "Combined move control is not the first Paths-table column."
Assert-Contains $Source 'out \+= ''<td class="move-cell"><button' "Combined move control is not the first row control."
Assert-NotContains $Source 'persistentMoveUp_' "Separate Move up control still exists."
Assert-NotContains $Source 'persistentMoveDown_' "Separate Move down control still exists."
Assert-Contains $Source 'state\.persistent\[index\] = state\.persistent\[targetIndex\]' "Persistent-row swap does not move the complete row object."
Assert-Contains $Source 'function queuePersistentMoveCursor\(index, cursorState\)' "Persistent-row cursor follow-up is missing."
Assert-Contains $Source 'class="button button-small row-menu-button"' "Persistent-row burger menu button is missing."
Assert-Contains $Source '&#9776;' "Persistent-row burger icon is missing."
Assert-Contains $Source '\.row-menu-button\s*\{\s*width: 30px;' "Persistent-row menu button size is not fixed."
Assert-Contains $Source 'function showPersistentRowMenu\(index, button\)' "Persistent-row menu display handler is missing."
Assert-Contains $Source 'onclick="return showPersistentRowMenu\(' "Burger menu does not open on left-click."
Assert-Contains $Source 'oncontextmenu="return showPersistentRowMenu\(' "Burger menu does not open on right-click."
Assert-Contains $Source '>Move to New Tab</button>' "Move to New Tab menu item is missing."
Assert-Contains $Source '>Delete Row</button>' "Delete Row menu item is missing."
Assert-Contains $Source 'function movePersistentToNewTab\(index\)' "Move-to-new-tab transaction is missing."
Assert-Contains $Source 'state\.data\[tabName\] = \{' "Move-to-new-tab data creation is missing."
Assert-Contains $Source 'state\.persistent\.splice\(index, 1\)' "Move-to-new-tab source-row deletion is missing."
Assert-Contains $Source 'if \(!state\.persistent\.length\)' "Move-to-new-tab does not preserve one fixed Paths row."
Assert-Contains $Source 'System\.Windows\.Forms\.Cursor' "Cursor follow-up does not use the Windows cursor API."
Assert-Contains $Source 'wsh\.Run\(command, 0, false\)' "Cursor follow-up is not launched with hidden window style 0."
Assert-Contains $Source 'function restartApplication\(\)' "Automatic restart function is missing."
Assert-Contains $Source 'window\.location\.reload\(true\)' "Automatic restart does not reload the running HTA instance."
Assert-Contains $Source 'function maintainLauncherBridge\(\)' "Launcher relaunch bridge is missing."
Assert-Contains $Source 'Path-Config\.heartbeat' "Launcher heartbeat path is missing."
Assert-Contains $Source 'Path-Config\.relaunch' "Launcher relaunch-request path is missing."
Assert-Contains $Source 'window\.setInterval\(maintainLauncherBridge, 1000\)' "Launcher bridge is not maintained periodically."
Assert-Contains $Source 'window\.attachEvent\("onunload", cleanupLauncherBridge\)' "Launcher bridge cleanup is not attached."
Assert-Contains $Source 'if \(isRestarting\)' "Automatic restart does not preserve restart-aware unload handling."
Assert-Contains $Source 'save changes to restart automatically' "Unsaved source-update guidance is missing."
Assert-Contains $Source 'function renderProgramPaths\(tabIndex, rows\)' "Programs tabs do not render Paths-style controls."
Assert-Contains $Source 'function browseDynamicPath\(tabIndex, index\)' "Programs-tab Browse handler is missing."
Assert-Contains $Source 'fieldInput\("dynamic", "paths", i, "path"' "Programs-tab file path control is missing."
Assert-Contains $Source 'fieldInput\("dynamic", "paths", i, "env_var"' "Programs-tab environment-variable control is missing."
Assert-Contains $Source 'checkboxInput\("dynamic", "paths", i, "run_as_admin"' "Programs-tab Run as Admin control is missing."
Assert-Contains $Source 'checkboxInput\("dynamic", "paths", i, "run_on_startup"' "Programs-tab Run on Startup control is missing."
Assert-Contains $Source 'function loadProgramPathRows\(ini, section\)' "Programs-tab path-row loader is missing."
Assert-Contains $Source 'i \+ "_Val", null' "Legacy Programs-tab path migration is missing."
Assert-Contains $Source 'i \+ "_Name", ""' "Legacy Programs-tab environment-name migration is missing."
Assert-Contains $Source 'PROGRAM_STARTUP_PREFIX = "PathConfig_Program_"' "Programs-tab startup prefix is missing."
Assert-Contains $Source 'function cleanupProgramStartup\(prefix, result\)' "Programs-tab startup cleanup is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_Path", row\.path\)' "Programs-tab path saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_EnvVar", row\.env_var\)' "Programs-tab environment-variable saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_RunAsAdmin", row\.run_as_admin' "Programs-tab administrator-flag saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_RunOnStartup", row\.run_on_startup' "Programs-tab startup-flag saving is missing."

$FunctionNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($Match in [regex]::Matches($Source, 'function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(')) {
    [void]$FunctionNames.Add($Match.Groups[1].Value)
}
foreach ($Match in [regex]::Matches($Source, '(?:onclick|oncontextmenu)="(?:return\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*\(')) {
    if (-not $FunctionNames.Contains($Match.Groups[1].Value)) {
        $Failures.Add("Undefined generated-HTML handler: $($Match.Groups[1].Value)")
    }
}

$ScriptMatch = [regex]::Match($Source, '(?s)<script[^>]*>(.*?)</script>')
if (-not $ScriptMatch.Success) {
    $Failures.Add("Embedded JScript block was not found.")
} else {
    $ParserPath = Join-Path ([System.IO.Path]::GetTempPath()) ("PathConfig-parser-" + [guid]::NewGuid().ToString("N") + ".js")
    try {
        $MigrationCheck = @'
var legacyProgramIni = {"PROGRAMS_Paths": {
    "1_Name": "TOOL_EXE",
    "1_Val": "C:\\Tools\\Tool.exe",
    "1_RunAsAdmin": "1",
    "1_RunOnStartup": "1"
}};
var legacyProgramRows = loadProgramPathRows(legacyProgramIni, "PROGRAMS_Paths");
if (legacyProgramRows.length !== 1 || legacyProgramRows[0].path !== "C:\\Tools\\Tool.exe" ||
        legacyProgramRows[0].env_var !== "TOOL_EXE" || legacyProgramRows[0].run_as_admin !== 1 ||
        legacyProgramRows[0].run_on_startup !== 1) {
    throw new Error("Legacy Programs path-row migration failed.");
}
var currentProgramIni = {"PROGRAMS_Paths": {
    "1_Path": "C:\\Tools\\Current.exe",
    "1_EnvVar": "CURRENT_EXE",
    "1_RunAsAdmin": "0",
    "1_RunOnStartup": "1"
}};
var currentProgramRows = loadProgramPathRows(currentProgramIni, "PROGRAMS_Paths");
if (currentProgramRows.length !== 1 || currentProgramRows[0].path !== "C:\\Tools\\Current.exe" ||
        currentProgramRows[0].env_var !== "CURRENT_EXE" || currentProgramRows[0].run_as_admin !== 0 ||
        currentProgramRows[0].run_on_startup !== 1) {
    throw new Error("Current Programs path-row loading failed.");
}
var savedVariableState = state;
state = {
    mode: "Config",
    activeUiTab: 0,
    activeProgramTab: 0,
    persistent: [
        {path: "%username%\\Google Drive", env_var: "GoogleDrive", run_as_admin: 0, run_on_startup: 0}
    ],
    tabs: ["PROGRAMS"],
    data: {
        "PROGRAMS": {
            paths: [],
            envs: [
                {name: "UserName", val: "D:\\DialogUser"},
                {name: "ToolRoot", val: "%GoogleDrive%\\Tools"},
                {name: "CycleA", val: "%CycleB%"},
                {name: "CycleB", val: "%CycleA%"}
            ],
            execs: [],
            links: []
        }
    }
};
var windowsEnvironment = {
    username: "C:\\WindowsUser",
    googledrive: "C:\\WindowsGoogleDrive",
    systemroot: "C:\\Windows"
};
wsh = {
    ExpandEnvironmentStrings: function(token) {
        var match = /^%([^%]+)%$/.exec(token);
        var key = match ? lower(match[1]) : "";
        return Object.prototype.hasOwnProperty.call(windowsEnvironment, key) ? windowsEnvironment[key] : token;
    }
};
var checkedExpandedPath = "";
fso = {
    FileExists: function(path) {
        checkedExpandedPath = path;
        return path === "D:\\DialogUser\\Google Drive\\Tools\\tool.exe";
    },
    FolderExists: function(path) { return false; }
};
if (expandPathVariables("%GoOgLeDrIvE%\\Tools\\tool.exe") !==
        "D:\\DialogUser\\Google Drive\\Tools\\tool.exe") {
    throw new Error("Path-Config variables did not override Windows variables case-insensitively.");
}
if (expandPathVariables("%ToolRoot%\\tool.exe") !==
        "D:\\DialogUser\\Google Drive\\Tools\\tool.exe") {
    throw new Error("Nested Path-Config variable expansion failed.");
}
if (expandPathVariables("%SystemRoot%\\System32") !== "C:\\Windows\\System32") {
    throw new Error("Windows environment-variable fallback failed.");
}
if (expandPathVariables("%MissingVariable%\\file.exe") !== "%MissingVariable%\\file.exe") {
    throw new Error("Unknown environment variables were not preserved.");
}
if (!/^%Cycle[AB]%$/.test(expandPathVariables("%CycleA%"))) {
    throw new Error("Cyclic Path-Config variables were not stopped safely.");
}
if (!pathExists("%ToolRoot%\\tool.exe") ||
        checkedExpandedPath !== "D:\\DialogUser\\Google Drive\\Tools\\tool.exe") {
    throw new Error("Path validation did not use the resolved path.");
}
if (!environmentExists("USERNAME") || !looksLikePath("%ToolRoot%\\tool.exe")) {
    throw new Error("Dialog variables were not available to environment and smart-path status checks.");
}
if (environmentRegistryType("%username%\\Tools") !== "REG_EXPAND_SZ" ||
        environmentRegistryType("C:\\Tools") !== "REG_SZ") {
    throw new Error("Native expandable registry value selection failed.");
}
state = savedVariableState;
wsh = null;
fso = null;
var emptyAdminCell = adminPropertyMatchCell("", false);
if (emptyAdminCell.indexOf('class="readonly no"') < 0 || emptyAdminCell.indexOf("N/A") < 0 ||
        emptyAdminCell.indexOf('class="readonly yes"') >= 0) {
    throw new Error("Empty administrator-property status is not neutral.");
}
hasRunAsAdminProperty = function(path) { return false; };
var enabledMismatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", true);
var disabledMatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", false);
if (enabledMismatch.indexOf('class="readonly mismatch"') < 0 || enabledMismatch.indexOf(">Yes</div>") < 0) {
    throw new Error("Enabled checkbox mismatch does not show red Yes.");
}
if (disabledMatch.indexOf('class="readonly yes"') < 0 || disabledMatch.indexOf(">No</div>") < 0) {
    throw new Error("Disabled checkbox match does not show green No.");
}
hasRunAsAdminProperty = function(path) { return true; };
var disabledMismatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", false);
var enabledMatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", true);
if (disabledMismatch.indexOf('class="readonly mismatch"') < 0 || disabledMismatch.indexOf(">No</div>") < 0) {
    throw new Error("Disabled checkbox mismatch does not show red No.");
}
if (enabledMatch.indexOf('class="readonly yes"') < 0 || enabledMatch.indexOf(">Yes</div>") < 0) {
    throw new Error("Enabled checkbox match does not show green Yes.");
}
fso = new ActiveXObject("Scripting.FileSystemObject");
wsh = new ActiveXObject("WScript.Shell");
var livePickerMarker = runPickerScript("Add-Type -AssemblyName System.Windows.Forms;" +
    "$fileDialog=New-Object System.Windows.Forms.OpenFileDialog;" +
    "$fileDialog.InitialDirectory='C:\\';" +
    "$folderDialog=New-Object System.Windows.Forms.FolderBrowserDialog;" +
    "$folderDialog.SelectedPath='C:\\';" +
    "[Console]::Out.Write('PATHCONFIG_PICKER:'+$fileDialog.InitialDirectory+'|'+$folderDialog.SelectedPath)");
if (livePickerMarker !== "C:\\|C:\\") {
    throw new Error("Native picker construction or helper command/capture quoting failed.");
}
var browseFolders = {"C:\\": true, "D:\\Tools": true, "E:\\Data": true};
fso = {
    FolderExists: function(path) { return browseFolders[path] === true; },
    GetParentFolderName: function(path) {
        var slash = path.lastIndexOf("\\");
        return slash > 2 ? path.substr(0, slash) : path.substr(0, 3);
    }
};
lastBrowseDirectory = "C:\\";
if (sanitizeBrowsedPath("d:\\Tools\\Tool.exe", false) !== "D:\\Tools\\Tool.exe" ||
        sanitizeBrowsedPath("e:\\Data\\", true) !== "E:\\Data" ||
        sanitizeBrowsedPath("c:\\", true) !== "C:\\" ||
        sanitizeBrowsedPath("\\\\server\\share\\", true) !== "\\\\server\\share") {
    throw new Error("Browsed-path sanitization did not normalize drive letters and folder endings safely.");
}
if (currentBrowseDirectory() !== "C:\\") {
    throw new Error("First browse directory is not C:\\.");
}
rememberBrowseDirectory("D:\\Tools\\Tool.exe");
if (lastBrowseDirectory !== "D:\\Tools") {
    throw new Error("Selected file directory was not remembered.");
}
rememberBrowseDirectory("E:\\Data");
if (lastBrowseDirectory !== "E:\\Data") {
    throw new Error("Selected folder was not remembered.");
}
lastBrowseDirectory = "Z:\\Missing";
if (currentBrowseDirectory() !== "C:\\" || lastBrowseDirectory !== "C:\\") {
    throw new Error("Invalid remembered directory did not fall back to C:\\.");
}
var realRunPickerScript = runPickerScript;
var pickerScript = "";
var pickedPath = "";
runPickerScript = function(script) {
    pickerScript = script;
    return "d:\\Tools\\Tool.exe";
};
browseFile(function(path) { pickedPath = path; }, ".exe");
if (pickedPath !== "D:\\Tools\\Tool.exe" || lastBrowseDirectory !== "D:\\Tools" ||
        pickerScript.indexOf("System.Windows.Forms.OpenFileDialog") < 0 ||
        pickerScript.indexOf("$dialog.InitialDirectory='C:\\';") < 0 ||
        pickerScript.indexOf("Executable files (*.exe)") < 0) {
    throw new Error("File picker did not start at C:\\ and remember the selected file directory.");
}
runPickerScript = function(script) {
    pickerScript = script;
    return "e:\\Data\\";
};
pickedPath = "";
browseFolder(function(path) { pickedPath = path; }, "Select target folder");
if (pickedPath !== "E:\\Data" || lastBrowseDirectory !== "E:\\Data" ||
        pickerScript.indexOf("System.Windows.Forms.FolderBrowserDialog") < 0 ||
        pickerScript.indexOf("$dialog.SelectedPath='D:\\Tools';") < 0 ||
        pickerScript.indexOf("SpecialFolder]::Desktop") < 0) {
    throw new Error("Folder picker did not use the remembered directory or full PC tree.");
}
var pickerCommand = "";
var pickerAlert = "";
runCapture = function(command) {
    pickerCommand = command;
    return "PATHCONFIG_PICKER:F:\\Apps\\Tool.exe";
};
alert = function(message) { pickerAlert = message; };
var markedPath = realRunPickerScript("picker-body");
if (markedPath !== "F:\\Apps\\Tool.exe" || pickerCommand.indexOf("-STA -WindowStyle Hidden") < 0) {
    throw new Error("Picker runner did not return the marked path through a hidden STA helper.");
}
runCapture = function(command) { return "PATHCONFIG_PICKER_ERROR:Picker failed"; };
if (realRunPickerScript("picker-body") !== "" || pickerAlert.indexOf("Picker failed") < 0) {
    throw new Error("Picker runner did not report a marked picker error.");
}
var firstPersistentRow = {path: "A", env_var: "A_ENV", run_as_admin: 1, run_on_startup: 0};
var secondPersistentRow = {path: "B", env_var: "B_ENV", run_as_admin: 0, run_on_startup: 1};
var thirdPersistentRow = {path: "C", env_var: "C_ENV", run_as_admin: 1, run_on_startup: 1};
state.persistent = [firstPersistentRow, secondPersistentRow, thirdPersistentRow];
var moveDirty = false;
var moveRendered = false;
var queuedMoveIndex = -1;
var realQueuePersistentMoveCursor = queuePersistentMoveCursor;
captureState = function() {};
markDirty = function() { moveDirty = true; };
render = function() { moveRendered = true; };
queuePersistentMoveCursor = function(index, cursorState) {
    queuedMoveIndex = index;
};
window = {event: {srcElement: null, returnValue: true}};
var contextResult = movePersistentUp(1);
if (state.persistent[0] !== secondPersistentRow || state.persistent[1] !== firstPersistentRow ||
        state.persistent[2] !== thirdPersistentRow || !moveDirty || !moveRendered ||
        queuedMoveIndex !== 0 || contextResult !== false || window.event.returnValue !== false) {
    throw new Error("Right-click did not move the persistent row up and suppress the context menu.");
}
moveDirty = false;
moveRendered = false;
queuedMoveIndex = -1;
window.event.returnValue = true;
movePersistentUp(0);
if (state.persistent[0] !== secondPersistentRow || moveDirty || moveRendered || queuedMoveIndex !== -1 ||
        window.event.returnValue !== false) {
    throw new Error("Right-click moved a persistent row beyond the upper boundary.");
}
movePersistent(0, 1);
if (state.persistent[0] !== firstPersistentRow || state.persistent[1] !== secondPersistentRow ||
        state.persistent[2] !== thirdPersistentRow || queuedMoveIndex !== 1) {
    throw new Error("Left-click did not move the persistent row down as a complete object.");
}
state.tabs = ["B"];
state.data = {"B": {paths: [], envs: [], execs: [], links: []}};
state.persistent = [firstPersistentRow, secondPersistentRow];
fso = {
    GetBaseName: function(path) {
        var slash = Math.max(path.lastIndexOf("\\"), path.lastIndexOf("/"));
        var name = slash >= 0 ? path.substr(slash + 1) : path;
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substr(0, dot) : name;
    }
};
secondPersistentRow.path = "C:\\Tools\\B.exe";
movePersistentToNewTab(1);
if (state.tabs.length !== 2 || state.tabs[1] !== "B_2" || state.persistent.length !== 1 ||
        state.persistent[0] !== firstPersistentRow || state.activeProgramTab !== 1 || state.activeUiTab !== 2 ||
        state.data.B_2.paths.length !== 1 || state.data.B_2.paths[0].path !== secondPersistentRow.path ||
        state.data.B_2.paths[0].env_var !== secondPersistentRow.env_var ||
        state.data.B_2.paths[0].run_as_admin !== 0 || state.data.B_2.paths[0].run_on_startup !== 1) {
    throw new Error("Persistent row was not moved completely into a uniquely named program tab.");
}
firstPersistentRow.path = "C:\\Tools\\A.exe";
movePersistentToNewTab(0);
if (state.persistent.length !== 1 || state.persistent[0].path !== "" ||
        state.persistent[0].env_var !== "" || state.persistent[0].run_as_admin !== 0 ||
        state.persistent[0].run_on_startup !== 0 || state.tabs[2] !== "A") {
    throw new Error("Moving the only persistent row did not leave the required empty fixed row.");
}
var fakeTabMenu = {style: {display: "block"}};
var fakeRowMenu = {style: {}, offsetWidth: 190};
var fakeDeleteMenuItem = {disabled: false};
document = {
    body: {scrollLeft: 0, scrollTop: 0},
    getElementById: function(id) {
        if (id === "contextMenu") { return fakeTabMenu; }
        if (id === "persistentRowMenu") { return fakeRowMenu; }
        if (id === "persistentRowDelete") { return fakeDeleteMenuItem; }
        return null;
    }
};
window = {event: {cancelBubble: false, returnValue: true}};
var fakeBurgerButton = {getBoundingClientRect: function() { return {right: 250, bottom: 80}; }};
var rowMenuResult = showPersistentRowMenu(0, fakeBurgerButton);
if (rowMenuResult !== false || persistentMenuIndex !== 0 || fakeRowMenu.style.display !== "block" ||
        fakeRowMenu.style.left !== "60px" || fakeRowMenu.style.top !== "80px" ||
        !fakeDeleteMenuItem.disabled || !window.event.cancelBubble || window.event.returnValue !== false ||
        fakeTabMenu.style.display !== "none") {
    throw new Error("Persistent-row burger menu did not open correctly for the first row.");
}
hidePersistentRowMenu();
showPersistentRowMenu(1, fakeBurgerButton);
if (fakeDeleteMenuItem.disabled || persistentMenuIndex !== 1) {
    throw new Error("Delete Row did not enable for a later persistent row.");
}
hidePersistentRowMenu();
var cursorTargetId = "";
var cursorCommand = "";
var cursorStyle = -1;
var cursorWait = true;
var cursorDelay = 0;
window = {
    screenLeft: 200,
    screenTop: 100,
    setTimeout: function(callback, delay) {
        cursorDelay = delay;
        callback();
    }
};
document = {
    getElementById: function(id) {
        cursorTargetId = id;
        return {getBoundingClientRect: function() { return {left: 40, top: 50}; }};
    }
};
wsh = {
    Run: function(command, style, wait) {
        cursorCommand = command;
        cursorStyle = style;
        cursorWait = wait;
        return 0;
    }
};
realQueuePersistentMoveCursor(1, {
    screen_x: 500,
    screen_y: 400,
    control_left: 10,
    control_top: 20,
    window_left: 180,
    window_top: 90
});
if (cursorTargetId !== "persistentMove_1" || cursorDelay !== 60 || cursorStyle !== 0 || cursorWait !== false ||
        cursorCommand.indexOf("ArgumentList 550,440") < 0) {
    throw new Error("Persistent-row cursor did not follow the moved button correctly.");
}
var restartReloadForced = null;
var restartStatus = "";
window = {location: {reload: function(force) { restartReloadForced = force; }}};
setStatus = function(message) { restartStatus = message; };
sourceReloadPending = true;
isRestarting = false;
hasUnsavedChanges = false;
restartApplication();
if (restartReloadForced !== true || sourceReloadPending || !isRestarting || hasUnsavedChanges) {
    throw new Error("Automatic restart did not reload the running HTA safely.");
}
restartReloadForced = null;
restartStatus = "";
sourceReloadPending = true;
isRestarting = false;
hasUnsavedChanges = true;
saveState = function(showMessage) { return false; };
restartApplication();
if (restartReloadForced !== null || sourceReloadPending || isRestarting ||
        restartStatus.indexOf("could not be saved") < 0) {
    throw new Error("Automatic restart did not stop when unsaved changes failed to save.");
}
var watcherStatus = "";
var watcherRestarted = false;
getSourceSignature = function() { return "new-signature"; };
setStatus = function(message) { watcherStatus = message; };
restartApplication = function() { watcherRestarted = true; sourceReloadPending = false; };
sourceSignature = "old-signature";
sourceReloadPending = false;
sourceChangeTime = 0;
hasUnsavedChanges = true;
watchForSourceUpdate();
if (!sourceReloadPending || sourceSignature !== "new-signature") {
    throw new Error("Source update was not detected.");
}
sourceChangeTime = new Date().valueOf() - 2000;
watchForSourceUpdate();
if (!sourceReloadPending || watcherRestarted || watcherStatus.indexOf("save changes") < 0) {
    throw new Error("Unsaved changes did not defer automatic restart.");
}
hasUnsavedChanges = false;
watchForSourceUpdate();
if (!watcherRestarted || sourceReloadPending) {
    throw new Error("Saved source update did not restart automatically.");
}
'@
        [System.IO.File]::WriteAllText(
            $ParserPath,
            $ScriptMatch.Groups[1].Value + "`r`n" + $MigrationCheck,
            [System.Text.UTF8Encoding]::new($false)
        )
        $ParserOutput = & "$env:SystemRoot\System32\cscript.exe" //nologo $ParserPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            $Failures.Add("JScript parser failed: " + ($ParserOutput -join " "))
        }
    } finally {
        Remove-Item -LiteralPath $ParserPath -Force -ErrorAction SilentlyContinue
    }
}

if ($Failures.Count -gt 0) {
    foreach ($Failure in $Failures) {
        Write-Error $Failure
    }
    exit 1
}

Write-Host "PASS: Path-Config HTA v$ExpectedVersion static and parser checks succeeded."
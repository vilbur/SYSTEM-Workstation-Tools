$ErrorActionPreference = "Stop"

$ExpectedVersion = "0.66"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $ProjectRoot "Path-Config.hta"
$DebugScriptPath = Join-Path $ProjectRoot "Debug\Print-Startup-Registry.ps1"
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
Assert-Contains $Source 'function moveProgramTab\(direction\)' "Program-tab move function is missing."
Assert-Contains $Source 'state\.tabs\[index\] = state\.tabs\[targetIndex\];[\s\S]*?state\.tabs\[targetIndex\] = tabName;' "Program-tab move does not swap the complete keyed tab order."
Assert-Contains $Source 'state\.activeProgramTab = targetIndex;\s*state\.activeUiTab = targetIndex \+ 1;[\s\S]*?render\(true\);' "Program-tab move does not preserve selection and window size."
Assert-Contains $Source 'onclick="moveProgramTab\(-1\)"' "Move-tab-left controls are missing."
Assert-Contains $Source 'onclick="moveProgramTab\(1\)"' "Move-tab-right controls are missing."

if (-not (Test-Path -LiteralPath $DebugScriptPath -PathType Leaf)) {
    $Failures.Add("Missing startup registry debug script: $DebugScriptPath")
} else {
    $DebugSource = [System.IO.File]::ReadAllText($DebugScriptPath)
    Assert-Contains $DebugSource 'OpenBaseKey\(' "Debug script does not use explicit registry views."
    Assert-Contains $DebugSource 'Registry64' "Debug script does not inspect the 64-bit registry view."
    Assert-Contains $DebugSource 'Registry32' "Debug script does not inspect the 32-bit registry view."
    Assert-Contains $DebugSource 'CurrentVersion\\Run' "Debug script does not inspect Run entries."
    Assert-Contains $DebugSource 'CurrentVersion\\RunOnce' "Debug script does not inspect RunOnce entries."
    Assert-Contains $DebugSource 'StartupApproved' "Debug script does not inspect Windows StartupApproved records."
    Assert-Contains $DebugSource 'FromFileTimeUtc' "Debug script does not decode StartupApproved timestamps."
    Assert-NotContains $DebugSource '(?i)\.SetValue\(|\.DeleteValue\(|New-ItemProperty|Set-ItemProperty|Remove-ItemProperty|reg(?:\.exe)?\s+(?:add|delete)' "Debug script contains a registry-write operation."

    $DebugTokens = $null
    $DebugParseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($DebugScriptPath, [ref]$DebugTokens, [ref]$DebugParseErrors) | Out-Null
    if ($DebugParseErrors.Count -gt 0) {
        $Failures.Add("Startup registry debug script does not parse: " + (($DebugParseErrors | ForEach-Object { $_.Message }) -join "; "))
    } else {
        try {
            $DebugRecords = @(& $DebugScriptPath -PassThru)
            foreach ($DebugRecord in $DebugRecords) {
                if ($null -eq $DebugRecord.PSObject.Properties['RecordType'] -or
                        $null -eq $DebugRecord.PSObject.Properties['RegistryPath'] -or
                        $null -eq $DebugRecord.PSObject.Properties['State']) {
                    $Failures.Add("Startup registry debug script returned an incomplete record.")
                    break
                }
            }
        } catch {
            $Failures.Add("Startup registry debug script failed during its read-only check: " + $_.Exception.Message)
        }
    }
}
Assert-Contains $Source 'var VERSION = "0\.66";' "HTA internal version is not 0.66."
Assert-Contains $Source 'document\.title = "Path-Config v" \+ VERSION' "GUI title does not use the internal version."
Assert-Contains $Source 'HTA edition &middot; v' "Visible HTA version label is missing."
Assert-Contains $Source 'function render\(preserveWindowSize\)' "Render does not accept the window-size preservation flag."
Assert-Contains $Source 'if \(!preserveWindowSize\) \{\s*window\.setTimeout\(fitWindowToContent, 0\);\s*\}' "Content fitting is not conditional."
Assert-Contains $Source 'function selectTab\(index\)[\s\S]*?render\(true\);' "Tab changes do not preserve the current window size."
Assert-Contains $Source '\.button\s*\{\s*min-width: 126px;[\s\S]*?border: 1px solid #444850;\s*background: #2a2d32;\s*color: #f0f1f2;\s*cursor: pointer;\s*\}' "The v0.39 available button surface was not preserved."
Assert-Contains $Source '\.save-state-frozen,\s*\.save-state-frozen:hover\s*\{\s*border-color: #444850;\s*background: #2a2d32;\s*color: #686d75;\s*cursor: default;\s*\}' "Frozen Save State does not keep the v0.39 resting surface with only grey text."
Assert-NotContains $Source '\.button\[disabled\]' "Native disabled styling still affects Save State."
Assert-NotContains $Source 'disabled="disabled"' "Save State still uses the native disabled attribute."
Assert-Contains $Source 'id="saveStateButton" class="button" onclick="saveState\(true\)"' "Available Save State did not restore its original direct action and base class."
Assert-Contains $Source 'id="saveStateButton" class="button save-state-frozen">SAVE STATE</button>' "Frozen Save State markup is missing."
Assert-Contains $Source 'function updateSaveStateButton\(\)' "Live Save State button synchronization is missing."
Assert-Contains $Source 'button\.className = hasUnsavedChanges \? "button" : "button save-state-frozen"' "Live Save State button class is not synchronized."
Assert-Contains $Source 'button\.onclick = hasUnsavedChanges \? function\(\) \{ saveState\(true\); \} : null' "Live Save State action is not restored or removed with availability."
Assert-NotContains $Source 'saveStateIfAvailable' "Available and frozen Save State still share the guarded handler."
Assert-Contains $Source 'hasUnsavedChanges = false;\s*updateSaveStateButton\(\);' "Successful saving does not freeze Save State immediately."
Assert-Contains $Source 'hasUnsavedChanges && !saveState\(false, true\)' "Config-to-Apply mode change does not auto-save pending changes."
Assert-Contains $Source 'Could not enter Apply mode because state could not be saved' "Apply mode does not stop with a clear status when auto-save fails."
Assert-NotContains $Source 'Admin property matches' "Apply mode still uses the old administrator-property header."
if ([regex]::Matches($Source, '<th class="status-header status-admin">ADMIN</th>').Count -lt 2) {
    $Failures.Add("Colored ADMIN header is not used in both path tables.")
}
if ([regex]::Matches($Source, '<th class="status-header status-start">STARTUP</th>').Count -lt 2) {
    $Failures.Add("Colored STARTUP header is not used in both path tables.")
}
if ([regex]::Matches($Source, '<th class="status-header status-menu">MENU</th>').Count -lt 2) {
    $Failures.Add("Colored MENU header is not used in both path tables.")
}
Assert-Contains $Source 'status-admin">ADMIN</th><th class="status-header status-start">STARTUP</th><th class="status-header status-menu">MENU</th>' "ADMIN, STARTUP, and MENU are not adjacent in the requested order."
Assert-Contains $Source '\.path-table \.status-header\s*\{\s*padding-right: 8px;\s*padding-left: 8px;\s*text-align: center;' "Status headers do not provide 16px between adjacent labels."
Assert-Contains $Source '\.path-table \.status-admin\s*\{\s*color: #f2a23a;' "ADMIN label is not orange."
Assert-Contains $Source '\.path-table \.status-start\s*\{\s*color: #69c77d;' "STARTUP label is not green."
Assert-Contains $Source '\.path-table \.status-menu\s*\{\s*color: #5aa9e6;' "MENU label is not blue."
Assert-Contains $Source '\(expected \? "Yes" : "No"\)' "Administrator detail does not describe the configured checkbox state."
Assert-Contains $Source 'function booleanStatusCell\(value, statusClass, title\)' "Shared Apply-mode boolean-symbol renderer is missing."
Assert-Contains $Source 'statusClass === "mismatch" \? "&#10008;" : "&#10004;"' "YES does not map to a red cross or green check according to status color."
Assert-Contains $Source 'value \? [\s\S]*? : "&nbsp;"' "NO and N/A statuses do not render as blank space."
Assert-Contains $Source '\.readonly\.boolean-status\s*\{\s*min-width: 30px;\s*padding-right: 0;\s*padding-left: 0;\s*overflow: visible;\s*text-align: center;\s*text-overflow: clip;' "Boolean symbol cells can still be truncated or ellipsized."
Assert-Contains $Source 'class="readonly boolean-status ' "Boolean symbol renderers do not use the permanent centered status class."
Assert-NotContains $Source '(?-i:>N/A</div>|\(expected \? "YES" : "NO"\)|\(pinned \? "YES" : "NO"\)|\(value \? "YES" : "NO"\))' "A visible YES, NO, or N/A status label remains in the renderer."
Assert-Contains $Source 'if \(state\.mode === "Config"\) \{[\s\S]*?<th>Link name</th>[\s\S]*?\} else \{[\s\S]*?class="data-table program-table links-apply-table"[\s\S]*?<th>Source</th><th>Link path</th><th>Type</th>' "Links does not use the compact Source/Link path/Type table only in APPLY mode."
Assert-Contains $Source 'sameDirectory = linkDirectoriesAreSame\(row\.src, row\.tgt_dir\);[\s\S]*?readonlyCell\(row\.src, sameDirectory \? "same-directory" : "pathcheck"\)[\s\S]*?readonlyCell\(target, sameDirectory \? "same-directory" : ""\)' "Links APPLY rows do not mark matching Source and Link paths orange."
Assert-Contains $Source '<th>Link folder</th>' "Links CONFIG table does not label the destination directory as Link folder."
Assert-Contains $Source '<th>Link name</th>' "Links CONFIG table does not label the created name as Link name."
Assert-Contains $Source 'function linkNameFromSource\(source\)' "Link Name source-name resolver is missing."
Assert-Contains $Source 'kind === "links" && field === "src" ?' "Typed Link sources do not trigger Link Name autofill only after a real source change."
Assert-Contains $Source 'function autofillLinkName\(sourceInput, row, oldSource\)[\s\S]*?currentName && currentName !== oldDefault' "Link Name autofill does not preserve a user-supplied name."
Assert-Contains $Source 'if \(!trimText\(row\.tgt_name\) \|\| trimText\(row\.tgt_name\) === oldDefault\) \{\s*row\.tgt_name = linkNameFromSource\(path\);' "Browsed Link sources do not autofill only an empty Link Name."
Assert-Contains $Source '<th>Link path</th>' "Links APPLY table does not label the combined destination as Link path."
Assert-NotContains $Source '<th>Target(?: folder| name)?</th>' "Target terminology remains in a Links UI column label."
Assert-NotContains $Source '"Select target folder"' "Target terminology remains in the Link-folder picker title."
Assert-Contains $Source 'var previousLinkFolder = rows\.length \? trimText\(rows\[rows\.length - 1\]\.tgt_dir\) : "";' "New Links rows do not derive Link folder from the previous row."
Assert-Contains $Source 'rows\.push\(\{src: "", tgt_dir: previousLinkFolder, tgt_name: "", type: "Symlink"\}\);' "New Links rows do not use the Symlink default while inheriting Link folder."
Assert-Contains $Source '\.field\.same-directory\s*\{\s*border-color: #b86f16;\s*color: #f2a23a;' "Config-mode same-directory paths do not use the orange warning style."
Assert-Contains $Source '\.readonly\.same-directory\s*\{\s*border-bottom-color: #b86f16;\s*color: #f2a23a;' "Apply-mode same-directory paths do not use the orange warning style."
if ([regex]::Matches($Source, 'data-linkdirectorycheck="1"').Count -ne 2) {
    $Failures.Add("Source and Link folder fields do not both participate in same-directory validation.")
}
Assert-Contains $Source 'function normalizedDirectoryPath\(path\)' "Case-insensitive directory normalization is missing."
Assert-Contains $Source 'function linkDirectoriesAreSame\(source, linkDirectory\)' "Source/Link directory comparison is missing."
Assert-Contains $Source 'fso\.GetParentFolderName\(source\)' "Same-directory comparison does not use the Source item's containing folder."
Assert-Contains $Source 'function linkInputDirectoriesAreSame\(input\)' "Live Link input comparison is missing."
Assert-Contains $Source 'linkInputDirectoriesAreSame\(inputs\[i\]\)[\s\S]*?className \+= " same-directory";' "Live validation does not apply the orange same-directory class."
Assert-Contains $Source 'className = inputs\[i\]\.className\.indexOf\("path-field"\) >= 0 \? "field path-field" : "field";' "Live validation does not preserve the File Path minimum-width class."
Assert-Contains $Source 'data-table path-table' "Path tables do not use the dedicated wide-layout class."
if ([regex]::Matches($Source, 'class="data-table path-table"').Count -lt 2) {
    $Failures.Add("The fixed and Programs path tables do not both use the dedicated layout.")
}
Assert-Contains $Source '<col style="width:40px"><col style="width:56px"><col style="width:56px"><col style="width:56px">' "Fixed Paths does not begin with compact Menu, ADMIN, STARTUP, and MENU columns."
Assert-Contains $Source '<col><col style="width:84px"><col style="width:20%">' "Programs Paths does not use a compact Browse column around the flexible File Path."
if ([regex]::Matches($Source, '<col style="width:56px"><col style="width:56px"><col style="width:56px">').Count -lt 2) {
    $Failures.Add("Both path tables do not reserve spaced ADMIN, STARTUP, and MENU columns.")
}
Assert-Contains $Source '<col style="width:84px"><col><col style="width:20%"><col style="width:40px">' "Fixed Paths does not end with Browse, File path, Environment variable, and position columns."
Assert-Contains $Source '<col style="width:50px"><col style="width:15%"><col style="width:130px"><col style="width:40px">' "Links Link Name column is not preserved at 15% within the compact layout."
Assert-Contains $Source 'html, body\s*\{\s*margin: 0;\s*min-width: 1350px;' "Application canvas is too narrow for restored columns and 560px path controls."
Assert-Contains $Source '\.path-table\s*\{\s*min-width: 1270px;' "Path tables do not preserve enough width for restored columns and path controls."
Assert-Contains $Source '\.path-field\s*\{\s*min-width: 560px;' "File Path edit controls do not have a 560px minimum width."
Assert-Contains $Source 'var className = field === "path" \? "field path-field" : "field";' "Path inputs do not receive the minimum-width class."
Assert-Contains $Source 'var desiredWidth = Math\.max\(1, Math\.floor\(availableWidth / 2\)\);' "Content-fit sizing is not capped at half the display."
Assert-Contains $Source 'var initialWidth = Math\.max\(1, Math\.floor\(screen\.availWidth / 2\)\);' "Initial sizing is not capped at half the display."
Assert-Contains $Source '\.section-action\s*\{\s*display: inline-block;\s*margin-left: 10px;' "Tab section buttons do not use the approved inline layout."
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
Assert-Contains $Source '\.links-apply-table td:last-child\s*\{\s*text-align: left;' "Links APPLY Type values are not left-aligned."
Assert-Contains $Source '\.program-table \.button-small\s*\{\s*box-sizing: border-box;\s*width: 30px;\s*margin-left: 0;\s*padding-right: 0;\s*padding-left: 0;' "Dynamic-tab row buttons are not compact 30px controls."
Assert-Contains $Source '\.program-table \.row-action-pair \.button-small \+ \.button-small\s*\{\s*margin-left: 20px;' "Paired D/F buttons do not have an exact 20px gap."
Assert-Contains $Source '<col style="width:20%"><col>''\s*\+\s*''<col style="width:100px"><col style="width:40px">' "Environment Variables rows do not use compact action columns."
Assert-Contains $Source '<col><col style="width:100px"><col style="width:40px">' "Executable rows do not use compact action columns."
Assert-Contains $Source '<col><col style="width:100px"><col>''\s*\+\s*''<col style="width:50px"><col style="width:15%"><col style="width:130px"><col style="width:40px">' "Links rows do not use compact action columns while preserving Link Name."
Assert-Contains $Source '\.path-table \.check-wrap input\s*\{\s*width: 20px;\s*height: 20px;\s*margin: 0;' "Path checkboxes are not enlarged."
Assert-Contains $Source 'function checkboxTooltip\(field\)' "Checkbox tooltip resolver is missing."
Assert-Contains $Source 'Run this executable as administrator' "ADMIN checkbox tooltip is missing."
Assert-Contains $Source 'Run this executable when you sign in' "STARTUP checkbox tooltip is missing."
Assert-Contains $Source 'Create or verify this executable or shortcut in the Start11 menu' "MENU checkbox tooltip does not describe .exe and .lnk support."
Assert-Contains $Source '<label class="check-wrap" title="'' \+ html\(tooltip\)' "Checkbox labels do not expose their tooltip."
Assert-Contains $Source '<input type="checkbox" title="'' \+' "Checkbox inputs do not expose their tooltip."
Assert-NotContains $Source '> Yes</label>' "Config-mode checkboxes still display the Yes label."
Assert-Contains $Source '\.move-cell\s*\{\s*padding-right: 0 !important;\s*text-align: right;' "Position button is not aligned to the right edge."
Assert-Contains $Source '\.row-menu-cell\s*\{\s*padding-left: 0 !important;\s*text-align: left;' "Row menu button is not aligned to the left edge."
Assert-Contains $Source '<td class="row-menu-cell"><button' "Persistent-row menu does not use the leftmost fixed-row cell."
Assert-Contains $Source 'var lastBrowseDirectory = "C:\\\\";' "Initial browse directory is not C:\\."
Assert-Contains $Source 'function currentBrowseDirectory\(preferredPath\)' "Preferred/remembered browse-directory resolver is missing."
Assert-Contains $Source 'function rememberBrowseDirectory\(path\)' "Browse-directory memory function is missing."
Assert-Contains $Source 'function sanitizeBrowsedPath\(path, isFolder\)' "Central browsed-path sanitizer is missing."
Assert-Contains $Source 'function normalizeConfigPathValue\(element, value\)' "Config-mode path normalizer is missing."
Assert-Contains $Source 'state\.mode === "Config"[\s\S]*?normalizeConfigPathValue\(element, value\)' "Path normalization is not limited to Config-mode capture."
Assert-Contains $Source 'element\.getAttribute\("data-pathcheck"\) === "1"' "Path fields do not opt into Config-mode normalization."
Assert-Contains $Source 'element\.getAttribute\("data-smartcheck"\) === "1"[\s\S]*?looksLikePath\(value\)' "Path-like value fields do not opt into Config-mode normalization."
Assert-Contains $Source 'expanded && fso\.FolderExists\(expanded\) && !/\\\\\$/.test\(value\)' "Existing Config-mode directories do not receive a missing trailing backslash."
Assert-Contains $Source 'path = path\.charAt\(0\)\.toUpperCase\(\) \+ path\.substr\(1\)' "Browsed drive letters are not capitalized."
Assert-Contains $Source 'while \(/\\\\\$/.test\(path\)\)[\s\S]*?path \+= "\\\\";' "Browsed folders do not end in exactly one trailing backslash."
Assert-Contains $Source 'sanitizeBrowsedPath\(runPickerScript\(script\), true\)' "Native folder results are not sanitized."
Assert-Contains $Source 'sanitizeBrowsedPath\(runPickerScript\(script\), false\)' "Native file results are not sanitized."
Assert-Contains $Source 'function runPickerScript\(script\)' "Native picker runner is missing."
Assert-Contains $Source 'System\.Windows\.Forms\.OpenFileDialog' "Full-PC file picker is missing."
Assert-Contains $Source 'var NATIVE_FOLDER_DIALOG_CSHARP' "Native folder-dialog bridge is missing."
Assert-Contains $Source 'PathConfig\.NativeFolderDialog' "IFileOpenDialog folder picker call is missing."
Assert-Contains $Source 'FromBase64String' "Native folder-dialog bridge is not decoded safely."
Assert-NotContains $Source 'System\.Windows\.Forms\.FolderBrowserDialog' "Unsupported legacy FolderBrowserDialog remains."
Assert-Contains $Source '\$dialog\.InitialDirectory=' "File picker does not use the remembered directory."
Assert-Contains $Source 'PathConfig\.NativeFolderDialog\]::Show\([\s\S]*?powerShellLiteral\(currentBrowseDirectory\(initialPath\)\)' "Native folder picker does not resolve the field-first initial directory."
Assert-Contains $Source 'powershell\.exe -NoProfile -STA -WindowStyle Hidden -Command' "Native picker is not launched in STA mode with a hidden helper window."
Assert-Contains $Source 'PATHCONFIG_PICKER:' "Native picker result marker is missing."
Assert-Contains $Source 'function browseFolder\(callback, title, initialPath\)' "Folder picker does not accept a field initial path."
Assert-Contains $Source 'function browseFile\(callback, accept, initialPath\)' "File picker does not accept a field initial path."
Assert-Contains $Source 'browseFile\(done, kind === "execs" \? "\.exe" : "", initialPath\)' "Dynamic file Browse does not pass the current field path."
Assert-Contains $Source 'browseFolder\(done, "Select folder", initialPath\)' "Dynamic folder Browse does not pass the current field path."
Assert-Contains $Source 'browseFolder\(done, "Select source folder", initialPath\)' "Link-source folder Browse does not pass its current field path."
Assert-Contains $Source '"Select link folder", initialPath\)' "Link-target Browse does not pass its current field path."
if ([regex]::Matches($Source, 'rememberBrowseDirectory\(path\);').Count -lt 2) {
    $Failures.Add("File and folder pickers do not both remember the selected directory.")
}
Assert-NotContains $Source 'BrowseForFolder\(' "Legacy app-directory-rooted folder picker is still present."
Assert-NotContains $Source 'input\.type = "file"' "Legacy HTML file input is still present."
Assert-NotContains $Source 'new ActiveXObject\("Shell\.Application"\)' "Unused legacy Shell.Application picker dependency remains."
if ([regex]::Matches($Source, 'oncontextmenu="return showBrowseContextMenu\(this\)"').Count -ne 9) {
    $Failures.Add("Not every file/folder Browse button opens the shared right-click menu.")
}
Assert-Contains $Source 'function browseButtonPath\(button\)' "Browse-menu adjacent-field resolver is missing."
Assert-Contains $Source 'function showBrowseContextMenu\(button\)' "Browse-button right-click menu handler is missing."
Assert-Contains $Source 'function hideBrowseContextMenu\(\)' "Browse-button menu hide handler is missing."
Assert-Contains $Source 'function findBrowsePathInExplorer\(\)' "Find in Explorer action is missing."
Assert-Contains $Source 'id="browseContextMenu"' "Browse-button context-menu element is missing."
Assert-Contains $Source '>Find in Explorer</button>' "Find in Explorer menu item is missing."
Assert-Contains $Source 'var path = expandPathVariables\(browseMenuPath\)' "Find in Explorer does not expand configured environment variables."
Assert-Contains $Source 'wsh\.Run\(quoteArg\(explorer\) \+ " /select," \+ quoteArg\(path\), 1, false\)' "Find in Explorer does not select the target in a visible non-blocking Explorer window."
Assert-Contains $Source 'hideBrowseContextMenu\(\);\s*\}' "Shared menu cleanup does not include the Browse menu."

Assert-Contains $Source 'function runCapture\(command\)' "runCapture() is missing."
Assert-NotContains $Source 'wsh\.Exec\s*\(' "WScript.Shell.Exec can flash a console window and must not be used."
Assert-Contains $Source 'wsh\.Run\(hiddenCommand, 0, true\)' "Captured commands are not run synchronously with hidden window style 0."
Assert-Contains $Source 'ExpandEnvironmentStrings\("%ComSpec%"\)' "Hidden capture does not use the configured command shell."
Assert-Contains $Source 'PathConfig-Capture-' "Hidden capture does not use an application-owned temporary filename."
Assert-Contains $Source '2>&1' "Hidden capture does not collect standard error."
Assert-Contains $Source 'fso\.DeleteFile\(tempPath, true\)' "Hidden capture does not clean up its temporary output."
Assert-Contains $Source 'finally\s*\{' "Temporary output cleanup is not protected by finally."

Assert-Contains $Source 'function menuPinMatchCell\(path, expected\)' "Apply-mode Start11 Menu status check is missing."
Assert-Contains $Source 'function readStart11PinValues\(registryKey\)' "Start11 registry-value reader is missing."
Assert-Contains $Source 'function readStart11PinTreeValues\(registryRoot\)' "Recursive Start11 registry-tree reader is missing."
Assert-Contains $Source 'START11_PIN_ROOTS' "Start11 root groups are missing."
Assert-Contains $Source 'function isStart11TargetPinned\(path\)' "Start11 target-pin check is missing."
Assert-Contains $Source 'function ensureStart11MenuPin\(path, runAsAdmin, result, rowLabel\)' "Start11 pin apply action is missing."
Assert-Contains $Source 'function removeStart11MenuPin\(path, result, rowLabel\)' "Start11 remove/sync action is missing."
Assert-Contains $Source 'function createStart11Shortcut\(shortcutPath, targetPath\)' "Start11 shortcut creation is missing."
Assert-Contains $Source 'function start11ShortcutDetails\(path\)' "Existing .lnk metadata reader is missing."
Assert-Contains $Source 'function start11MenuSourceInfo\(path\)' "Start11 .exe/.lnk source resolver is missing."
Assert-Contains $Source 'function resolveRunAsAdminPath\(path\)' "Administrator-property shortcut-target resolver is missing."
Assert-Contains $Source 'function start11ShortcutSignature\(path\)' "Shortcut target-and-arguments signature is missing."
Assert-Contains $Source 'function isStart11MenuSourcePinned\(path\)' "Shortcut-aware Start11 pin status is missing."
Assert-Contains $Source 'function copyStart11Shortcut\(sourcePath, shortcutPath\)' "Existing .lnk copy action is missing."
Assert-Contains $Source 'fso\.CopyFile\(sourcePath, shortcutPath, false\)' "Existing .lnk files are not copied without overwrite."
Assert-Contains $Source 'function start11GroupContainsSignature\(values, signature\)' "Start11 duplicate detection does not preserve shortcut arguments."
Assert-Contains $Source 'Menu requires an existing \.exe or \.lnk with an existing target' "Invalid Menu input does not describe .lnk support."
Assert-Contains $Source 'shortcut\.TargetPath = targetPath' "Created Start11 shortcuts do not target the configured executable."
Assert-Contains $Source 'shortcut\.Save\(\)' "Created Start11 shortcuts are not saved."
Assert-Contains $Source 'START11_PIN_DIRECTORY = "%APPDATA%\\\\Microsoft\\\\Internet Explorer\\\\Quick Launch\\\\User Pinned\\\\StartMenu"' "Start11 shortcut directory is incorrect."
Assert-Contains $Source 'Start8\.ini\\\\GroupContents\\\\\$PINNEDDEF\$' "Classic Start11 pin registry group is missing."
Assert-Contains $Source 'Start8\.ini\\\\GroupContents11\\\\\$\$APPS\$\$' "Start11 Apps registry group is missing."
Assert-Contains $Source '\|\-1\|1\|\-1\|\-1' "Classic Start11 pin suffix is missing."
Assert-Contains $Source '\|\-1\|0\|\-1\|\-1' "Start11 Apps pin suffix is missing."
Assert-Contains $Source 'nextStart11ValueName\(values\)' "Start11 registry values do not use the next numeric index."
Assert-Contains $Source 'wsh\.RegWrite\(START11_PIN_GROUPS\[i\]\.key \+ "\\\\" \+ valueName' "Start11 pin registry entry is not written."
Assert-Contains $Source 'wsh\.RegDelete\(values\[j\]\.registry_key \+ "\\\\" \+ values\[j\]\.name\)' "Matching Start11 registrations are not removed."
Assert-Contains $Source 'start11ShortcutSignature\(shortcutPath\) === sourceInfo\.signature' "Start11 shortcut deletion is not guarded by exact target-and-arguments signature."
Assert-Contains $Source 'runAsAdmin && !hasRunAsAdminProperty\(sourceInfo\.target_path\)' "Admin Menu shortcuts are not verified against their resolved executable target."
if ([regex]::Matches($Source, 'start11PinCache = null').Count -lt 3) {
    $Failures.Add("Start11 state is not refreshed on render, add, and remove operations.")
}
if ([regex]::Matches($Source, 'ensureStart11MenuPin\(path, (?:row|item)\.run_as_admin').Count -lt 2) {
    $Failures.Add("Fixed and Programs Apply flows do not both ensure checked Start11 pins.")
}
if ([regex]::Matches($Source, 'removeStart11MenuPin\(path, result').Count -lt 2) {
    $Failures.Add("Fixed and Programs Apply flows do not both remove unchecked Start11 pins.")
}
Assert-Contains $Source 'function readRunAsAdminFlags\(path\)' "Administrator-property status check is missing."
Assert-Contains $Source 'if \(!trimText\(path\)\) \{\s*return booleanStatusCell\(false, "no", "No path configured"\);' "Empty administrator-property status is not blank and neutral."
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
Assert-Contains $Source 'STARTUP_APPROVED_KEY = "HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Explorer\\\\StartupApproved\\\\Run"' "Windows Startup Apps approval target is missing or uses the wrong registry view."
Assert-Contains $Source 'STARTUP_APPROVED_ENABLED = "020000000000000000000000"' "Windows Startup Apps enabled binary state is missing."
Assert-Contains $Source 'function isOwnedStartupName\(name\)' "Startup Apps ownership guard is missing."
Assert-Contains $Source 'function writeStartupApproval\(name, result, rowLabel\)' "Startup Apps enabled-state writer is missing."
Assert-Contains $Source 'function cleanupStartupApprovals\(prefix, result\)' "Startup Apps reconciliation cleanup is missing."
Assert-Contains $Source '/t REG_BINARY /d " \+ data \+ " /f"' "Startup Apps status is not written as REG_BINARY."
Assert-Contains $Source 'isOwnedStartupName\(name\) && lower\(name\)\.substr\(0, normalizedPrefix\.length\) === normalizedPrefix' "Startup Apps cleanup is not constrained to an owned scoped prefix."
Assert-Contains $Source 'cleanupStartupApprovals\(STARTUP_PREFIX, result\)' "Fixed startup reconciliation does not remove stale owned approval state."
Assert-Contains $Source 'cleanupStartupApprovals\(prefix, result\)' "Programs startup reconciliation does not remove stale scoped approval state."
if ([regex]::Matches($Source, 'syncStartupState\(path, (?:row|item)\.run_on_startup').Count -lt 2) {
    $Failures.Add("Fixed and Programs startup rows do not both synchronize against existing Windows Startup Apps entries.")
}
Assert-NotContains $Source 'StartupApproved\\\\Run32' "Startup Apps status uses Run32 instead of the live per-user Run approval key."
Assert-Contains $Source 'function startupCommandTarget\(command\)' "Existing startup command target parsing is missing."
Assert-Contains $Source 'function readUserRunEntries\(\)' "Current-user Run entry enumeration is missing."
Assert-Contains $Source 'function findExistingStartupEntry\(path\)' "Exact existing startup entry matching is missing."
Assert-Contains $Source 'function readStartupApprovalState\(name\)' "Live Windows Startup Apps approval reading is missing."
Assert-Contains $Source 'function startupStateForPath\(path\)' "Live startup state resolution is missing."
Assert-Contains $Source 'function startupMatchCell\(path, expected\)' "Apply-mode startup state does not mirror Windows Startup Apps."
if ([regex]::Matches($Source, 'startupMatchCell\(row\.path, row\.run_on_startup\)').Count -lt 2) {
    $Failures.Add("Common and Programs Apply rows do not both show live Windows Startup Apps status.")
}
Assert-Contains $Source 'function startupApprovedDisabledData\(\)' "Windows Startup Apps disabled state generation is missing."
Assert-Contains $Source 'function writeExistingStartupApproval\(name, enabled, result, rowLabel\)' "Existing startup approval synchronization is missing."
Assert-Contains $Source 'function syncStartupState\(path, enabled, elevate, ownedName, result, rowLabel\)' "Existing-or-owned startup synchronization dispatcher is missing."
Assert-Contains $Source 'matchingStartupEntries\(path, true\)' "Existing-entry adoption is not limited to unowned exact matches."
Assert-Contains $Source 'matches multiple existing Windows Startup Apps entries; no state was changed' "Ambiguous existing startup matches are not rejected safely."
Assert-Contains $Source 'wsh\.RegWrite\(REG_RUN \+ ownedName, command, "REG_SZ"\)' "Missing existing entries do not fall back to the current owned Run-value behavior."
Assert-Contains $Source 'return "03000000" \+ uint32LittleEndianHex\(low\) \+ uint32LittleEndianHex\(high\)' "Disabled StartupApproved data does not contain state plus FILETIME."
Assert-Contains $Source 'function configuredEnvironmentVariables\(\)' "Path-Config environment collector is missing."
Assert-Contains $Source 'function expandPathVariables\(value, variables\)' "Native %NAME% path expansion is missing."
Assert-Contains $Source 'Object\.prototype\.hasOwnProperty\.call\(variables, key\)' "Configured-variable priority lookup is missing."
Assert-Contains $Source 'wsh\.ExpandEnvironmentStrings\(token\)' "Windows environment fallback is missing."
Assert-Contains $Source 'function environmentRegistryType\(value\)' "Expandable registry-value type selection is missing."
Assert-Contains $Source '"REG_EXPAND_SZ"' "Native expandable environment registry values are missing."
Assert-Contains $Source 'if \(captureElement\(target\)\) \{\s*markDirty\(\);' "Live dialog edits do not mark only real value changes dirty."
Assert-Contains $Source 'document\.attachEvent\("onkeyup", trackInputChange\)' "HTA keyboard edits do not immediately update dirty state."
Assert-Contains $Source 'document\.attachEvent\("onpropertychange", trackInputChange\)' "HTA paste and MSHTML value changes do not immediately update dirty state."
Assert-Contains $Source 'path = expandPathVariables\(rawPath, variables\)' "Apply flows do not resolve native variables before path actions."
Assert-Contains $Source 'var src = expandPathVariables\(link\.src, variables\)' "Link sources do not resolve native variables."
Assert-Contains $Source 'path = expandPathVariables\(path\);' "Executable, startup, or administrator paths do not resolve native variables."

Assert-Contains $Source 'function loadState\(\)' "INI load function is missing."
Assert-Contains $Source 'i \+ "_RunAsAdmin"' "Run-as-admin persistence field is missing."
Assert-Contains $Source 'i \+ "_RunOnStartup"' "Run-on-startup persistence field is missing."
Assert-Contains $Source 'i \+ "_Menu"' "Persistent Menu field loading is missing."
Assert-Contains $Source 'entry\(lines, \(i \+ 1\) \+ "_Menu", row\.menu' "Persistent Menu field saving is missing."
Assert-Contains $Source 'checkboxInput\("persistent", "", i, "menu", row\.menu\)' "Fixed Paths Menu checkbox is missing."
Assert-Contains $Source 'legacyKey = String\(i\)' "Legacy persistent-path migration is missing."
Assert-Contains $Source 'tabButton\(0, "Common"\)' "Fixed Common tab is not first."
Assert-NotContains $Source 'tabButton\(0, "Paths"\)' "The fixed first tab still displays the old Paths label."
Assert-Contains $Source 'lower\(name\) !== "paths" && lower\(name\) !== "common"' "Loaded program tabs do not reserve both legacy Paths and visible Common names."
Assert-Contains $Source 'lower\(newName\) === "paths" \|\| lower\(newName\) === "common"' "Program-tab rename does not reserve both Paths and Common."
Assert-Contains $Source 'function movePersistent\(index, direction\)' "Persistent-row move handler is missing."
Assert-Contains $Source 'function movePersistentUp\(index\)' "Persistent-row right-click Move up handler is missing."
Assert-Contains $Source 'id="persistentMove_' "Combined persistent-row move destination is missing."
Assert-Contains $Source 'title="Left click: move down; right click: move up"' "Combined move-control guidance is missing."
Assert-Contains $Source 'onclick="movePersistent\(' "Combined move control does not move down on left-click."
Assert-Contains $Source 'oncontextmenu="return movePersistentUp\(' "Combined move control does not move up on right-click."
Assert-Contains $Source '<thead><tr><th></th><th class="status-header status-admin">ADMIN</th>' "Fixed Paths does not begin with Menu, ADMIN, STARTUP, and MENU columns."
Assert-Contains $Source 'out \+= ''<td class="move-cell"><button' "Combined position control is missing from the last fixed-row column."
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
Assert-Contains $Source 'checkboxInput\("dynamic", "paths", i, "menu"' "Programs-tab Menu control is missing."
Assert-Contains $Source 'function loadProgramPathRows\(ini, section\)' "Programs-tab path-row loader is missing."
Assert-Contains $Source 'i \+ "_Val", null' "Legacy Programs-tab path migration is missing."
Assert-Contains $Source 'i \+ "_Name", ""' "Legacy Programs-tab environment-name migration is missing."
Assert-Contains $Source 'PROGRAM_STARTUP_PREFIX = "PathConfig_Program_"' "Programs-tab startup prefix is missing."
Assert-Contains $Source 'function cleanupProgramStartup\(prefix, result\)' "Programs-tab startup cleanup is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_Path", row\.path\)' "Programs-tab path saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_EnvVar", row\.env_var\)' "Programs-tab environment-variable saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_RunAsAdmin", row\.run_as_admin' "Programs-tab administrator-flag saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_RunOnStartup", row\.run_on_startup' "Programs-tab startup-flag saving is missing."
Assert-Contains $Source 'entry\(lines, \(j \+ 1\) \+ "_Menu", row\.menu' "Programs-tab Menu flag saving is missing."

$BridgeMatch = [regex]::Match($Source, 'var NATIVE_FOLDER_DIALOG_CSHARP =(?<value>[\s\S]*?);')
if (-not $BridgeMatch.Success) {
    $Failures.Add("Native folder-dialog bridge constant could not be read.")
} else {
    $EncodedBridge = ([regex]::Matches($BridgeMatch.Groups["value"].Value, '"([A-Za-z0-9+/=]+)"') |
        ForEach-Object { $_.Groups[1].Value }) -join ""
    try {
        $BridgeSource = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedBridge))
        foreach ($RequiredBridgeMarker in @(
            'Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")',
            'PickFolders = 0x00000020',
            'ForceFileSystem = 0x00000040',
            'PathMustExist = 0x00000800',
            'SHCreateItemFromParsingName',
            'SetDefaultFolder',
            'GetForegroundWindow',
            'ShellDisplayName.FileSystemPath'
        )) {
            if (-not $BridgeSource.Contains($RequiredBridgeMarker)) {
                $Failures.Add("Native folder-dialog bridge is missing: $RequiredBridgeMarker")
            }
        }
        Add-Type -TypeDefinition $BridgeSource -Language CSharp -ErrorAction Stop
    } catch {
        $Failures.Add("Native folder-dialog bridge did not decode or compile: $($_.Exception.Message)")
    }
}
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
if (linkNameFromSource("C:\\Tools\\Widget.exe") !== "Widget.exe" ||
        linkNameFromSource("C:\\Tools\\Widget\\") !== "Widget") {
    throw new Error("Link Name source-name resolver did not return the source item name.");
}
var linkNameInput = {
    value: "",
    getAttribute: function(name) {
        if (name === "data-scope") { return "dynamic"; }
        if (name === "data-kind") { return "links"; }
        if (name === "data-tab") { return "0"; }
        if (name === "data-index") { return "0"; }
        if (name === "data-field") { return "tgt_name"; }
        return "";
    }
};
var linkSourceInput = {
    type: "text",
    value: "C:\\Tools\\Widget.exe",
    getAttribute: function(name) {
        if (name === "data-scope") { return "dynamic"; }
        if (name === "data-kind") { return "links"; }
        if (name === "data-tab") { return "0"; }
        if (name === "data-index") { return "0"; }
        if (name === "data-field") { return "src"; }
        return "";
    }
};
document = {
    getElementsByTagName: function(name) {
        return name === "input" ? [linkSourceInput, linkNameInput] : [];
    }
};
state.mode = "Config";
state.tabs = ["PROGRAMS"];
state.data = {"PROGRAMS": {links: [{src: "", tgt_name: ""}]}};
if (!captureElement(linkSourceInput) ||
        state.data.PROGRAMS.links[0].tgt_name !== "Widget.exe" ||
        linkNameInput.value !== "Widget.exe") {
    throw new Error("Typed Link source did not autofill an empty Link Name.");
}
linkSourceInput.value = "C:\Tools\Widget-Final.exe";
captureElement(linkSourceInput);
if (state.data.PROGRAMS.links[0].tgt_name !== "Widget-Final.exe" ||
        linkNameInput.value !== "Widget-Final.exe") {
    throw new Error("Automatically derived Link Name did not follow continued Source typing.");
}
state.data.PROGRAMS.links[0].tgt_name = "Custom.exe";
linkNameInput.value = "Custom.exe";
linkSourceInput.value = "C:\\Other\\Replacement.exe";
captureElement(linkSourceInput);
if (state.data.PROGRAMS.links[0].tgt_name !== "Custom.exe" ||
        linkNameInput.value !== "Custom.exe") {
    throw new Error("Link source change overwrote a custom Link Name.");
}
var legacyProgramIni = {"PROGRAMS_Paths": {
    "1_Name": "TOOL_EXE",
    "1_Val": "C:\\Tools\\Tool.exe",
    "1_RunAsAdmin": "1",
    "1_RunOnStartup": "1"
}};
var legacyProgramRows = loadProgramPathRows(legacyProgramIni, "PROGRAMS_Paths");
if (legacyProgramRows.length !== 1 || legacyProgramRows[0].path !== "C:\\Tools\\Tool.exe" ||
        legacyProgramRows[0].env_var !== "TOOL_EXE" || legacyProgramRows[0].run_as_admin !== 1 ||
        legacyProgramRows[0].run_on_startup !== 1 || legacyProgramRows[0].menu !== 0) {
    throw new Error("Legacy Programs path-row migration failed.");
}
var currentProgramIni = {"PROGRAMS_Paths": {
    "1_Path": "C:\\Tools\\Current.exe",
    "1_EnvVar": "CURRENT_EXE",
    "1_RunAsAdmin": "0",
    "1_RunOnStartup": "1",
    "1_Menu": "1"
}};
var currentProgramRows = loadProgramPathRows(currentProgramIni, "PROGRAMS_Paths");
if (currentProgramRows.length !== 1 || currentProgramRows[0].path !== "C:\\Tools\\Current.exe" ||
        currentProgramRows[0].env_var !== "CURRENT_EXE" || currentProgramRows[0].run_as_admin !== 0 ||
        currentProgramRows[0].run_on_startup !== 1 || currentProgramRows[0].menu !== 1) {
    throw new Error("Current Programs path-row loading failed.");
}
var savedLinkPrefillState = state;
var savedLinkCaptureState = captureState;
var savedLinkMarkDirty = markDirty;
var savedLinkRender = render;
var linkPrefillDirty = false;
var linkPrefillRendered = false;
state = {
    tabs: ["PROGRAMS"],
    data: {"PROGRAMS": {
        paths: [],
        envs: [],
        execs: [],
        links: [{src: "C:\\Source.txt", tgt_dir: "  D:\\Links  ", tgt_name: "Source.txt", type: "Shortcut"}]
    }}
};
captureState = function() {};
markDirty = function() { linkPrefillDirty = true; };
render = function() { linkPrefillRendered = true; };
addDynamicRow(0, "links");
var inheritedLink = state.data.PROGRAMS.links[1];
if (!linkPrefillDirty || !linkPrefillRendered || inheritedLink.src !== "" ||
        inheritedLink.tgt_dir !== "D:\\Links" || inheritedLink.tgt_name !== "" ||
        inheritedLink.type !== "Symlink") {
    throw new Error("New Link row did not inherit only the previous non-empty Link folder with the Symlink default.");
}
state.data.PROGRAMS.links[1].tgt_dir = "   ";
addDynamicRow(0, "links");
if (state.data.PROGRAMS.links[2].tgt_dir !== "") {
    throw new Error("New Link row did not remain empty after an unfilled previous Link folder.");
}
state = savedLinkPrefillState;
captureState = savedLinkCaptureState;
markDirty = savedLinkMarkDirty;
render = savedLinkRender;
var savedSameDirectoryFso = fso;
var savedSameDirectoryExpand = expandPathVariables;
var savedSameDirectoryState = state;
expandPathVariables = function(value) {
    return String(value).replace(/%ROOT%/gi, "C:\\Work");
};
fso = {
    GetAbsolutePathName: function(path) { return path; },
    GetParentFolderName: function(path) {
        path = String(path).replace(/\//g, "\\");
        var slash = path.lastIndexOf("\\");
        return slash >= 0 ? path.substr(0, slash) : "";
    }
};
if (!linkDirectoriesAreSame("%ROOT%\\Source.txt", "c:/work/") ||
        linkDirectoriesAreSame("C:\\Work\\Source.txt", "C:\\Elsewhere")) {
    throw new Error("Source and Link directory comparison is not normalized and case-insensitive.");
}
state = {
    tabs: ["PROGRAMS"],
    data: {"PROGRAMS": {
        links: [{src: "C:\\Work\\Source.txt", tgt_dir: "c:\\work"}]
    }}
};
var sameDirectoryInput = {
    value: "c:\\work\\",
    getAttribute: function(name) {
        var values = {"data-kind": "links", "data-tab": "0", "data-index": "0", "data-field": "tgt_dir"};
        return values[name] || "";
    }
};
if (!linkInputDirectoriesAreSame(sameDirectoryInput) ||
        readonlyCell("C:\\Work\\Source.txt", "same-directory").indexOf('class="readonly same-directory"') < 0) {
    throw new Error("Live or Apply-mode same-directory warning state was not produced.");
}
state = savedSameDirectoryState;
fso = savedSameDirectoryFso;
expandPathVariables = savedSameDirectoryExpand;
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
var savedApprovalRunCapture = runCapture;
var approvalCommand = "";
var approvalStyle = -1;
var approvalWait = false;
var approvalDeletes = [];
wsh = {
    ExpandEnvironmentStrings: function(value) {
        return value === "%SystemRoot%" ? "C:\\Windows" : value;
    },
    Run: function(command, style, wait) {
        approvalCommand = command;
        approvalStyle = style;
        approvalWait = wait;
        return 0;
    },
    RegDelete: function(path) {
        approvalDeletes.push(path);
    }
};
var approvalResult = {error_count: 0, success_count: 0};
if (!writeStartupApproval("PathConfig_Path_2", approvalResult, "Row 2") ||
        approvalCommand.indexOf('"C:\\Windows\\System32\\reg.exe" add') !== 0 ||
        approvalCommand.indexOf('"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run"') < 0 ||
        approvalCommand.indexOf('/v "PathConfig_Path_2" /t REG_BINARY /d 020000000000000000000000 /f') < 0 ||
        approvalStyle !== 0 || approvalWait !== true || approvalResult.error_count !== 0) {
    throw new Error("Startup Apps enabled state was not written safely through a hidden owned registry command.");
}
if (!isOwnedStartupName("PathConfig_Path_2") ||
        !isOwnedStartupName("pathconfig_program_3_1") ||
        isOwnedStartupName("UnrelatedStartup")) {
    throw new Error("Startup Apps ownership guard accepted or rejected the wrong value name.");
}
runCapture = function(command) {
    return "    PathConfig_Path_2    REG_BINARY    030000000000000000000000\r\n" +
        "    PathConfig_Program_3_1    REG_BINARY    030000000000000000000000\r\n" +
        "    UnrelatedStartup    REG_BINARY    030000000000000000000000\r\n";
};
cleanupStartupApprovals(STARTUP_PREFIX, approvalResult);
cleanupStartupApprovals(programStartupPrefix(2), approvalResult);
if (approvalDeletes.length !== 2 ||
        approvalDeletes[0] !== REG_STARTUP_APPROVED + "PathConfig_Path_2" ||
        approvalDeletes[1] !== REG_STARTUP_APPROVED + "PathConfig_Program_3_1" ||
        approvalResult.error_count !== 0) {
    throw new Error("Startup Apps cleanup did not remove only the requested Path-Config-owned approval values.");
}
var savedStartupAppendLog = appendLog;
appendLog = function() {};
var startupRunOutput =
    "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\r\n" +
    "    Display Fusion    REG_SZ    \"C:\\Tools\\DisplayFusion.exe\" /silent\r\n" +
    "    Other App    REG_SZ    \"C:\\Tools\\Other.exe\"\r\n";
runCapture = function(command) {
    if (command.indexOf("StartupApproved") >= 0) {
        return "    Display Fusion    REG_BINARY    030000001122334455667788\r\n";
    }
    return startupRunOutput;
};
fso = {
    FileExists: function(path) { return path === "C:\\Tools\\DisplayFusion.exe"; },
    FolderExists: function(path) { return false; },
    GetExtensionName: function(path) {
        var dot = String(path).lastIndexOf(".");
        return dot >= 0 ? String(path).substr(dot + 1) : "";
    },
    GetAbsolutePathName: function(path) { return path; }
};
var startupRegWrites = [];
wsh.RegWrite = function(path, value, type) {
    startupRegWrites.push({path: path, value: value, type: type});
};
startupStateCache = null;
if (startupCommandTarget('"C:\\Tools\\DisplayFusion.exe" /silent') !== "C:\\Tools\\DisplayFusion.exe" ||
        startupCommandTarget("C:\\Tools\\DisplayFusion.exe /silent") !== "C:\\Tools\\DisplayFusion.exe" ||
        startupCommandTarget(buildStartupCommand("C:\\Tools\\DisplayFusion.exe", true)) !==
            "C:\\Tools\\DisplayFusion.exe") {
    throw new Error("Existing startup command target parsing failed for quoted, unquoted, or elevated commands.");
}
var existingStartupState = startupStateForPath("C:\\Tools\\DisplayFusion.exe");
var existingStartupCell = startupMatchCell("C:\\Tools\\DisplayFusion.exe", true);
if (!existingStartupState.found || existingStartupState.ambiguous || existingStartupState.enabled ||
        existingStartupState.name !== "Display Fusion" ||
        existingStartupCell.indexOf('class="readonly boolean-status mismatch"') < 0 ||
        existingStartupCell.indexOf(">&#10008;</div>") < 0 ||
        existingStartupCell.indexOf("Windows Startup Apps: Off") < 0) {
    throw new Error("Path-Config startup status did not mirror the matching disabled Windows Startup Apps entry.");
}
var existingSyncResult = {startup_count: 0, success_count: 0, error_count: 0};
approvalCommand = "";
syncStartupState("C:\\Tools\\DisplayFusion.exe", true, false,
    "PathConfig_Path_1", existingSyncResult, "Row 1");
if (startupRegWrites.length !== 0 || existingSyncResult.startup_count !== 1 ||
        existingSyncResult.success_count !== 1 || existingSyncResult.error_count !== 0 ||
        approvalCommand.indexOf('/v "Display Fusion" /t REG_BINARY /d 020000000000000000000000 /f') < 0) {
    throw new Error("A unique existing startup entry was not enabled without rewriting its Run command.");
}
approvalCommand = "";
syncStartupState("C:\\Tools\\DisplayFusion.exe", false, false,
    "PathConfig_Path_1", existingSyncResult, "Row 1");
if (startupRegWrites.length !== 0 || existingSyncResult.success_count !== 2 ||
        !/\/v "Display Fusion" \/t REG_BINARY \/d 03000000[0-9A-F]{16} \/f/.test(approvalCommand)) {
    throw new Error("A unique existing startup entry was not disabled with a timestamped StartupApproved state.");
}
startupRunOutput = "    First Match    REG_SZ    \"C:\\Tools\\DisplayFusion.exe\"\r\n" +
    "    Second Match    REG_SZ    \"C:\\Tools\\DisplayFusion.exe\" /other\r\n";
startupStateCache = null;
approvalCommand = "";
var ambiguousErrors = existingSyncResult.error_count;
syncStartupState("C:\\Tools\\DisplayFusion.exe", false, false,
    "PathConfig_Path_1", existingSyncResult, "Row 1");
if (existingSyncResult.error_count !== ambiguousErrors + 1 || approvalCommand !== "" ||
        startupRegWrites.length !== 0) {
    throw new Error("Ambiguous existing startup entries were modified instead of rejected.");
}
startupRunOutput = "    Other App    REG_SZ    \"C:\\Tools\\Other.exe\"\r\n";
startupStateCache = null;
approvalCommand = "";
startupRegWrites = [];
var fallbackResult = {startup_count: 0, success_count: 0, error_count: 0};
syncStartupState("C:\\Tools\\DisplayFusion.exe", true, false,
    "PathConfig_Path_4", fallbackResult, "Row 4");
if (startupRegWrites.length !== 1 ||
        startupRegWrites[0].path !== REG_RUN + "PathConfig_Path_4" ||
        startupRegWrites[0].value !== '"C:\\Tools\\DisplayFusion.exe"' ||
        startupRegWrites[0].type !== "REG_SZ" || fallbackResult.startup_count !== 1 ||
        fallbackResult.success_count !== 1 || fallbackResult.error_count !== 0 ||
        approvalCommand.indexOf('/v "PathConfig_Path_4" /t REG_BINARY /d 020000000000000000000000 /f') < 0) {
    throw new Error("Missing existing startup entry did not fall back to the owned PathConfig Run entry behavior.");
}
if (!/^03000000[0-9A-F]{16}$/.test(startupApprovedDisabledData())) {
    throw new Error("Disabled StartupApproved data is not a 12-byte state plus FILETIME value.");
}
appendLog = savedStartupAppendLog;
runCapture = savedApprovalRunCapture;
wsh = null;
var savedMenuFso = fso;
var savedMenuWsh = wsh;
var savedMenuReadValues = readStart11PinValues;
var savedMenuReadTreeValues = readStart11PinTreeValues;
var savedMenuAppendLog = appendLog;
var menuSourcePath = "C:\\Links\\Tool.lnk";
var menuTargetPath = "C:\\Tools\\Tool.exe";
var menuPinnedPath = "C:\\Pinned\\Tool.lnk";
var menuFiles = {};
menuFiles[menuSourcePath] = true;
menuFiles[menuTargetPath] = true;
var menuCopiedFrom = "";
var menuCopiedTo = "";
var menuGroupValues = [[], []];
var menuCustomValues = [];
fso = {
    FileExists: function(path) { return menuFiles[path] === true; },
    FolderExists: function(path) { return path === "C:\\Pinned"; },
    GetExtensionName: function(path) {
        var dot = String(path).lastIndexOf(".");
        return dot >= 0 ? String(path).substr(dot + 1) : "";
    },
    GetAbsolutePathName: function(path) { return path; },
    GetBaseName: function(path) {
        var slash = String(path).lastIndexOf("\\");
        var name = slash >= 0 ? String(path).substr(slash + 1) : String(path);
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substr(0, dot) : name;
    },
    GetParentFolderName: function(path) {
        var slash = String(path).lastIndexOf("\\");
        return slash >= 0 ? String(path).substr(0, slash) : "";
    },
    BuildPath: function(directory, name) { return directory + "\\" + name; },
    CopyFile: function(sourcePath, destinationPath, overwrite) {
        if (overwrite || !menuFiles[destinationPath]) {
            menuCopiedFrom = sourcePath;
            menuCopiedTo = destinationPath;
            menuFiles[destinationPath] = true;
            return;
        }
        throw new Error("Destination exists");
    }
};
wsh = {
    ExpandEnvironmentStrings: function(value) {
        return value === START11_PIN_DIRECTORY ? "C:\\Pinned" : value;
    },
    CreateShortcut: function(path) {
        if (!menuFiles[path] || lower(fso.GetExtensionName(path)) !== "lnk") {
            throw new Error("Missing shortcut");
        }
        return {
            TargetPath: menuTargetPath,
            Arguments: "--profile Work"
        };
    },
    RegWrite: function(registryPath, data, type) {
        var groupIndex = registryPath.indexOf(START11_PIN_GROUPS[1].key) === 0 ? 1 : 0;
        menuGroupValues[groupIndex].push({
            registry_key: START11_PIN_GROUPS[groupIndex].key,
            name: String(menuGroupValues[groupIndex].length),
            data: data,
            shortcut_path: data.substr(0, data.indexOf("|"))
        });
    },
    RegDelete: function(registryPath) {
        if (registryPath.indexOf("\\CustomGroup\\") >= 0) {
            menuCustomValues = [];
            return;
        }
        var groupIndex = registryPath.indexOf(START11_PIN_GROUPS[1].key) === 0 ? 1 : 0;
        var valueName = registryPath.substr(registryPath.lastIndexOf("\\") + 1);
        var kept = [];
        var i;
        for (i = 0; i < menuGroupValues[groupIndex].length; i++) {
            if (menuGroupValues[groupIndex][i].name !== valueName) {
                kept.push(menuGroupValues[groupIndex][i]);
            }
        }
        menuGroupValues[groupIndex] = kept;
    }
};
readStart11PinValues = function(registryKey) {
    return registryKey === START11_PIN_GROUPS[1].key ? menuGroupValues[1] : menuGroupValues[0];
};
readStart11PinTreeValues = function(registryRoot) {
    return registryRoot === START11_PIN_ROOTS[1] ? menuGroupValues[1] :
        menuCustomValues.concat(menuGroupValues[0]);
};
appendLog = function() {};
start11PinCache = null;
var menuSourceInfo = start11MenuSourceInfo(menuSourcePath);
if (!menuSourceInfo || menuSourceInfo.target_path !== menuTargetPath ||
        menuSourceInfo.arguments !== "--profile Work" ||
        menuSourceInfo.signature !== normalizedStart11Path(menuTargetPath) + "\n--profile Work" ||
        resolveRunAsAdminPath(menuSourcePath) !== menuTargetPath) {
    throw new Error("Existing .lnk source did not preserve and resolve its executable target and arguments.");
}
var menuResult = {
    menu_pin_count: 0,
    menu_created_count: 0,
    menu_removed_count: 0,
    success_count: 0,
    error_count: 0
};
ensureStart11MenuPin(menuSourcePath, false, menuResult, "Shortcut row");
if (menuCopiedFrom !== menuSourcePath || menuCopiedTo !== menuPinnedPath ||
        menuGroupValues[0].length !== 1 || menuGroupValues[1].length !== 1 ||
        menuResult.menu_pin_count !== 1 || menuResult.menu_created_count !== 1 ||
        menuResult.success_count !== 1 || menuResult.error_count !== 0 ||
        !isStart11MenuSourcePinned(menuSourcePath)) {
    throw new Error("Existing .lnk source was not copied, registered, and verified with its arguments preserved.");
}
menuGroupValues[0][0].registry_key = START11_PIN_ROOTS[0] + "\\CustomGroup";
menuCustomValues.push(menuGroupValues[0][0]);
menuGroupValues[0] = [];
start11PinCache = null;
ensureStart11MenuPin(menuSourcePath, false, menuResult, "Shortcut row");
if (menuGroupValues[0].length !== 0 || menuCustomValues.length !== 1 || menuGroupValues[1].length !== 1 ||
        menuResult.menu_pin_count !== 2 || menuResult.error_count !== 0) {
    throw new Error("Repeated Start11 add recreated a root duplicate for a custom-group pin or lost live state.");
}
var uncheckedLiveMenuCell = menuPinMatchCell(menuSourcePath, false);
if (uncheckedLiveMenuCell.indexOf(">&#10004;</div>") < 0 ||
        uncheckedLiveMenuCell.indexOf("actual Start11 pin: Yes") < 0) {
    throw new Error("MENU status did not report the real pin when the saved checkbox was unchecked.");
}
fso.FolderExists = function() { return false; };
removeStart11MenuPin(menuSourcePath, menuResult, "Shortcut row");
removeStart11MenuPin(menuSourcePath, menuResult, "Shortcut row");
if (menuGroupValues[0].length !== 0 || menuCustomValues.length !== 0 || menuGroupValues[1].length !== 0 ||
        menuResult.menu_removed_count !== 2 || isStart11MenuSourcePinned(menuSourcePath)) {
    throw new Error("Repeated Start11 removal was not idempotent or left a stale live status.");
}
fso.FolderExists = function(path) { return path === "C:\\Pinned"; };
ensureStart11MenuPin(menuSourcePath, false, menuResult, "Shortcut row");
if (menuGroupValues[0].length !== 1 || menuGroupValues[1].length !== 1 ||
        !isStart11MenuSourcePinned(menuSourcePath)) {
    throw new Error("Start11 pin could not be added again after removal.");
}
start11PinCache = null;
fso = savedMenuFso;
wsh = savedMenuWsh;
readStart11PinValues = savedMenuReadValues;
readStart11PinTreeValues = savedMenuReadTreeValues;
appendLog = savedMenuAppendLog;
var enabledStartupCell = yesNoCell(true);
var disabledStartupCell = yesNoCell(false);
if (enabledStartupCell.indexOf('class="readonly boolean-status yes"') < 0 ||
        enabledStartupCell.indexOf(">&#10004;</div>") < 0 ||
        disabledStartupCell.indexOf('class="readonly boolean-status no"') < 0 ||
        disabledStartupCell.indexOf(">&nbsp;</div>") < 0) {
    throw new Error("Startup status does not render a green check for YES and blank space for NO.");
}
var emptyAdminCell = adminPropertyMatchCell("", false);
if (emptyAdminCell.indexOf('class="readonly boolean-status no"') < 0 ||
        emptyAdminCell.indexOf(">&nbsp;</div>") < 0 || emptyAdminCell.indexOf("N/A") >= 0 ||
        emptyAdminCell.indexOf('title="No path configured"') < 0) {
    throw new Error("Empty administrator-property status is not blank and neutral.");
}
hasRunAsAdminProperty = function(path) { return false; };
var enabledMismatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", true);
var disabledMatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", false);
if (enabledMismatch.indexOf('class="readonly boolean-status mismatch"') < 0 ||
        enabledMismatch.indexOf(">&#10008;</div>") < 0) {
    throw new Error("Enabled checkbox mismatch does not show a red cross.");
}
if (disabledMatch.indexOf('class="readonly boolean-status yes"') < 0 ||
        disabledMatch.indexOf(">&nbsp;</div>") < 0) {
    throw new Error("Disabled checkbox match is not blank.");
}
hasRunAsAdminProperty = function(path) { return true; };
var disabledMismatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", false);
var enabledMatch = adminPropertyMatchCell("C:\\Tools\\Tool.exe", true);
if (disabledMismatch.indexOf('class="readonly boolean-status mismatch"') < 0 ||
        disabledMismatch.indexOf(">&nbsp;</div>") < 0) {
    throw new Error("Disabled checkbox mismatch is not blank.");
}
if (enabledMatch.indexOf('class="readonly boolean-status yes"') < 0 ||
        enabledMatch.indexOf(">&#10004;</div>") < 0) {
    throw new Error("Enabled checkbox match does not show a green check.");
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
var browseFolders = {"C:\\": true, "D:\\Tools": true, "D:\\Tools\\": true, "E:\\Data": true, "E:\\Data\\": true, "F:\\Existing": true, "F:\\Existing\\": true};
fso = {
    FolderExists: function(path) { return browseFolders[path] === true; },
    GetParentFolderName: function(path) {
        var slash = path.lastIndexOf("\\");
        return slash > 2 ? path.substr(0, slash) : path.substr(0, 3);
    }
};
var configPathElement = {
    type: "text",
    value: "d:\\Tools",
    getAttribute: function(name) {
        if (name === "data-scope") { return "persistent"; }
        if (name === "data-field") { return "path"; }
        if (name === "data-index") { return "0"; }
        if (name === "data-pathcheck") { return "1"; }
        return "";
    }
};
state.mode = "Config";
state.persistent = [{path: "", env_var: "", run_as_admin: 0, run_on_startup: 0, menu: 0}];
captureElement(configPathElement);
if (configPathElement.value !== "D:\\Tools\\" || state.persistent[0].path !== "D:\\Tools\\") {
    throw new Error("Config-mode capture did not capitalize the drive letter and append a directory backslash.");
}
var realExpandPathVariables = expandPathVariables;
expandPathVariables = function(value) {
    return value === "%ROOT%\\Existing" ? "F:\\Existing" : value;
};
configPathElement.value = "%ROOT%\\Existing";
captureElement(configPathElement);
if (configPathElement.value !== "%ROOT%\\Existing\\" || state.persistent[0].path !== "%ROOT%\\Existing\\") {
    throw new Error("Config-mode directory normalization did not preserve environment-variable syntax.");
}
expandPathVariables = realExpandPathVariables;
state.mode = "Apply";
configPathElement.value = "e:\\Data";
captureElement(configPathElement);
if (configPathElement.value !== "e:\\Data" || state.persistent[0].path !== "e:\\Data") {
    throw new Error("Apply-mode capture unexpectedly normalized an editable path.");
}
state.mode = "Config";
lastBrowseDirectory = "C:\\";
if (sanitizeBrowsedPath("d:\\Tools\\Tool.exe", false) !== "D:\\Tools\\Tool.exe" ||
        sanitizeBrowsedPath("e:\\Data\\", true) !== "E:\\Data\\" ||
        sanitizeBrowsedPath("e:\\Data", true) !== "E:\\Data\\" ||
        sanitizeBrowsedPath("\\\\server\\share\\", true) !== "\\\\server\\share\\") {
    throw new Error("Browsed-path sanitization did not normalize drive letters and folder endings safely.");
}
if (currentBrowseDirectory() !== "C:\\") {
    throw new Error("First browse directory is not C:\\.");
}
lastBrowseDirectory = "E:\\Data";
if (currentBrowseDirectory("D:\\Tools") !== "D:\\Tools" ||
        currentBrowseDirectory("D:\\Tools\\Tool.exe") !== "D:\\Tools") {
    throw new Error("A populated field did not take priority as the initial browse location.");
}
if (currentBrowseDirectory("") !== "E:\\Data") {
    throw new Error("An empty field did not fall back to the last used browse directory.");
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
lastBrowseDirectory = "E:\\Data";
browseFile(function(path) { pickedPath = path; }, ".exe", "D:\\Tools\\Old.exe");
if (pickedPath !== "D:\\Tools\\Tool.exe" || lastBrowseDirectory !== "D:\\Tools" ||
        pickerScript.indexOf("System.Windows.Forms.OpenFileDialog") < 0 ||
        pickerScript.indexOf("$dialog.InitialDirectory='D:\\Tools';") < 0 ||
        pickerScript.indexOf("Executable files (*.exe)") < 0) {
    throw new Error("File picker did not prefer the field directory and remember the selected file directory.");
}
runPickerScript = function(script) {
    pickerScript = script;
    return "";
};
pickedPath = "";
browseFolder(function(path) { pickedPath = path; }, "Preferred folder", "E:\\Data");
if (pickedPath !== "" || pickerScript.indexOf("'E:\\Data'") < 0) {
    throw new Error("Folder picker did not prefer its populated field path.");
}
runPickerScript = function(script) {
    pickerScript = script;
    return "e:\\Data\\";
};
pickedPath = "";
browseFolder(function(path) { pickedPath = path; }, "Select link folder", "");
if (pickedPath !== "E:\\Data\\" || lastBrowseDirectory !== "E:\\Data\\" ||
        pickerScript.indexOf("PathConfig.NativeFolderDialog") < 0 ||
        pickerScript.indexOf("FromBase64String") < 0 ||
        pickerScript.indexOf("'D:\\Tools'") < 0 ||
        pickerScript.indexOf("'Select link folder'") < 0) {
    throw new Error("Folder picker did not use the native dialog bridge or remembered directory.");
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
var fakeBrowseTabMenu = {style: {display: "block"}};
var fakeBrowseRowMenu = {style: {display: "block"}};
var fakeBrowseMenu = {style: {display: "none"}};
var fakeBrowseFind = {disabled: false};
var fakeBrowseInput = {value: "%ToolRoot%\\Tool.exe"};
var fakeBrowseValueCell = {
    nodeType: 1,
    getElementsByTagName: function(name) { return name === "input" ? [fakeBrowseInput] : []; }
};
var fakeBrowseTextNode = {nodeType: 3, previousSibling: fakeBrowseValueCell};
var fakeBrowseButton = {
    parentNode: {previousSibling: fakeBrowseTextNode},
    getBoundingClientRect: function() { return {left: 20, bottom: 30}; }
};
document = {
    body: {scrollLeft: 5, scrollTop: 7},
    getElementById: function(id) {
        if (id === "contextMenu") { return fakeBrowseTabMenu; }
        if (id === "persistentRowMenu") { return fakeBrowseRowMenu; }
        if (id === "browseContextMenu") { return fakeBrowseMenu; }
        if (id === "browseFindExplorer") { return fakeBrowseFind; }
        return null;
    }
};
window = {event: {clientX: 120, clientY: 75, cancelBubble: false, returnValue: true}};
var browseMenuResult = showBrowseContextMenu(fakeBrowseButton);
if (browseMenuResult !== false || browseMenuPath !== "%ToolRoot%\\Tool.exe" ||
        fakeBrowseMenu.style.display !== "block" || fakeBrowseMenu.style.left !== "125px" ||
        fakeBrowseMenu.style.top !== "82px" || fakeBrowseFind.disabled ||
        fakeBrowseTabMenu.style.display !== "none" || fakeBrowseRowMenu.style.display !== "none" ||
        !window.event.cancelBubble || window.event.returnValue !== false) {
    throw new Error("Browse-button right-click menu did not open from the adjacent field correctly.");
}
var explorerExpandedInput = "";
var explorerCommand = "";
var explorerStyle = -1;
var explorerWait = true;
var explorerAlert = "";
expandPathVariables = function(path) {
    explorerExpandedInput = path;
    return "C:\\Tools\\Tool.exe";
};
fso = {
    FileExists: function(path) { return path === "C:\\Tools\\Tool.exe"; },
    FolderExists: function(path) { return false; }
};
wsh = {
    ExpandEnvironmentStrings: function(value) { return value === "%SystemRoot%" ? "C:\\Windows" : value; },
    Run: function(command, style, wait) {
        explorerCommand = command;
        explorerStyle = style;
        explorerWait = wait;
        return 0;
    }
};
alert = function(message) { explorerAlert = message; };
findBrowsePathInExplorer();
if (explorerExpandedInput !== "%ToolRoot%\\Tool.exe" ||
        explorerCommand !== '"C:\\Windows\\explorer.exe" /select,"C:\\Tools\\Tool.exe"' ||
        explorerStyle !== 1 || explorerWait !== false || explorerAlert ||
        fakeBrowseMenu.style.display !== "none" || browseMenuPath !== "") {
    throw new Error("Find in Explorer did not expand and select the configured path correctly.");
}
fakeBrowseInput.value = "";
window.event = {clientX: 0, clientY: 0, cancelBubble: false, returnValue: true};
showBrowseContextMenu(fakeBrowseButton);
if (!fakeBrowseFind.disabled || browseMenuPath !== "") {
    throw new Error("Find in Explorer was not disabled for an empty adjacent path field.");
}
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
var saveButtonState = {className: "", onclick: "initial"};
document = {
    getElementById: function(id) {
        return id === "saveStateButton" ? saveButtonState : null;
    }
};
hasUnsavedChanges = false;
updateSaveStateButton();
if (saveButtonState.className !== "button save-state-frozen" || saveButtonState.onclick !== null) {
    throw new Error("Clean Save State was not frozen with no click handler.");
}
var trackedValueChanged = true;
captureElement = function(target) { return trackedValueChanged; };
markDirty = function() {
    hasUnsavedChanges = true;
    updateSaveStateButton();
};
window = {
    event: {
        srcElement: {
            getAttribute: function(name) {
                return name === "data-scope" ? "persistent" : "";
            }
        }
    }
};
trackInputChange();
if (!hasUnsavedChanges || saveButtonState.className !== "button" ||
        typeof saveButtonState.onclick !== "function") {
    throw new Error("A live HTA value edit did not immediately unfreeze Save State.");
}
hasUnsavedChanges = false;
updateSaveStateButton();
trackedValueChanged = false;
trackInputChange();
if (hasUnsavedChanges || saveButtonState.className !== "button save-state-frozen" ||
        saveButtonState.onclick !== null) {
    throw new Error("A non-value property event incorrectly unfroze Save State.");
}
var availableSaveCalls = 0;
saveState = function(showMessage) {
    if (showMessage !== true) {
        throw new Error("Available Save State did not request its confirmation message.");
    }
    availableSaveCalls++;
    return true;
};
hasUnsavedChanges = true;
updateSaveStateButton();
if (saveButtonState.className !== "button" || typeof saveButtonState.onclick !== "function") {
    throw new Error("Dirty Save State did not restore the exact available class and click handler.");
}
saveButtonState.onclick();
if (availableSaveCalls !== 1) {
    throw new Error("Restored available Save State did not execute its direct save action.");
}
hasUnsavedChanges = false;
updateSaveStateButton();
if (saveButtonState.className !== "button save-state-frozen" || saveButtonState.onclick !== null) {
    throw new Error("Save State did not return to a frozen no-click state.");
}
var modeSaveCalls = 0;
var modeRendered = 0;
var modeStatus = "";
captureState = function() {};
render = function() { modeRendered++; };
setStatus = function(message) { modeStatus = message; };
state.mode = "Config";
hasUnsavedChanges = true;
saveState = function(showMessage, stateAlreadyCaptured) {
    if (showMessage !== false || stateAlreadyCaptured !== true) {
        throw new Error("Config-to-Apply auto-save used incorrect save options.");
    }
    modeSaveCalls++;
    hasUnsavedChanges = false;
    return true;
};
toggleMode();
if (state.mode !== "Apply" || modeSaveCalls !== 1 || modeRendered !== 1 || hasUnsavedChanges) {
    throw new Error("Config-to-Apply did not save pending state before entering Apply mode.");
}
state.mode = "Config";
hasUnsavedChanges = false;
modeSaveCalls = 0;
modeRendered = 0;
toggleMode();
if (state.mode !== "Apply" || modeSaveCalls !== 0 || modeRendered !== 1) {
    throw new Error("Clean Config-to-Apply transition performed an unnecessary save or failed to render.");
}
state.mode = "Config";
hasUnsavedChanges = true;
modeSaveCalls = 0;
modeRendered = 0;
modeStatus = "";
saveState = function() { modeSaveCalls++; return false; };
toggleMode();
if (state.mode !== "Config" || modeSaveCalls !== 1 || modeRendered !== 0 ||
        modeStatus.indexOf("could not be saved") < 0) {
    throw new Error("Failed Config-to-Apply auto-save did not keep Config mode active.");
}
var tabPreserveWindowSize = null;
var tabRenderCalls = 0;
captureState = function() {};
render = function(preserveWindowSize) {
    tabPreserveWindowSize = preserveWindowSize;
    tabRenderCalls++;
};
state.tabs = ["PROGRAMS", "TOOLS"];
state.activeUiTab = 0;
state.activeProgramTab = 0;
selectTab(2);
if (state.activeUiTab !== 2 || state.activeProgramTab !== 1 ||
        tabRenderCalls !== 1 || tabPreserveWindowSize !== true) {
    throw new Error("Tab selection did not render while preserving the current window size.");
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

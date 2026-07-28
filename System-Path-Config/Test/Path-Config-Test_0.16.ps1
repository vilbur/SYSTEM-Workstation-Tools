$ErrorActionPreference = "Stop"

$ExpectedVersion = "0.16"
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
Assert-Contains $Source 'var VERSION = "0\.16";' "HTA internal version is not 0.16."
Assert-Contains $Source 'document\.title = "Path-Config v" \+ VERSION' "GUI title does not use the internal version."
Assert-Contains $Source 'HTA edition &middot; v' "Visible HTA version label is missing."
Assert-NotContains $Source 'Admin property matches' "Apply mode still uses the old administrator-property header."
if ([regex]::Matches($Source, '<th>Run as admin</th>').Count -lt 2) {
    $Failures.Add("Run as admin header is not used in both path tables.")
}
Assert-Contains $Source '\(expected \? "Yes" : "No"\)' "Administrator status does not display the configured checkbox state."

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

Assert-Contains $Source 'function loadState\(\)' "INI load function is missing."
Assert-Contains $Source 'i \+ "_RunAsAdmin"' "Run-as-admin persistence field is missing."
Assert-Contains $Source 'i \+ "_RunOnStartup"' "Run-on-startup persistence field is missing."
Assert-Contains $Source 'legacyKey = String\(i\)' "Legacy persistent-path migration is missing."
Assert-Contains $Source 'tabButton\(0, "Paths"\)' "Fixed Paths tab is not first."
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
foreach ($Match in [regex]::Matches($Source, 'onclick="([A-Za-z_$][A-Za-z0-9_$]*)\s*\(')) {
    if (-not $FunctionNames.Contains($Match.Groups[1].Value)) {
        $Failures.Add("Undefined onclick handler: $($Match.Groups[1].Value)")
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
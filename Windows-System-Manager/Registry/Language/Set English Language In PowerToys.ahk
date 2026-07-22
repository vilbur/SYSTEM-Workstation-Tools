#NoEnv
#SingleInstance Force
SetBatchLines, -1
SendMode, Input
SetWorkingDir, %A_ScriptDir%
DetectHiddenWindows, On

; SetEnglishWindowsPowerToys.ahk
; Version: 0.01
;
; Sets the current user's Windows display-language override to English (en-US).
; Sets the PowerToys interface language to English.
; Does not modify keyboard layouts or the default keyboard.

global SCRIPT_VERSION := "0.01"
global TEST_MODE := false
global ENGLISH_LANGUAGE_TAG := "en-US"

if (TEST_MODE)
{
    runSelfTest()
    ExitApp
}

applyEnglishLanguage()
ExitApp


;------------------------------------------------------------------------------
; Applies English to Windows display language and the PowerToys interface.
;------------------------------------------------------------------------------
applyEnglishLanguage()
{
    powershell_path := getPowerShellPath()

    if (!FileExist(powershell_path))
    {
        MsgBox, 16, English language, Windows PowerShell was not found.`n`n%powershell_path%
        return false
    }

    power_toys_path := getPowerToysExecutablePath()
    power_toys_was_running := isProcessRunning("PowerToys.exe")

    windows_result := setWindowsDisplayLanguage(powershell_path)
    power_toys_result := setPowerToysLanguage(power_toys_path, power_toys_was_running)
    verification_result := verifyWindowsDisplayLanguage(powershell_path)

    result_message := "Configuration finished.`n`n"
    result_message .= "Windows display language: "
        . (verification_result.success ? "English" : "FAILED") . "`n"
    result_message .= "PowerToys language: "
        . (power_toys_result.success ? "English" : "FAILED") . "`n"

    if (!windows_result.success)
    {
        result_message .= "`nWindows error:`n" . windows_result.details . "`n"
    }

    if (!power_toys_result.success)
    {
        result_message .= "`nPowerToys error:`n" . power_toys_result.details . "`n"
    }

    if (!verification_result.success)
    {
        result_message .= "`nVerification error:`n" . verification_result.details . "`n"
    }

    result_message .= "`nSign out of Windows and sign back in to apply the display-language change."
    result_message .= "`nThe English language pack must already be installed."

    if (windows_result.success && power_toys_result.success && verification_result.success)
    {
        MsgBox, 64, English language, %result_message%
        return true
    }

    MsgBox, 48, English language, %result_message%
    return false
}


;------------------------------------------------------------------------------
; Sets only the current user's Windows UI-language override to English.
;------------------------------------------------------------------------------
setWindowsDisplayLanguage(powershell_path)
{
    temp_prefix := A_Temp . "\SetEnglishWindows_" . A_TickCount
    script_path := temp_prefix . ".ps1"
    result_path := temp_prefix . "_result.txt"

    powershell_script =
(
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'

try
{
    Set-WinUILanguageOverride -Language 'en-US'
    'SUCCESS' | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    exit 0
}
catch
{
    $_ | Out-String | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    exit 1
}
)

    FileDelete, %script_path%
    FileDelete, %result_path%
    FileAppend, %powershell_script%, %script_path%, UTF-8-RAW

    if (ErrorLevel)
    {
        return {success: false, details: "Could not create the temporary PowerShell script."}
    }

    command_line := quoteText(powershell_path)
        . " -NoProfile -NonInteractive -ExecutionPolicy Bypass"
        . " -File " . quoteText(script_path)
        . " -OutputFile " . quoteText(result_path)

    RunWait, %command_line%,, Hide UseErrorLevel
    exit_code := ErrorLevel
    result_text := readTextFile(result_path)

    FileDelete, %script_path%
    FileDelete, %result_path%

    if (exit_code != 0)
    {
        if (result_text = "")
        {
            result_text := "PowerShell exited with code " . exit_code . "."
        }

        return {success: false, details: result_text}
    }

    return {success: true, details: result_text}
}


;------------------------------------------------------------------------------
; Sets PowerToys LanguageTag to English and restarts it when it was running.
;------------------------------------------------------------------------------
setPowerToysLanguage(power_toys_path, power_toys_was_running)
{
    power_toys_directory := A_LocalAppData . "\Microsoft\PowerToys"
    language_file_path := power_toys_directory . "\language.json"
    language_json := "{""LanguageTag"":""en-US""}"

    closePowerToysProcesses()

    if (!FileExist(power_toys_directory))
    {
        FileCreateDir, %power_toys_directory%

        if (ErrorLevel)
        {
            restartPowerToys(power_toys_path, power_toys_was_running)
            return {success: false, details: "Could not create:`n" . power_toys_directory}
        }
    }

    FileDelete, %language_file_path%
    FileAppend, %language_json%, %language_file_path%, UTF-8-RAW

    if (ErrorLevel)
    {
        restartPowerToys(power_toys_path, power_toys_was_running)
        return {success: false, details: "Could not write:`n" . language_file_path}
    }

    written_json := readTextFile(language_file_path)
    language_written := InStr(written_json, """LanguageTag"":""en-US""") > 0
    restart_result := restartPowerToys(power_toys_path, power_toys_was_running)

    if (!language_written)
    {
        return {success: false, details: "PowerToys language.json verification failed."}
    }

    if (!restart_result.success)
    {
        return {success: true, details: "PowerToys is set to English. Start it manually."}
    }

    return {success: true, details: "PowerToys language: English"}
}


;------------------------------------------------------------------------------
; Verifies that the Windows UI-language override is English.
;------------------------------------------------------------------------------
verifyWindowsDisplayLanguage(powershell_path)
{
    temp_prefix := A_Temp . "\VerifyEnglishWindows_" . A_TickCount
    script_path := temp_prefix . ".ps1"
    result_path := temp_prefix . "_result.txt"

    powershell_script =
(
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'

try
{
    $uiOverride = Get-WinUILanguageOverride

    if ($null -eq $uiOverride)
    {
        $value = ''
    }
    elseif ($uiOverride.PSObject.Properties.Name -contains 'Name')
    {
        $value = [string]$uiOverride.Name
    }
    else
    {
        $value = [string]$uiOverride
    }

    $value | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    exit 0
}
catch
{
    $_ | Out-String | Set-Content -LiteralPath $OutputFile -Encoding UTF8
    exit 1
}
)

    FileDelete, %script_path%
    FileDelete, %result_path%
    FileAppend, %powershell_script%, %script_path%, UTF-8-RAW

    command_line := quoteText(powershell_path)
        . " -NoProfile -NonInteractive -ExecutionPolicy Bypass"
        . " -File " . quoteText(script_path)
        . " -OutputFile " . quoteText(result_path)

    RunWait, %command_line%,, Hide UseErrorLevel
    exit_code := ErrorLevel
    result_text := Trim(readTextFile(result_path), " `t`r`n")

    FileDelete, %script_path%
    FileDelete, %result_path%

    if (exit_code != 0)
    {
        return {success: false, details: result_text}
    }

    if (result_text != "en-US")
    {
        return {success: false, details: "Expected en-US, received: " . result_text}
    }

    return {success: true, details: result_text}
}


;------------------------------------------------------------------------------
; Closes the PowerToys settings process and the main PowerToys process.
;------------------------------------------------------------------------------
closePowerToysProcesses()
{
    command_line := ComSpec . " /D /C "
        . "taskkill /IM PowerToys.Settings.exe /F >nul 2>&1"
        . " & taskkill /IM PowerToys.exe /F >nul 2>&1"

    RunWait, %command_line%,, Hide
    Sleep, 500
}


;------------------------------------------------------------------------------
; Restarts PowerToys only when it was running before the language change.
;------------------------------------------------------------------------------
restartPowerToys(power_toys_path, power_toys_was_running)
{
    if (!power_toys_was_running)
    {
        return {success: true, details: "PowerToys was not running."}
    }

    if (power_toys_path = "" || !FileExist(power_toys_path))
    {
        return {success: false, details: "PowerToys executable was not found."}
    }

    Run, % quoteText(power_toys_path),, Hide UseErrorLevel

    if (ErrorLevel)
    {
        return {success: false, details: "PowerToys could not be restarted."}
    }

    return {success: true, details: "PowerToys restarted."}
}


;------------------------------------------------------------------------------
; Locates the running or installed PowerToys executable.
;------------------------------------------------------------------------------
getPowerToysExecutablePath()
{
    WinGet, running_path, ProcessPath, ahk_exe PowerToys.exe

    if (running_path != "" && FileExist(running_path))
    {
        return running_path
    }

    candidate_paths := []

    EnvGet, program_files_64, ProgramW6432
    EnvGet, program_files_x86, ProgramFiles(x86)

    if (program_files_64 != "")
    {
        candidate_paths.Push(program_files_64 . "\PowerToys\PowerToys.exe")
    }

    if (A_ProgramFiles != "")
    {
        candidate_paths.Push(A_ProgramFiles . "\PowerToys\PowerToys.exe")
    }

    if (program_files_x86 != "")
    {
        candidate_paths.Push(program_files_x86 . "\PowerToys\PowerToys.exe")
    }

    candidate_paths.Push(A_LocalAppData . "\PowerToys\PowerToys.exe")

    for candidate_index, candidate_path in candidate_paths
    {
        if (FileExist(candidate_path))
        {
            return candidate_path
        }
    }

    return ""
}


;------------------------------------------------------------------------------
; Returns the built-in Windows PowerShell executable path.
;------------------------------------------------------------------------------
getPowerShellPath()
{
    return A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
}


;------------------------------------------------------------------------------
; Returns true when the supplied process is running.
;------------------------------------------------------------------------------
isProcessRunning(process_name)
{
    Process, Exist, %process_name%
    return ErrorLevel != 0
}


;------------------------------------------------------------------------------
; Reads a complete text file or returns an empty string.
;------------------------------------------------------------------------------
readTextFile(file_path)
{
    if (!FileExist(file_path))
    {
        return ""
    }

    FileRead, file_text, %file_path%

    if (ErrorLevel)
    {
        return ""
    }

    return file_text
}


;------------------------------------------------------------------------------
; Quotes command-line text and escapes embedded quote marks.
;------------------------------------------------------------------------------
quoteText(text_value)
{
    escaped_text := StrReplace(text_value, """", """""")
    return """" . escaped_text . """"
}


;------------------------------------------------------------------------------
; Tests required paths without changing any language settings.
;------------------------------------------------------------------------------
runSelfTest()
{
    powershell_path := getPowerShellPath()
    power_toys_path := getPowerToysExecutablePath()
    report_text := "SetEnglishWindowsPowerToys " . SCRIPT_VERSION . " self-test`n`n"
    test_passed := true

    if (FileExist(powershell_path))
    {
        report_text .= "PASS: Windows PowerShell found.`n"
    }
    else
    {
        report_text .= "FAIL: Windows PowerShell not found.`n"
        test_passed := false
    }

    if (A_LocalAppData != "")
    {
        report_text .= "PASS: LOCALAPPDATA is available.`n"
    }
    else
    {
        report_text .= "FAIL: LOCALAPPDATA is unavailable.`n"
        test_passed := false
    }

    if (power_toys_path != "")
    {
        report_text .= "PASS: PowerToys executable found.`n"
        report_text .= power_toys_path . "`n"
    }
    else
    {
        report_text .= "NOTICE: PowerToys executable was not found.`n"
    }

    report_text .= "`nNo settings were changed."

    MsgBox, % test_passed ? 64 : 16, English language self-test, %report_text%
    return test_passed
}

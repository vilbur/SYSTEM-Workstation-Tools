#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

rcedit_path := A_ScriptDir . "\rcedit-x64.exe"

if (!FileExist(rcedit_path))
{
    MsgBox, 16, Missing rcedit-x64.exe, Place rcedit-x64.exe in the same folder as this script.`n`nExpected path:`n%rcedit_path%
    ExitApp
}

FileSelectFile, exe_path, 3,, Select the EXE file, Executable files (*.exe)
if (ErrorLevel || exe_path = "")
{
    ExitApp
}

FileSelectFile, icon_path, 3,, Select the ICO file, Icon files (*.ico)
if (ErrorLevel || icon_path = "")
{
    ExitApp
}

SplitPath, exe_path, exe_name, exe_directory, exe_extension, exe_name_no_extension
SplitPath, icon_path,,, icon_extension

if (exe_extension != "exe")
{
    MsgBox, 16, Invalid file, The selected target is not an EXE file.
    ExitApp
}

if (icon_extension != "ico")
{
    MsgBox, 16, Invalid file, The selected icon is not an ICO file.
    ExitApp
}

Process, Exist, %exe_name%
if (ErrorLevel)
{
    MsgBox, 16, EXE is running, Close %exe_name% before changing its icon.
    ExitApp
}

MsgBox, 35, Change EXE icon, Change the original EXE?`n`nYes = change original and create a backup`nNo = test on a copy`nCancel = exit
IfMsgBox, Cancel
{
    ExitApp
}

IfMsgBox, No
{
    output_path := exe_directory . "\" . exe_name_no_extension . "-Icon-Test.exe"

    if (FileExist(output_path))
    {
        MsgBox, 16, Test file exists, Delete or rename this file first:`n`n%output_path%
        ExitApp
    }

    FileCopy, %exe_path%, %output_path%, 0
    if (ErrorLevel)
    {
        MsgBox, 16, Copy failed, The test copy could not be created.
        ExitApp
    }
}
else
{
    FormatTime, backup_stamp,, yyyyMMdd-HHmmss
    backup_path := exe_directory . "\" . exe_name_no_extension . "-Before-Icon-Change-" . backup_stamp . ".exe"

    FileCopy, %exe_path%, %backup_path%, 0
    if (ErrorLevel)
    {
        MsgBox, 16, Backup failed, The EXE was not changed because its backup could not be created.
        ExitApp
    }

    output_path := exe_path
}

quote_char := Chr(34)
command_line := quote_char . rcedit_path . quote_char . " " . quote_char . output_path . quote_char . " --set-icon " . quote_char . icon_path . quote_char
RunWait, %command_line%, %A_ScriptDir%, Hide UseErrorLevel

if (ErrorLevel = "ERROR")
{
    MsgBox, 16, Could not start rcedit, The rcedit command could not be started.
    ExitApp
}

if (ErrorLevel != 0)
{
    MsgBox, 16, Icon change failed, rcedit returned exit code %ErrorLevel%.`n`nThe selected EXE may be protected or digitally signed.
    ExitApp
}

MsgBox, 64, Icon changed, The icon was changed successfully:`n`n%output_path%`n`nIf Windows shows the old icon, restart File Explorer or clear its icon cache.
ExitApp

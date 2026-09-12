#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

; ==============================================================================
; Everything Assistance - Compiler
; Builds the root executable from the launcher source in dev\lib.
; ==============================================================================

SplitPath, A_ScriptDir,, project_root
launcher_path := A_ScriptDir . "\lib\Everything-Assistance.ahk"
methods_path := A_ScriptDir . "\lib\Everything-Assistance-methods.ahk"
icon_path := A_ScriptDir . "\Everything-Assistance.ico"
output_path := project_root . "\Everything-Assistance.exe"
build_path := A_ScriptDir . "\Everything-Assistance.build.exe"

if !FileExist(launcher_path)
{
    MsgBox, 16, Everything Assistance Compiler, The launcher source was not found:`n%launcher_path%
    ExitApp
}

if !FileExist(methods_path)
{
    MsgBox, 16, Everything Assistance Compiler, The methods script was not found:`n%methods_path%
    ExitApp
}

if !FileExist(icon_path)
{
    MsgBox, 16, Everything Assistance Compiler, The launcher icon was not found:`n%icon_path%
    ExitApp
}

compiler_path := findAhk2Exe()
if (compiler_path = "")
{
    MsgBox, 16, Everything Assistance Compiler, Ahk2Exe.exe was not found. Install the AutoHotkey v1 compiler component or select Ahk2Exe.exe when prompted.
    ExitApp
}

if hasArgument("-test")
{
    MsgBox, 64, Everything Assistance Compiler - Test Passed, Launcher source:`n%launcher_path%`n`nMethods script:`n%methods_path%`n`nIcon:`n%icon_path%`n`nCompiler:`n%compiler_path%`n`nOutput:`n%output_path%
    ExitApp
}

if FileExist(build_path)
{
    FileDelete, %build_path%
    if ErrorLevel
    {
        MsgBox, 16, Everything Assistance Compiler, The old temporary build could not be removed:`n%build_path%
        ExitApp
    }
}

compile_command := quote(compiler_path)
    . " /in " . quote(launcher_path)
    . " /out " . quote(build_path)
    . " /icon " . quote(icon_path)

RunWait, %compile_command%, %A_ScriptDir%, UseErrorLevel Hide
compile_exit_code := ErrorLevel

if (compile_exit_code != 0 || !FileExist(build_path))
{
    MsgBox, 16, Everything Assistance Compiler, Compilation failed.`n`nExit code: %compile_exit_code%`nLauncher: %launcher_path%
    ExitApp
}

FileMove, %build_path%, %output_path%, 1
if ErrorLevel
{
    MsgBox, 16, Everything Assistance Compiler, Compilation succeeded, but the final executable could not be replaced.`n`nTemporary build:`n%build_path%`n`nClose Everything-Assistance.exe and try again.
    ExitApp
}

MsgBox, 64, Everything Assistance Compiler, Everything-Assistance.exe was compiled successfully.`n`nLauncher source:`n%launcher_path%`n`nMethods script:`n%methods_path%`n`nIcon:`n%icon_path%`n`nOutput:`n%output_path%
ExitApp

/**
Locate the AutoHotkey v1 Ahk2Exe compiler or let the user select it.
*/
findAhk2Exe()
{
    candidate_paths := []
    SplitPath, A_AhkPath,, ahk_directory
    candidate_paths.Push(ahk_directory . "\Compiler\Ahk2Exe.exe")
    candidate_paths.Push(A_ProgramFiles . "\AutoHotkey\Compiler\Ahk2Exe.exe")

    EnvGet, program_files_x86, ProgramFiles(x86)
    if (program_files_x86 != "")
    {
        candidate_paths.Push(program_files_x86 . "\AutoHotkey\Compiler\Ahk2Exe.exe")
    }

    for _, candidate_path in candidate_paths
    {
        if FileExist(candidate_path)
        {
            return candidate_path
        }
    }

    FileSelectFile, selected_path, 3,, Select Ahk2Exe.exe, Programs (*.exe)
    if (selected_path != "" && FileExist(selected_path))
    {
        SplitPath, selected_path, selected_name
        if (selected_name = "Ahk2Exe.exe")
        {
            return selected_path
        }
    }

    return ""
}

/**
Return true when the requested command-line argument is present.
*/
hasArgument(expected_argument)
{
    for _, supplied_argument in A_Args
    {
        if (supplied_argument = expected_argument)
        {
            return true
        }
    }

    return false
}

/**
Quote a command-line path.
*/
quote(value)
{
    return Chr(34) . value . Chr(34)
}

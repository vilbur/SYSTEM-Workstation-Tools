#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

; ==============================================================================
; Everything Assistance - Compiler
; Builds the stable launcher EXE from the newest numbered source files.
; ==============================================================================

launcher_path := findNewestScript("Everything-Assistance-Launcher", "Everything-Assistance-Launcher.ahk")
assistant_path := findNewestScript("Everything-Assistance", "Everything-Assistance.ahk")
icon_path := A_ScriptDir . "\Everything-Assistance.ico"
compiler_path := findAhk2Exe()
output_path := A_ScriptDir . "\Everything-Assistance-Launcher.exe"
build_path := A_ScriptDir . "\Everything-Assistance-Launcher.build.exe"

if (launcher_path = "")
{
    MsgBox, 16, Everything Assistance Compiler, No launcher source was found in:`n%A_ScriptDir%
    ExitApp
}

if (assistant_path = "")
{
    MsgBox, 16, Everything Assistance Compiler, No assistant source was found in:`n%A_ScriptDir%
    ExitApp
}

if !FileExist(icon_path)
{
    MsgBox, 16, Everything Assistance Compiler, The launcher icon was not found:`n%icon_path%
    ExitApp
}

if (compiler_path = "")
{
    MsgBox, 16, Everything Assistance Compiler, Ahk2Exe.exe was not found. Install the AutoHotkey v1 compiler component or select Ahk2Exe.exe when prompted.
    ExitApp
}

if hasArgument("-test")
{
    MsgBox, 64, Everything Assistance Compiler - Test Passed, Launcher:`n%launcher_path%`n`nAssistant:`n%assistant_path%`n`nIcon:`n%icon_path%`n`nCompiler:`n%compiler_path%`n`nOutput:`n%output_path%
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
    MsgBox, 16, Everything Assistance Compiler, Compilation succeeded, but the final launcher could not be replaced.`n`nTemporary build:`n%build_path%`n`nClose any running launcher and try again.
    ExitApp
}

MsgBox, 64, Everything Assistance Compiler, Everything-Assistance-Launcher.exe was compiled successfully.`n`nLauncher source:`n%launcher_path%`n`nAssistant verified:`n%assistant_path%`n`nIcon:`n%icon_path%`n`nOutput:`n%output_path%
ExitApp

/**
Return the newest numbered source, with an unversioned fallback.
*/
findNewestScript(file_prefix, fallback_name)
{
    newest_path := ""
    newest_major := -1
    newest_minor := -1
    newest_patch := -1
    file_pattern := A_ScriptDir . "\" . file_prefix . "_*.ahk"

    Loop, Files, %file_pattern%, F
    {
        version_pattern := "i)^" . file_prefix . "_([0-9]+)\.([0-9]+)(?:\.([0-9]+))?\.ahk$"
        if !RegExMatch(A_LoopFileName, version_pattern, version_match)
        {
            continue
        }

        version_major := version_match1 + 0
        version_minor := version_match2 + 0
        version_patch := version_match3 + 0

        if isNewerVersion(version_major, version_minor, version_patch
            , newest_major, newest_minor, newest_patch)
        {
            newest_major := version_major
            newest_minor := version_minor
            newest_patch := version_patch
            newest_path := A_LoopFileFullPath
        }
    }

    if (newest_path != "")
    {
        return newest_path
    }

    fallback_path := A_ScriptDir . "\" . fallback_name
    return FileExist(fallback_path) ? fallback_path : ""
}

/**
Compare three numeric version components without decimal-number ambiguity.
*/
isNewerVersion(candidate_major, candidate_minor, candidate_patch
    , current_major, current_minor, current_patch)
{
    if (candidate_major != current_major)
    {
        return candidate_major > current_major
    }

    if (candidate_minor != current_minor)
    {
        return candidate_minor > current_minor
    }

    return candidate_patch > current_patch
}

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

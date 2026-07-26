/* -------------------------
    Registry Configurator v0.01
    Standalone registry configuration tool
-------------------------
*/

#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global g_ini_file := A_ScriptDir "\\Registry-Config.ini"
global g_legacy_ini_file := A_ScriptDir "\\System-Config.ini"
global g_reg_dir := A_ScriptDir "\\Registry"
global g_current_mode := "Config"
global g_win_sections := {}
global g_win_section_names := []
global dark_background := "1E1E1E"
global font_color := "D6D6D6"
global mode_color := "FF9900"
global g_dark_brush := DllCall("CreateSolidBrush", "UInt", 0x1E1E1E, "Ptr")

OnMessage(0x0133, "onDarkControlColor")
OnMessage(0x0138, "onDarkControlColor")

if FileExist("Registry-Config.ico")
    Menu, Tray, Icon, Registry-Config.ico
else if FileExist("System-Config.ico")
    Menu, Tray, Icon, System-Config.ico

if !InStr(FileExist(g_reg_dir), "D")
    FileCreateDir, %g_reg_dir%

scanRegistryDirectory()
loadRegistryState()
mode_color := (g_current_mode == "Config") ? "FF9900" : "5599FF"

Gui, +hwndh_main_gui +LastFound
Gui, Color, %dark_background%, %dark_background%
Gui, Margin, 14, 14
Gui, Font, s12 c%font_color%, Segoe UI
setDarkTitleBar(h_main_gui)

Gui, Add, GroupBox, x20 y10 w760 h80 c%mode_color%, Execution Mode
Gui, Font, s12 Bold
Gui, Add, Button, vmode_btn gtoggleMode x40 y35 w250 h40 hwndh_mode -Theme +Border, MODE: %g_current_mode%
setDarkControl(h_mode)

if (g_current_mode == "Config")
{
    Gui, Add, Button, gonManualSave x300 y35 w250 h40 hwndh_save -Theme +Border, SAVE STATE
    setDarkControl(h_save)
}
else
{
    Gui, Add, Button, gonApplyRegistry x300 y35 w250 h40 hwndh_apply -Theme +Border, APPLY CHANGES
    setDarkControl(h_apply)
}
Gui, Font, s12 Norm c%font_color%

y_pos := 120
For _, sec_name in g_win_section_names
{
    Gui, Font, s15 Bold c%mode_color%
    Gui, Add, Text, x40 y%y_pos% BackgroundTrans, %sec_name%
    Gui, Font, s12 Norm c%font_color%
    y_pos += 35

    opts := g_win_sections[sec_name]
    For _, opt in opts
    {
        var_id := opt.id
        chk_state := opt.state
        Gui, Add, CheckBox, v%var_id% Checked%chk_state% x60 y%y_pos% BackgroundTrans, % opt.name
        y_pos += 32
    }
    y_pos += 15
}

window_height := y_pos + 75
if (window_height < 300)
    window_height := 300
if (window_height > 950)
    window_height := 950

Gui, Show, w800 h%window_height%, Registry-Config v0.01
return

toggleMode:
    Gui, Submit, NoHide
    saveRegistryState()
    g_current_mode := (g_current_mode == "Config") ? "Apply" : "Config"
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode
    Reload
return

onManualSave:
    saveRegistryState()
    MsgBox, 64, Saved, Registry selections were saved to Registry-Config.ini.
return

onApplyRegistry:
    Gui, Submit, NoHide
    updates_made := applyRegistryChanges()
    saveRegistryState()
    MsgBox, 64, Registry Updates, Applied %updates_made% changed registry configurations.
return

GuiClose:
    saveRegistryState()
ExitApp

/*
Description: Scan Registry subfolders and build dynamic option data.
*/
scanRegistryDirectory()
{
    global g_reg_dir, g_win_sections, g_win_section_names

    chk_index := 1
    Loop, Files, %g_reg_dir%\*, D
    {
        section_folder := A_LoopFileName
        section_name := StrReplace(section_folder, "-", " ")
        section_name := StrReplace(section_name, "_", " ")
        StringUpper, section_name, section_name, T
        g_win_section_names.Push(section_name)
        g_win_sections[section_name] := []

        Loop, Files, %g_reg_dir%\%section_folder%\*, D
        {
            option_folder := A_LoopFileName
            option_name := StrReplace(option_folder, "-", " ")
            option_name := StrReplace(option_name, "_", " ")
            StringUpper, option_name, option_name, T
            variable_name := "chk_win_" chk_index
            g_win_sections[section_name].Push({"id": variable_name, "path": section_folder "\\" option_folder, "name": option_name, "state": 0, "initial_state": 0})
            chk_index++
        }
    }
}

/*
Description: Load registry checkbox state and import legacy state once.
*/
loadRegistryState()
{
    global g_ini_file, g_legacy_ini_file, g_current_mode, g_win_sections, g_win_section_names

    source_ini := FileExist(g_ini_file) ? g_ini_file : g_legacy_ini_file
    if !FileExist(source_ini)
        return

    IniRead, g_current_mode, %source_ini%, Settings, Mode, Config

    For _, section_name in g_win_section_names
    {
        opts := g_win_sections[section_name]
        For option_index, option_data in opts
        {
            IniRead, option_value, %source_ini%, Windows, % option_data.id, 0
            g_win_sections[section_name][option_index].state := option_value
            g_win_sections[section_name][option_index].initial_state := option_value
        }
    }

    if (source_ini != g_ini_file)
        saveRegistryState(false)
}

/*
Description: Save all dynamic registry checkbox states.
*/
saveRegistryState(submit_gui := true)
{
    global g_ini_file, g_current_mode, g_win_sections, g_win_section_names

    if (submit_gui)
        Gui, Submit, NoHide
    FileDelete, %g_ini_file%
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode

    For _, section_name in g_win_section_names
    {
        opts := g_win_sections[section_name]
        For option_index, option_data in opts
        {
            variable_name := option_data.id
            option_value := %variable_name%
            IniWrite, %option_value%, %g_ini_file%, Windows, %variable_name%
        }
    }
}

/*
Description: Execute changed Enabled or Disabled registry actions.
*/
applyRegistryChanges()
{
    global g_reg_dir, g_win_sections, g_win_section_names

    updates_made := 0
    extensions := ["reg", "ahk", "exe"]

    For _, section_name in g_win_section_names
    {
        opts := g_win_sections[section_name]
        For option_index, option_data in opts
        {
            variable_name := option_data.id
            current_state := %variable_name%
            initial_state := option_data.initial_state

            if (current_state != initial_state)
            {
                target_state := current_state ? "Enabled" : "Disabled"
                target_dir := g_reg_dir "\\" option_data.path "\\"

                For _, extension_name in extensions
                {
                    target_file := target_dir target_state "." extension_name
                    if FileExist(target_file)
                    {
                        if (extension_name == "reg")
                            RunWait, regedit.exe /s "%target_file%"
                        else
                            RunWait, "%target_file%"

                        updates_made++
                        break
                    }
                }
                g_win_sections[section_name][option_index].initial_state := current_state
            }
        }
    }

    return updates_made
}

/*
Description: Apply native dark theme to a control.
*/
setDarkControl(hwnd)
{
    DllCall("uxtheme\\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

/*
Description: Enable the dark Windows title bar where supported.
*/
setDarkTitleBar(window_hwnd)
{
    use_dark_mode := 1
    DllCall("dwmapi\\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 20, "Int*", use_dark_mode, "Int", 4)
    DllCall("dwmapi\\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 19, "Int*", use_dark_mode, "Int", 4)
}

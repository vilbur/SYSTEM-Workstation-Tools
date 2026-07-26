/* -------------------------
    System Configurator v0.69
    Tray Icon & Link Types
-------------------------
*/ 

#NoEnv
#SingleInstance Force
#Persistent
global log_file := A_ScriptDir . "\\Apply-Log.md"

writeLog(msg, color="") {
    global log_file
    if (color == "red")
        FileAppend, <span style="color:red">%msg%</span>`n`n, %log_file%
    else
        FileAppend, %msg%`n`n, %log_file%
}

resetLog() {
    global log_file
    FileDelete, %log_file%
    FileAppend, # Apply Execution Log - %A_Now%`n`n, %log_file%
}

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

if FileExist("System-Config.ico")
    Menu, Tray, Icon, System-Config.ico

global g_ini_file        := A_ScriptDir "\System-Config.ini"
global g_reg_dir         := A_ScriptDir "\Registry"
global g_tab_names       := []
global g_tab_data        := {}
global g_current_tab     := 1
global g_current_mode    := "Config"
global g_tab_menu        := "TabMenu"

global dark_background := "1E1E1E"
global border_color := "2D2D2D"
global font_color := "D6D6D6"

; State tracking for bug-free path redraws
global g_path_states := {}

; Dynamic Registry Options Array
global g_win_sections := {}
global g_win_section_names := []

; Right Click event for Tab Menu
OnMessage(0x204, "WM_RBUTTONDOWN") 

; Ensure Registry directory exists
if !InStr(FileExist(g_reg_dir), "D")
    FileCreateDir, %g_reg_dir%

; ==========================================
;         INIT & DATA LOADING
; ==========================================
scanRegistryDirectory()
loadState()

Menu, %g_tab_menu%, Add, Add New Program Tab, onAddProgram
Menu, %g_tab_menu%, Add, Rename Current Tab, onRenameTab
Menu, %g_tab_menu%, Add, Delete Current Tab, onDeleteTab

global mode_color := (g_current_mode == "Config") ? "FF9900" : "5599FF"

; ==========================================
;         GUI CONSTRUCTION
; ==========================================
Gui, +hwndh_main_gui +LastFound
Gui, Color, %dark_background%, %dark_background%
Gui, Margin, 14, 14
Gui, Font, s12 c%font_color%, Segoe UI

DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", h_main_gui, "Int", 20, "Int*", true, "Int", 4)

; Mode Selection & Save State at TOP
Gui, Add, GroupBox, x20 y10 w1160 h80 c%mode_color%, Execution Mode
Gui, Font, s12 Bold
Gui, Add, Button, vmode_btn gtoggleMode x40 y35 w250 h40 hwndh_mode -Theme +Border, MODE: %g_current_mode%

if (g_current_mode == "Config") {
    Gui, Add, Button, gonManualSave x300 y35 w250 h40 hwndh_save -Theme +Border, SAVE STATE
    setDarkControl(h_save)
} else {
    Gui, Add, Button, x300 y35 w250 h40 gonApplyConfigs hwndh_apply -Theme +Border, APPLY ALL
    setDarkControl(h_apply)
}
setDarkControl(h_mode)
Gui, Font, s12 Norm

tab_str := ""
For tab_idx, tab_name in g_tab_names
    tab_str .= tab_name "|"

Gui, Add, Tab3, vmain_tab gonTabChanged x20 y110 w1160 h670 hwndh_tab AltSubmit Choose%g_current_tab%, %tab_str%
DllCall("uxtheme\SetWindowTheme", "Ptr", h_tab, "Str", "DarkMode_Explorer", "Ptr", 0)
GuiControl, +cDDDDDD, main_tab

For tab_idx, tab_name in g_tab_names 
{
    Gui, Tab, %tab_idx% 
    if (tab_idx == 1) {
        y_pos := 155
        
        For _, sec_name in g_win_section_names {
            Gui, Font, s15 Bold c%mode_color%
            Gui, Add, Text, x40 y%y_pos%, %sec_name%
            Gui, Font, s12 Norm c%font_color%
            y_pos += 35
            
            opts := g_win_sections[sec_name]
            For _, opt in opts {
                var_id := opt.id
                chk_state := opt.state
                Gui, Add, CheckBox, v%var_id% Checked%chk_state% x60 y%y_pos% BackgroundTrans, % opt.name
                y_pos += 32
            }
            y_pos += 15
        }

        if (g_current_mode == "Apply") {
            Gui, Font, Bold s12 cFFFFFF
            hwnd_var := "h_app_" tab_idx
            Gui, Add, Button, hwnd%hwnd_var% gonApplyCurrentTab x920 y720 w240 h40 -Theme +Border, Apply WINDOWS
            handle := %hwnd_var%
            setDarkControl(handle)
            Gui, Font, Norm s12 c%font_color%
        }

    } else {
        data := g_tab_data[tab_name]
        y_pos := 155
        
        ; SECTION BUILDER LOGIC
        sections := ["Paths", "Envs", "Execs", "Links"]
        For sec_idx, sec_name in sections {
            Gui, Font, Bold s15 c%mode_color%
            if (g_current_mode == "Config") {
                if (sec_name == "Paths")
                    Gui, Add, Text, gonAddPath x40 y%y_pos% BackgroundTrans, + ADD %sec_name%
                else if (sec_name == "Envs")
                    Gui, Add, Text, gonAddEnv x40 y%y_pos% BackgroundTrans, + ADD Env
                else if (sec_name == "Execs")
                    Gui, Add, Text, gonAddExec x40 y%y_pos% BackgroundTrans, + ADD Exec
                else if (sec_name == "Links")
                    Gui, Add, Text, gonAddLink x40 y%y_pos% BackgroundTrans, + ADD Link
            } else {
                Gui, Add, Text, x40 y%y_pos% BackgroundTrans, %sec_idx%. %sec_name%
            }
            Gui, Font, Norm s12 c%font_color%
            y_pos += 38
            
            if (sec_name == "Paths") {
                For i, path_item in data.paths {
                    path_name := path_item.name
                    path_value := path_item.val
                    var_n := "edit_path_name_" tab_idx "_" i
                    var_edit := "edit_path_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_d := "btn_path_d_" tab_idx "_" i
                        var_f := "btn_path_f_" tab_idx "_" i
                        var_del := "btn_del_path_" tab_idx "_" i
                        Gui, Add, Edit, v%var_n% x40 y%y_pos% w180 h28 -E0x200 -Theme +Border, %path_name%
                        Gui, Add, Edit, v%var_edit% x230 y%y_pos% w780 h28 -E0x200 -Theme +Border, %path_value%
                        Gui, Add, Button, v%var_d% gonBrowsePathDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowsePathFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 1) {
                            Gui, Add, Button, v%var_del% gonDeletePath hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Add, Text, v%var_n% x40 y%y_pos% w180 h28 c%font_color%, %path_name%
                        Gui, Add, Text, v%var_edit% x230 y%y_pos% w800 h28 c%font_color%, %path_value%
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Envs") {
                For i, e in data.envs {
                    var_n := "edit_env_name_" tab_idx "_" i
                    var_v := "edit_env_val_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_d := "btn_env_d_" tab_idx "_" i
                        var_f := "btn_env_f_" tab_idx "_" i
                        var_del := "btn_del_env_" tab_idx "_" i
                        Gui, Add, Edit, v%var_n% x40 y%y_pos% w200 h28 -E0x200 -Theme +Border, % e.name
                        Gui, Add, Edit, v%var_v% x250 y%y_pos% w760 h28 -E0x200 -Theme +Border, % e.val
                        Gui, Add, Button, v%var_d% gonBrowseEnvDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowseEnvFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteEnv hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Font, Bold
                        Gui, Add, Text, v%var_n% x40 y%y_pos% w200 h28 c%font_color%, % e.name
                        Gui, Font, Norm
                        Gui, Add, Text, v%var_v% x250 y%y_pos% w780 h28 c%font_color%, % e.val
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Execs") {
                For i, x in data.execs {
                    var_edit := "edit_exec_" tab_idx "_" i
                    if (g_current_mode == "Config") {
                        var_d := "btn_exec_d_" tab_idx "_" i
                        var_f := "btn_exec_f_" tab_idx "_" i
                        var_del := "btn_del_exec_" tab_idx "_" i
                        Gui, Add, Edit, v%var_edit% x40 y%y_pos% w970 h28 -E0x200 -Theme +Border, %x%
                        Gui, Add, Button, v%var_d% gonBrowseExecDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowseExecFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteExec hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Add, Text, v%var_edit% x40 y%y_pos% w990 h28 c%font_color%, %x%
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Links") {
                if (data.links.Length() > 0) {
                    label_y := y_pos + 5
                    Gui, Font, Bold s12 c888888
                    if (g_current_mode == "Config") {
                        Gui, Add, Text, x40 y%label_y%, Source
                        Gui, Add, Text, x400 y%label_y%, Target Folder
                        Gui, Add, Text, x790 y%label_y%, Target Name
                        Gui, Add, Text, x980 y%label_y%, Type
                    } else {
                        Gui, Add, Text, x40 y%label_y%, Source
                        Gui, Add, Text, x420 y%label_y%, Deployed Link Path
                        Gui, Add, Text, x935 y%label_y%, Type
                    }
                    Gui, Font, Norm s12 c%font_color%
                    y_pos += 33
                }
                
                For i, l in data.links {
                    var_e_s := "edit_link_s_" tab_idx "_" i
                    var_e_td := "edit_link_tdir_" tab_idx "_" i
                    var_e_type := "edit_link_type_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_e_tn := "edit_link_tname_" tab_idx "_" i
                        var_d_s := "btn_link_d_s_" tab_idx "_" i
                        var_f_s := "btn_link_f_s_" tab_idx "_" i
                        var_d_t := "btn_link_d_t_" tab_idx "_" i
                        var_del := "btn_del_link_" tab_idx "_" i
                        
                        type_str := "Shortcut|Symlink|Hardlink"
                        
                        Gui, Add, Edit, v%var_e_s% x40 y%y_pos% w280 h28 -E0x200 -Theme +Border, % l.src
                        Gui, Add, Button, v%var_d_s% gonBrowseLinkSD hwndh_d_s x325 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f_s% gonBrowseLinkSF hwndh_f_s x360 y%y_pos% w30 h28 -Theme +Border, F
                        Gui, Add, Edit, v%var_e_td% x400 y%y_pos% w350 h28 -E0x200 -Theme +Border, % l.tgt_dir
                        Gui, Add, Button, v%var_d_t% gonBrowseLinkTD hwndh_d_t x755 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Edit, v%var_e_tn% x790 y%y_pos% w180 h28 -E0x200 -Theme +Border, % l.tgt_name
                        
                        Gui, Add, DropDownList, v%var_e_type% hwndh_type x980 y%y_pos% w100 r3 -Theme +Background%dark_background% c%font_color%, %type_str%
                        if (l.type != "")
                            GuiControl, ChooseString, %var_e_type%, % l.type
                        else
                            GuiControl, Choose, %var_e_type%, 1
                        
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteLink hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d_s), setDarkControl(h_f_s), setDarkControl(h_d_t)
                    } else {
                        if (l.tgt_dir != "")
                            full_tgt := l.tgt_dir . (SubStr(l.tgt_dir, 0) == "\" ? "" : "\") . l.tgt_name
                        else
                            full_tgt := l.tgt_name
                        if (l.type == "Shortcut" && !InStr(full_tgt, ".lnk"))
                            full_tgt .= ".lnk"
                        
                        Gui, Add, Text, v%var_e_s% x40 y%y_pos% w360 h28 c%font_color%, % l.src
                        Gui, Add, Text, v%var_e_td% x420 y%y_pos% w500 h28 c%font_color%, % full_tgt
                        Gui, Add, Text, v%var_e_type% x935 y%y_pos% w100 h28 c%font_color%, % l.type
                    }
                    y_pos += 33
                }
                y_pos += 15
            }
        }
        
        if (g_current_mode == "Apply") {
            Gui, Font, Bold s12 cFFFFFF
            hwnd_var := "h_app_" tab_idx
            Gui, Add, Button, hwnd%hwnd_var% gonApplyCurrentTab x920 y720 w240 h40 -Theme +Border, Apply %tab_name%
            handle := %hwnd_var%
            setDarkControl(handle)
            Gui, Font, Norm s12 c%font_color%
        }
    }
}
Gui, Tab 
Gui, Show, w1200 h800, System-Config v0.69

SetTimer, pathTimer, 500
return

; ==========================================
;         REGISTRY SCANNING
; ==========================================
scanRegistryDirectory() {
    global g_reg_dir, g_win_sections, g_win_section_names
    chk_index := 1
    Loop, Files, %g_reg_dir%\*, D
    {
        sectionFolder := A_LoopFileName
        secName := StrReplace(sectionFolder, "-", " ")
        secName := StrReplace(secName, "_", " ")
        StringUpper, secName, secName, T 
        g_win_section_names.Push(secName)
        g_win_sections[secName] := []
        
        Loop, Files, %g_reg_dir%\%sectionFolder%\*, D
        {
            optFolder := A_LoopFileName
            optName := StrReplace(optFolder, "-", " ")
            optName := StrReplace(optName, "_", " ")
            StringUpper, optName, optName, T 
            varName := "chk_win_" chk_index
            g_win_sections[secName].Push({"id": varName, "path": sectionFolder "\" optFolder, "name": optName, "state": 0, "initial_state": 0})
            chk_index++
        }
    }
}

; ==========================================
;         RIGHT-CLICK & TAB MENU LOGIC
; ==========================================
WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global h_tab, g_tab_menu
    if (hwnd == h_tab) {
        Menu, %g_tab_menu%, Show
    }
}

onTabChanged:
    Gui, Submit, NoHide
    g_current_tab := main_tab
    saveState()
return

toggleMode:
    Gui, Submit, NoHide
    captureCurrentTabRows()
    saveState()
    g_current_mode := (g_current_mode == "Config") ? "Apply" : "Config"
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode
    Reload
return

onAddProgram:
    FileSelectFile, exe_path, 3,, Browse for Main Executable (Sets Tab Name), Executables (*.exe)
    if (exe_path == "")
        return
    captureCurrentTabRows()
    SplitPath, exe_path, out_file_name, out_dir, out_ext, out_name_no_ext
    SplitPath, out_dir, out_folder_name
    tab_name := out_folder_name
    if (tab_name == "")
        tab_name := out_name_no_ext 
    Loop {
        is_dup := false
        For k, v in g_tab_names {
            if (v == tab_name) {
                is_dup := true
                tab_name := tab_name "_2"
                break
            }
        }
        if (!is_dup)
            break
    }
    g_tab_names.Push(tab_name)
    g_tab_data[tab_name] := {"paths": [{"name": out_name_no_ext, "val": exe_path}], "envs": [], "execs": [], "links": []}
    g_current_tab := g_tab_names.Length() 
    saveState()
    Reload
return

onRenameTab:
    if (g_current_tab == 1) {
        MsgBox, 48, Denied, The WINDOWS tab cannot be renamed.
        return
    }
    old_name := g_tab_names[g_current_tab]
    InputBox, new_name, Rename Tab, Enter new name for tab "%old_name%":,, 300, 150
    if (ErrorLevel || new_name == "" || new_name == old_name)
        return
    g_tab_names[g_current_tab] := new_name
    g_tab_data[new_name] := g_tab_data[old_name]
    g_tab_data.Delete(old_name)
    captureCurrentTabRows()
    saveState()
    Reload
return

onDeleteTab:
    if (g_current_tab == 1) {
        MsgBox, 48, Denied, The WINDOWS tab cannot be deleted.
        return
    }
    target_name := g_tab_names[g_current_tab]
    MsgBox, 52, Confirm Delete, Are you sure you want to completely delete "%target_name%"?
    IfMsgBox, No
        return
    g_tab_data.Delete(target_name)
    g_tab_names.RemoveAt(g_current_tab)
    g_current_tab := 1 
    saveState()
    Reload
return


; ==========================================
;         ROW ADD/DELETE/BROWSE EVENTS
; ==========================================
onAddPath:
    captureCurrentTabRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].paths))
        g_tab_data[g_tab_names[g_current_tab]].paths := []
    g_tab_data[g_tab_names[g_current_tab]].paths.Push({"name":"", "val":""})
    saveState()
    Reload
return

onAddEnv:
    captureCurrentTabRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].envs))
        g_tab_data[g_tab_names[g_current_tab]].envs := []
    g_tab_data[g_tab_names[g_current_tab]].envs.Push({"name":"", "val":""})
    saveState()
    Reload
return

onAddExec:
    captureCurrentTabRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].execs))
        g_tab_data[g_tab_names[g_current_tab]].execs := []
    g_tab_data[g_tab_names[g_current_tab]].execs.Push("")
    saveState()
    Reload
return

onAddLink:
    captureCurrentTabRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].links))
        g_tab_data[g_tab_names[g_current_tab]].links := []
    g_tab_data[g_tab_names[g_current_tab]].links.Push({"src":"", "tgt_dir":"", "tgt_name":"", "type":"Shortcut"})
    saveState()
    Reload
return

onDeletePath:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureCurrentTabRows()
    g_tab_data[g_tab_names[tab_idx]].paths.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteEnv:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureCurrentTabRows()
    g_tab_data[g_tab_names[tab_idx]].envs.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteExec:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureCurrentTabRows()
    g_tab_data[g_tab_names[tab_idx]].execs.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteLink:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureCurrentTabRows()
    g_tab_data[g_tab_names[tab_idx]].links.RemoveAt(row_idx)
    saveState()
    Reload
return

; --- BROWSE ---
onBrowsePathDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_path_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseExecDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_exec_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseEnvDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_env_val_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseLinkSD:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_s_" tab_idx "_" row_idx
    var_tname := "edit_link_tname_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Source Folder
    if (selected != "") {
        GuiControl,, %var_edit%, %selected%
        SplitPath, selected, out_name
        GuiControl,, %var_tname%, %out_name%
    }
return

onBrowseLinkTD:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_tdir_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Target Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowsePathFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_path_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseExecFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_exec_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File, Executables (*.exe)
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseEnvFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_env_val_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseLinkSF:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_s_" tab_idx "_" row_idx
    var_tname := "edit_link_tname_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select Source File
    if (selected != "") {
        GuiControl,, %var_edit%, %selected%
        SplitPath, selected, out_name
        GuiControl,, %var_tname%, %out_name%
    }
return

; ==========================================
;         LIVE VERIFICATION
; ==========================================
pathTimer:
    checkPaths()
return

updateControlColor(var, path, is_env_name := false) {
    global g_path_states
    if (is_env_name) {
        state := (path == "") ? -1 : 0
        if (path != "") {
            EnvGet, env_check, %path%
            if (env_check != "")
                state := 1
        }
    } else {
        state := (path == "") ? -1 : (FileExist(path) ? 1 : 0)
    }
    
    if (g_path_states[var] != state) {
        g_path_states[var] := state
        if (state == 1)
            GuiControl, +c55FF55, %var%
        else if (state == 0)
            GuiControl, +cFF4444, %var%
        else
            GuiControl, +cD6D6D6, %var%
        GuiControl, +Redraw, %var%
    }
}

checkPaths() {
    global g_current_tab, g_current_mode
    if (g_current_tab == 1)
        return
        
    Loop, 50 {
        edit_var := "edit_path_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (ErrorLevel) 
            break
        updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        edit_var := "edit_exec_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (ErrorLevel) 
            break
        updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        name_var := "edit_env_name_" g_current_tab "_" A_Index
        GuiControlGet, name_val,, %name_var%
        if (ErrorLevel) 
            break
        if (g_current_mode == "Apply")
            updateControlColor(name_var, name_val, true)
            
        edit_var := "edit_env_val_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (InStr(path_val, ":\") || InStr(path_val, "\\"))
            updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        edit_src := "edit_link_s_" g_current_tab "_" A_Index
        edit_tdir := "edit_link_tdir_" g_current_tab "_" A_Index
        GuiControlGet, src_val,, %edit_src%
        if (ErrorLevel) 
            break
        updateControlColor(edit_src, src_val)
        
        GuiControlGet, tgt_val,, %edit_tdir%
        updateControlColor(edit_tdir, tgt_val)
    }
}

; ==========================================
;         STATE MANAGEMENT CORE
; ==========================================
onManualSave:
    captureCurrentTabRows()
    saveState()
    MsgBox, 64, Saved, All dynamic configurations have been written to System-Config.ini.
return

onApplyConfigs:
    captureCurrentTabRows()
    saveState()
    GoSub, RunWindowsRegistryEngine
    env_updated := false
    For k, tab_name in g_tab_names {
        if (k == 1)
            continue
        if (applyTabConfig(tab_name))
            env_updated := true
    }
    if (env_updated)
        SendMessage, 0x1A, 0, "Environment",, ahk_id 0xFFFF
    MsgBox, 64, Apply All, All configurations applied successfully!
return

onApplyCurrentTab:
    captureCurrentTabRows()
    saveState()
    current_tab_name := g_tab_names[g_current_tab]
    if (g_current_tab == 1) {
        GoSub, RunWindowsRegistryEngine
    } else {
        if (applyTabConfig(current_tab_name))
            SendMessage, 0x1A, 0, "Environment",, ahk_id 0xFFFF
        MsgBox, 64, Apply Tab, Applied configurations for %current_tab_name%.
    }
return

RunWindowsRegistryEngine:
    updates_made := 0
    For _, sec_name in g_win_section_names {
        opts := g_win_sections[sec_name]
        For k, opt in opts {
            var_id := opt.id
            current_state := %var_id%
            initial_state := opt.initial_state
            if (current_state != initial_state) {
                target_state := current_state ? "Enabled" : "Disabled"
                target_dir := g_reg_dir "\" opt.path "\"
                extensions := ["reg", "ahk", "exe"]
                For idx, ext in extensions {
                    target_file := target_dir target_state "." ext
                    if FileExist(target_file) {
                        if (ext == "reg")
                            RunWait, regedit.exe /s "%target_file%"
                        else
                            RunWait, "%target_file%"
                        updates_made++
                        break
                    }
                }
                g_win_sections[sec_name][k].initial_state := current_state 
            }
        }
    }
    saveState()
    if (updates_made > 0)
        MsgBox, 64, Registry Updates, Applied %updates_made% changed registry configurations successfully.
return

GuiClose:
    captureCurrentTabRows()
    saveState()
ExitApp

captureCurrentTabRows() {
    global
    if (g_current_mode == "Apply")
        return
        
    Gui, Submit, NoHide
    For tab_idx, tab_name in g_tab_names {
        if (tab_idx == 1)
            continue
        data := g_tab_data[tab_name]
        For i, p in data.paths {
            var_n := "edit_path_name_" tab_idx "_" i
            var_edit := "edit_path_" tab_idx "_" i
            data.paths[i].name := %var_n%
            data.paths[i].val := %var_edit%
        }
        For i, e in data.envs {
            var_name := "edit_env_name_" tab_idx "_" i
            var_val := "edit_env_val_" tab_idx "_" i
            data.envs[i].name := %var_name%
            data.envs[i].val := %var_val%
        }
        For i, x in data.execs {
            var_edit := "edit_exec_" tab_idx "_" i
            data.execs[i] := %var_edit%
        }
        For i, l in data.links {
            var_src := "edit_link_s_" tab_idx "_" i
            var_tdir := "edit_link_tdir_" tab_idx "_" i
            var_tname := "edit_link_tname_" tab_idx "_" i
            var_type := "edit_link_type_" tab_idx "_" i
            data.links[i].src := %var_src%
            data.links[i].tgt_dir := %var_tdir%
            data.links[i].tgt_name := %var_tname%
            data.links[i].type := %var_type%
        }
    }
}

saveState() {
    global
    FileDelete, %g_ini_file% 
    tab_str := ""
    For k, v in g_tab_names
        tab_str .= (A_Index=1 ? "" : "|") . v
    IniWrite, %tab_str%, %g_ini_file%, Settings, Tabs
    IniWrite, %g_current_tab%, %g_ini_file%, Settings, ActiveTab
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode
    
    For _, sec_name in g_win_section_names {
        opts := g_win_sections[sec_name]
        For k, opt in opts {
            var_id := opt.id
            val := %var_id%
            IniWrite, %val%, %g_ini_file%, Windows, %var_id%
        }
    }
    For k, tab_name in g_tab_names {
        if (k == 1)
            continue
        data := g_tab_data[tab_name]
        For i, p in data.paths {
            IniWrite, % p.name, %g_ini_file%, %tab_name%_Paths, %i%_Name
            IniWrite, % p.val,  %g_ini_file%, %tab_name%_Paths, %i%_Val
        }
        For i, e in data.envs {
            IniWrite, % e.name, %g_ini_file%, %tab_name%_Envs, %i%_Name
            IniWrite, % e.val,  %g_ini_file%, %tab_name%_Envs, %i%_Val
        }
        For i, x in data.execs
            IniWrite, %x%, %g_ini_file%, %tab_name%_Execs, %i%
        For i, l in data.links {
            IniWrite, % l.src, %g_ini_file%, %tab_name%_Links, %i%_Src
            IniWrite, % l.tgt_dir, %g_ini_file%, %tab_name%_Links, %i%_TgtDir
            IniWrite, % l.tgt_name, %g_ini_file%, %tab_name%_Links, %i%_TgtName
            IniWrite, % l.type, %g_ini_file%, %tab_name%_Links, %i%_Type
        }
    }
}

loadState() {
    global
    if !FileExist(g_ini_file) {
        g_tab_names := ["WINDOWS"]
        g_tab_data := {}
        g_current_tab := 1
        g_current_mode := "Config"
        return
    }
    IniRead, tabs, %g_ini_file%, Settings, Tabs, WINDOWS
    g_tab_names := StrSplit(tabs, "|")
    IniRead, g_current_tab, %g_ini_file%, Settings, ActiveTab, 1
    IniRead, g_current_mode, %g_ini_file%, Settings, Mode, Config
    
    For _, sec_name in g_win_section_names {
        opts := g_win_sections[sec_name]
        For k, opt in opts {
            IniRead, val, %g_ini_file%, Windows, % opt.id, 0
            g_win_sections[sec_name][k].state := val
            g_win_sections[sec_name][k].initial_state := val
        }
    }
    For k, tab_name in g_tab_names {
        if (k == 1)
            continue
        g_tab_data[tab_name] := {"paths":[], "envs":[], "execs":[], "links":[]}
        Loop {
            IniRead, n, %g_ini_file%, %tab_name%_Paths, %A_Index%_Name, ||END||
            if (n == "||END||") {
                IniRead, val, %g_ini_file%, %tab_name%_Paths, %A_Index%, ||END||
                if (val == "||END||")
                    break
                g_tab_data[tab_name].paths.Push({"name": "", "val": val})
            } else {
                IniRead, v, %g_ini_file%, %tab_name%_Paths, %A_Index%_Val, %A_Space%
                g_tab_data[tab_name].paths.Push({"name": n, "val": v})
            }
        }
        if (g_tab_data[tab_name].paths.Length() == 0)
            g_tab_data[tab_name].paths.Push({"name": "", "val": ""})
            
        Loop {
            IniRead, n, %g_ini_file%, %tab_name%_Envs, %A_Index%_Name, ||END||
            if (n == "||END||")
                break
            IniRead, v, %g_ini_file%, %tab_name%_Envs, %A_Index%_Val, %A_Space%
            g_tab_data[tab_name].envs.Push({"name": n, "val": v})
        }
        Loop {
            IniRead, x, %g_ini_file%, %tab_name%_Execs, %A_Index%, ||END||
            if (x == "||END||")
                break
            g_tab_data[tab_name].execs.Push(x)
        }
        Loop {
            IniRead, src, %g_ini_file%, %tab_name%_Links, %A_Index%_Src, ||END||
            if (src == "||END||") {
                IniRead, l, %g_ini_file%, %tab_name%_Links, %A_Index%, ||END||
                if (l != "||END||") {
                    g_tab_data[tab_name].links.Push({"src": l, "tgt_dir": "", "tgt_name": "", "type": "Shortcut"})
                    continue
                }
                break
            }
            IniRead, tgt_dir, %g_ini_file%, %tab_name%_Links, %A_Index%_TgtDir, %A_Space%
            IniRead, tgt_name, %g_ini_file%, %tab_name%_Links, %A_Index%_TgtName, %A_Space%
            IniRead, type, %g_ini_file%, %tab_name%_Links, %A_Index%_Type, Shortcut
            
            if (tgt_dir == "" && tgt_name == "") {
                IniRead, old_tgt, %g_ini_file%, %tab_name%_Links, %A_Index%_Tgt, ||END||
                if (old_tgt != "||END||" && old_tgt != "") {
                    SplitPath, old_tgt, out_name, out_dir
                    tgt_dir := out_dir
                    tgt_name := out_name
                }
            }
            g_tab_data[tab_name].links.Push({"src": src, "tgt_dir": tgt_dir, "tgt_name": tgt_name, "type": type})
        }
    }
}

; ==========================================
;         THEMING & EXECUTION UTILITIES
; ==========================================
setDarkControl(hwnd) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

applyTabConfig(tab_name) {
    global g_tab_data
    data := g_tab_data[tab_name]
    env_changed := false
    
    For i, p in data.paths {
        if (p.name != "" && p.val != "") {
            RegWrite, REG_SZ, HKCU\Environment, % p.name, % p.val
            env_changed := true
        }
    }
    For i, e in data.envs {
        if (e.name != "" && e.val != "") {
            RegWrite, REG_SZ, HKCU\Environment, % e.name, % e.val
            env_changed := true
        }
    }
    For i, x in data.execs {
        if (x == "")
            continue
        attr := FileExist(x)
        if (attr) {
            if (InStr(attr, "D")) {
                Loop, Files, %x%\*.exe
                    Run, "%A_LoopFileFullPath%", %x%
                Loop, Files, %x%\*.bat
                    Run, "%A_LoopFileFullPath%", %x%
            } else {
                SplitPath, x, , out_dir
                Run, "%x%", %out_dir%
            }
        }
    }
    For i, l in data.links {
        if (l.src != "" && l.tgt_dir != "" && l.tgt_name != "") {
            shortcut_name := l.tgt_name
            if (l.type == "Shortcut" && !InStr(shortcut_name, ".lnk"))
                shortcut_name .= ".lnk"
                
            shortcut_path := l.tgt_dir "\" shortcut_name
            
            src_path := l.src
            
            if (l.type == "Shortcut") {
                if (FileExist(shortcut_path))
                    FileDelete, %shortcut_path%
                FileCreateShortcut, %src_path%, %shortcut_path%
            } else {
                ; Handling Symlink/Hardlink
                if (FileExist(shortcut_path)) {
                    ; Check if it's already a link
                    FileGetAttrib, attr, %shortcut_path%
                    if (InStr(attr, "L")) {
                        FileDelete, %shortcut_path%
                    } else {
                        ; Rename original target
                        FileMove, %shortcut_path%, %shortcut_path% . default
                    }
                }
                
                if (l.type == "Symlink") {
                    attr := FileExist(src_path)
                    cmd := (InStr(attr, "D")) ? "/c mklink /D" : "/c mklink"
                    RunWait, %ComSpec% %cmd% "%shortcut_path%" "%src_path%",, Hide
                } else if (l.type == "Hardlink") {
                    RunWait, %ComSpec% /c mklink /H "%shortcut_path%" "%src_path%",, Hide
                }
            }
        }
    }
    return env_changed
}

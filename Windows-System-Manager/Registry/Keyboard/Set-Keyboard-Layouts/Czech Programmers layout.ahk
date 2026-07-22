#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.


; ------------------------------------------------------------------------------
; 4. KEYBOARD LAYOUT CONFIGURATION
; ------------------------------------------------------------------------------

; Clear out any existing keyboard layout preload lists to prevent layout ghosting
RegDelete, HKEY_CURRENT_USER\Keyboard Layout\Preload
RegWrite, REG_SZ, HKEY_CURRENT_USER\Keyboard Layout\Preload, 1, 00000809 ; UK English as primary default
RegWrite, REG_SZ, HKEY_CURRENT_USER\Keyboard Layout\Preload, 2, 00020405 ; Czech Programmers as secondary

; Clean up any active layout overrides to prevent old setups from bleeding in
RegDelete, HKEY_CURRENT_USER\Control Panel\International\User Profile
RegDelete, HKEY_CURRENT_USER\Control Panel\International\User Profile System Backup

; Explicitly construct the allowed language list in the modern Windows UI framework
; 0809:00000809 = English (United Kingdom)
; 0405:00020405 = Czech (Programmers)
RegWrite, REG_MULTI_SZ, HKEY_CURRENT_USER\Control Panel\International\User Profile, Languages, en-GB`nc_CZ
RegWrite, REG_DWORD, HKEY_CURRENT_USER\Control Panel\International\User Profile, HttpAcceptLanguageOptOut, 1

; Assign the specific layout variants to the language profiles
RegWrite, REG_DWORD, HKEY_CURRENT_USER\Control Panel\International\User Profile\Languages\en-GB, Lcid, 0x00000809
RegWrite, REG_MULTI_SZ, HKEY_CURRENT_USER\Control Panel\International\User Profile\Languages\en-GB, KeyboardLayouts, 0809:00000809

RegWrite, REG_DWORD, HKEY_CURRENT_USER\Control Panel\International\User Profile\Languages\c_CZ, Lcid, 0x00000405
RegWrite, REG_MULTI_SZ, HKEY_CURRENT_USER\Control Panel\International\User Profile\Languages\c_CZ, KeyboardLayouts, 0405:00020405

; Set English UK as the strict system startup preferred override
RegWrite, REG_SZ, HKEY_CURRENT_USER\Control Panel\International\User Profile, TargetLanguageInUserProfile, en-GB

; FORCE TASKBAR / SYSTEM TRAY LAYOUT ICON VISIBILITY
; ShowStatus: 4 = Docked in taskbar, 3 = Hidden, 0 = Floating
RegWrite, REG_DWORD, HKEY_CURRENT_USER\Software\Microsoft\CTF\LangBar, ShowStatus, 4
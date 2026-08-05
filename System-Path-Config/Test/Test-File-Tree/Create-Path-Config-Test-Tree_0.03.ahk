#NoEnv
#SingleInstance Force
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

script_version := "0.03"
test_root := A_ScriptDir

create_result := createTestTree( test_root )
verify_result := verifyTestTree( test_root )

result_text := "Path-Config test tree " script_version "`n`n"
result_text .= create_result.message "`n"
result_text .= verify_result.message

if ( create_result.success && verify_result.success )
{
    MsgBox, 64, Test Tree Created, %result_text%
    Run, explorer.exe "%test_root%"
}
else
{
    MsgBox, 16, Test Tree Error, %result_text%
}

ExitApp


/*
Creates the complete Path-Config test tree.
Returns an object containing success state and a status message.
*/
createTestTree( test_root )
{
    source_root := test_root "\Source"
    target_root := test_root "\Target"
    hardlink_source_dir := source_root "\hardlink-source"
    softlink_source_dir := source_root "\softlink-source"
    file_links_dir := source_root "\file-links"

    hardlink_source_file := hardlink_source_dir "\foo.txt"
    softlink_source_file := softlink_source_dir "\foo.txt"
    hardlink_test_file := file_links_dir "\hardlink-test.txt"
    junction_test_path := file_links_dir "\junction-test.txt"
    shortcut_test_file := file_links_dir "\link-test.lnk"
    foo_exe_path := source_root "\foo.exe"

    FileCreateDir, %hardlink_source_dir%
    FileCreateDir, %softlink_source_dir%
    FileCreateDir, %file_links_dir%
    FileCreateDir, %target_root%

    if ( ErrorLevel )
    {
        return {"success":false, "message":"Failed to create one or more test directories."}
    }

    if ( !writeTextFile( hardlink_source_file, "Hard-link source file.`r`n" ) )
    {
        return {"success":false, "message":"Failed to create hardlink-source\\foo.txt."}
    }

    if ( !writeTextFile( softlink_source_file, "Shortcut source file.`r`n" ) )
    {
        return {"success":false, "message":"Failed to create softlink-source\\foo.txt."}
    }

    if ( !createTestExecutable( foo_exe_path ) )
    {
        return {"success":false, "message":"Failed to create foo.exe from Windows Notepad."}
    }

    deleteTestLink( hardlink_test_file, false )
    deleteTestLink( shortcut_test_file, false )
    deleteTestLink( junction_test_path, true )

    if ( !createHardLink( hardlink_test_file, hardlink_source_file ) )
    {
        return {"success":false, "message":"Failed to create hardlink-test.txt."}
    }

    if ( !createDirectoryJunction( junction_test_path, target_root ) )
    {
        return {"success":false, "message":"Failed to create junction-test.txt directory junction."}
    }

    FileCreateShortcut, %softlink_source_file%, %shortcut_test_file%, %softlink_source_dir%,, Path-Config shortcut test

    if ( ErrorLevel )
    {
        return {"success":false, "message":"Failed to create link-test.lnk."}
    }

    return {"success":true, "message":"Creation: PASS"}
}


/*
Writes a text file and replaces any previous file at the same path.
Returns true when the file exists after writing.
*/
writeTextFile( file_path, file_text )
{
    FileDelete, %file_path%
    FileAppend, %file_text%, %file_path%

    return FileExist( file_path ) ? true : false
}


/*
Copies Windows Notepad as a harmless valid test executable.
Returns true when foo.exe was created.
*/
createTestExecutable( target_path )
{
    source_exe := A_WinDir "\System32\notepad.exe"
    FileDelete, %target_path%
    FileCopy, %source_exe%, %target_path%, 1

    return FileExist( target_path ) ? true : false
}


/*
Creates an NTFS hard link by using the native Windows API.
The source and link remain on the same volume because both are under the script folder.
*/
createHardLink( link_path, source_path )
{
    create_result := DllCall( "Kernel32.dll\CreateHardLinkW", "WStr", link_path, "WStr", source_path, "Ptr", 0, "Int" )

    return create_result ? true : false
}


/*
Creates a directory junction using the Windows mklink command.
The junction name may use a .txt suffix, but it is still a directory entry.
*/
createDirectoryJunction( junction_path, target_path )
{
    RunWait, %ComSpec% /D /C mklink /J "%junction_path%" "%target_path%",, Hide UseErrorLevel

    return ( ErrorLevel = 0 )
}


/*
Deletes a previously generated link without deleting its target.
Directory mode uses rmdir so a junction target remains untouched.
*/
deleteTestLink( link_path, is_directory )
{
    if ( !FileExist( link_path ) )
    {
        return true
    }

    if ( is_directory )
    {
        RunWait, %ComSpec% /D /C rmdir "%link_path%",, Hide UseErrorLevel
        return ( ErrorLevel = 0 )
    }

    FileDelete, %link_path%

    return !FileExist( link_path )
}


/*
Verifies the generated tree and all three link types.
Returns a combined status message suitable for a test result dialog.
*/
verifyTestTree( test_root )
{
    source_root := test_root "\Source"
    target_root := test_root "\Target"
    hardlink_source_file := source_root "\hardlink-source\foo.txt"
    softlink_source_file := source_root "\softlink-source\foo.txt"
    hardlink_test_file := source_root "\file-links\hardlink-test.txt"
    junction_test_path := source_root "\file-links\junction-test.txt"
    shortcut_test_file := source_root "\file-links\link-test.lnk"
    foo_exe_path := source_root "\foo.exe"

    error_text := ""

    verifyPathExists( source_root, "Directory Source", error_text )
    verifyPathExists( target_root, "Directory Target", error_text )
    verifyPathExists( hardlink_source_file, "hardlink-source\\foo.txt", error_text )
    verifyPathExists( softlink_source_file, "softlink-source\\foo.txt", error_text )
    verifyPathExists( hardlink_test_file, "file-links\\hardlink-test.txt", error_text )
    verifyPathExists( junction_test_path, "file-links\\junction-test.txt", error_text )
    verifyPathExists( shortcut_test_file, "file-links\\link-test.lnk", error_text )
    verifyPathExists( foo_exe_path, "foo.exe", error_text )

    if ( FileExist( hardlink_source_file ) && FileExist( hardlink_test_file ) )
    {
        source_identity := getFileIdentity( hardlink_source_file )
        link_identity := getFileIdentity( hardlink_test_file )

        if ( source_identity = "" || source_identity != link_identity )
        {
            error_text .= "`nHard-link identity does not match its source."
        }
    }

    if ( FileExist( junction_test_path ) )
    {
        if ( !isDirectoryReparsePoint( junction_test_path ) )
        {
            error_text .= "`njunction-test.txt is not detected as a directory reparse point."
        }
    }

    if ( FileExist( shortcut_test_file ) )
    {
        FileGetShortcut, %shortcut_test_file%, shortcut_target

        if ( shortcut_target != softlink_source_file )
        {
            error_text .= "`nlink-test.lnk points to an unexpected target."
        }
    }

    if ( error_text != "" )
    {
        return {"success":false, "message":"Verification: FAIL" error_text}
    }

    return {"success":true, "message":"Verification: PASS"}
}


/*
Checks native Windows file-attribute bits for a directory reparse point.
This works for junctions even when their names use a file-like extension.
*/
isDirectoryReparsePoint( file_path )
{
    static invalid_attributes := 0xFFFFFFFF
    static file_attribute_directory := 0x00000010
    static file_attribute_reparse_point := 0x00000400

    file_attributes := DllCall( "Kernel32.dll\GetFileAttributesW", "WStr", file_path, "UInt" )

    if ( file_attributes = invalid_attributes )
    {
        return false
    }

    is_directory := file_attributes & file_attribute_directory
    is_reparse_point := file_attributes & file_attribute_reparse_point

    return ( is_directory && is_reparse_point )
}


/*
Adds an error when an expected file or directory is missing.
The error string is passed by reference.
*/
verifyPathExists( file_path, display_name, ByRef error_text )
{
    if ( !FileExist( file_path ) )
    {
        error_text .= "`nMissing: " display_name
    }

    ; return
}


/*
Returns a stable volume and file-index identity for a file.
Hard-linked paths must return the same identity.
*/
getFileIdentity( file_path )
{
    static generic_read := 0x80000000
    static file_share_all := 0x00000007
    static open_existing := 3
    static file_attribute_normal := 0x00000080
    static invalid_handle := -1

    file_handle := DllCall( "Kernel32.dll\CreateFileW", "WStr", file_path, "UInt", generic_read, "UInt", file_share_all, "Ptr", 0, "UInt", open_existing, "UInt", file_attribute_normal, "Ptr", 0, "Ptr" )

    if ( file_handle = invalid_handle )
    {
        return ""
    }

    VarSetCapacity( file_info, 52, 0 )
    info_result := DllCall( "Kernel32.dll\GetFileInformationByHandle", "Ptr", file_handle, "Ptr", &file_info, "Int" )

    DllCall( "Kernel32.dll\CloseHandle", "Ptr", file_handle )

    if ( !info_result )
    {
        return ""
    }

    volume_serial := NumGet( file_info, 28, "UInt" )
    file_index_high := NumGet( file_info, 44, "UInt" )
    file_index_low := NumGet( file_info, 48, "UInt" )

    return volume_serial ":" file_index_high ":" file_index_low
}

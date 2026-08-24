[CmdletBinding()]
param(
    [switch]$PassThru
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:ApprovalByName = @{}
$script:Records = New-Object System.Collections.Generic.List[object]

function ConvertTo-HexString {
    param([object]$Value)

    if ($Value -is [byte[]]) {
        return (($Value | ForEach-Object { $_.ToString('X2') }) -join ' ')
    }

    if ($null -eq $Value) {
        return ''
    }

    return [string]$Value
}

function ConvertFrom-StartupApprovedData {
    param([object]$Value)

    $state = 'Unknown'
    $disabledAtUtc = $null

    if ($Value -is [byte[]] -and $Value.Length -gt 0) {
        if ($Value[0] -eq 2) {
            $state = 'On'
        }
        elseif ($Value[0] -eq 3) {
            $state = 'Off'
        }

        if ($Value.Length -ge 12) {
            try {
                $fileTime = [BitConverter]::ToInt64($Value, 4)
                if ($fileTime -gt 0) {
                    $disabledAtUtc = [DateTime]::FromFileTimeUtc($fileTime).ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
            catch {
                $disabledAtUtc = $null
            }
        }
    }

    return [pscustomobject]@{
        State         = $state
        DisabledAtUtc = $disabledAtUtc
        RawData       = ConvertTo-HexString $Value
    }
}

function Get-HiveLabel {
    param([Microsoft.Win32.RegistryHive]$Hive)

    if ($Hive -eq [Microsoft.Win32.RegistryHive]::CurrentUser) {
        return 'HKCU'
    }

    return 'HKLM'
}

function Get-ViewLabel {
    param([Microsoft.Win32.RegistryView]$View)

    if ($View -eq [Microsoft.Win32.RegistryView]::Registry32) {
        return '32-bit'
    }

    return '64-bit'
}

function Get-RegistryValues {
    param(
        [Microsoft.Win32.RegistryHive]$Hive,
        [Microsoft.Win32.RegistryView]$View,
        [string]$SubKey
    )

    $baseKey = $null
    $key = $null

    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, $View)
        $key = $baseKey.OpenSubKey($SubKey, $false)
        if ($null -eq $key) {
            return @()
        }

        $values = @()
        foreach ($name in $key.GetValueNames()) {
            $values += [pscustomobject]@{
                Name  = $name
                Value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                Kind  = $key.GetValueKind($name).ToString()
            }
        }

        return $values
    }
    catch {
        $script:Warnings.Add(('{0} ({1}): {2}' -f (Get-HiveLabel $Hive), (Get-ViewLabel $View), $_.Exception.Message))
        return @()
    }
    finally {
        if ($null -ne $key) {
            $key.Close()
        }
        if ($null -ne $baseKey) {
            $baseKey.Close()
        }
    }
}

function Get-ApprovalLookupKey {
    param(
        [string]$Scope,
        [string]$Bucket,
        [string]$Name
    )

    return ('{0}|{1}|{2}' -f $Scope, $Bucket, $Name).ToUpperInvariant()
}

$views = @(
    [Microsoft.Win32.RegistryView]::Registry64,
    [Microsoft.Win32.RegistryView]::Registry32
)

$hives = @(
    [pscustomobject]@{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; Scope = 'Current user' },
    [pscustomobject]@{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; Scope = 'All users' }
)

$approvalRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$approvalBuckets = @('Run', 'Run32', 'StartupFolder', 'StartupTask')
$seenApproval = @{}

foreach ($hiveInfo in $hives) {
    foreach ($view in $views) {
        foreach ($bucket in $approvalBuckets) {
            $subKey = $approvalRoot + '\' + $bucket
            foreach ($entry in (Get-RegistryValues -Hive $hiveInfo.Hive -View $view -SubKey $subKey)) {
                $approval = ConvertFrom-StartupApprovedData $entry.Value
                $path = '{0}\{1}' -f (Get-HiveLabel $hiveInfo.Hive), $subKey
                $recordIdentity = ('{0}|{1}|{2}' -f $path, $entry.Name, $approval.RawData).ToUpperInvariant()

                # Some StartupApproved keys are not registry-view redirected. Avoid printing
                # the same physical value twice when 32-bit and 64-bit views return it.
                if (-not $seenApproval.ContainsKey($recordIdentity)) {
                    $seenApproval[$recordIdentity] = $true
                    $script:Records.Add([pscustomobject]@{
                        RecordType   = 'StartupApproved'
                        Scope        = $hiveInfo.Scope
                        View         = (Get-ViewLabel $view)
                        Source       = $bucket
                        Name         = $entry.Name
                        State        = $approval.State
                        Data         = ''
                        ValueKind    = $entry.Kind
                        DisabledUtc  = $approval.DisabledAtUtc
                        RawApproval  = $approval.RawData
                        RegistryPath = $path
                    })
                }

                $lookupKey = Get-ApprovalLookupKey -Scope $hiveInfo.Scope -Bucket $bucket -Name $entry.Name
                if (-not $script:ApprovalByName.ContainsKey($lookupKey)) {
                    $script:ApprovalByName[$lookupKey] = $approval
                }
            }
        }
    }
}

$startupLocations = @(
    [pscustomobject]@{ Source = 'Run'; SubKey = 'Software\Microsoft\Windows\CurrentVersion\Run'; ValueNames = $null },
    [pscustomobject]@{ Source = 'RunOnce'; SubKey = 'Software\Microsoft\Windows\CurrentVersion\RunOnce'; ValueNames = $null },
    [pscustomobject]@{ Source = 'RunOnceEx'; SubKey = 'Software\Microsoft\Windows\CurrentVersion\RunOnceEx'; ValueNames = $null },
    [pscustomobject]@{ Source = 'Policy Run'; SubKey = 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; ValueNames = $null },
    [pscustomobject]@{ Source = 'Windows Load/Run'; SubKey = 'Software\Microsoft\Windows NT\CurrentVersion\Windows'; ValueNames = @('Load', 'Run') },
    [pscustomobject]@{ Source = 'Winlogon'; SubKey = 'Software\Microsoft\Windows NT\CurrentVersion\Winlogon'; ValueNames = @('Shell', 'Userinit') }
)
$seenCommands = @{}

foreach ($hiveInfo in $hives) {
    foreach ($view in $views) {
        foreach ($location in $startupLocations) {
            foreach ($entry in (Get-RegistryValues -Hive $hiveInfo.Hive -View $view -SubKey $location.SubKey)) {
                if ($null -ne $location.ValueNames -and $location.ValueNames -notcontains $entry.Name) {
                    continue
                }

                $state = 'Not recorded'
                $disabledUtc = $null
                $rawApproval = ''

                if ($location.Source -eq 'Run') {
                    $bucket = 'Run'
                    if ($view -eq [Microsoft.Win32.RegistryView]::Registry32) {
                        $bucket = 'Run32'
                    }

                    $lookupKey = Get-ApprovalLookupKey -Scope $hiveInfo.Scope -Bucket $bucket -Name $entry.Name
                    if ($script:ApprovalByName.ContainsKey($lookupKey)) {
                        $state = $script:ApprovalByName[$lookupKey].State
                        $disabledUtc = $script:ApprovalByName[$lookupKey].DisabledAtUtc
                        $rawApproval = $script:ApprovalByName[$lookupKey].RawData
                    }
                }

                $registryPath = '{0}\{1}' -f (Get-HiveLabel $hiveInfo.Hive), $location.SubKey
                $data = ConvertTo-HexString $entry.Value
                $recordIdentity = ('{0}|{1}|{2}|{3}' -f $registryPath, $entry.Name, $entry.Kind, $data).ToUpperInvariant()
                if ($seenCommands.ContainsKey($recordIdentity)) {
                    continue
                }
                $seenCommands[$recordIdentity] = $true

                $script:Records.Add([pscustomobject]@{
                    RecordType   = 'Startup command'
                    Scope        = $hiveInfo.Scope
                    View         = (Get-ViewLabel $view)
                    Source       = $location.Source
                    Name         = $entry.Name
                    State        = $state
                    Data         = $data
                    ValueKind    = $entry.Kind
                    DisabledUtc  = $disabledUtc
                    RawApproval  = $rawApproval
                    RegistryPath = $registryPath
                })
            }
        }
    }
}

$orderedRecords = @($script:Records | Sort-Object RecordType, Scope, Source, Name, View)

if ($PassThru) {
    $orderedRecords
    return
}

Write-Host 'Windows startup registry inventory' -ForegroundColor Cyan
Write-Host ('Computer: {0}    User: {1}\{2}' -f $env:COMPUTERNAME, $env:USERDOMAIN, $env:USERNAME)
Write-Host ('Collected: {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Write-Host ''
Write-Host 'This report is read-only. It does not include scheduled tasks, services, or files in Startup folders.' -ForegroundColor DarkGray
Write-Host ''

$commandRecords = @($orderedRecords | Where-Object { $_.RecordType -eq 'Startup command' })
$approvalRecords = @($orderedRecords | Where-Object { $_.RecordType -eq 'StartupApproved' })

Write-Host ('Startup command entries ({0})' -f $commandRecords.Count) -ForegroundColor Yellow
if ($commandRecords.Count -eq 0) {
    Write-Host '  None found.'
}
else {
    $commandRecords | Format-List Scope, View, Source, Name, State, Data, ValueKind, DisabledUtc, RawApproval, RegistryPath | Out-Host
}

Write-Host ('StartupApproved status entries ({0})' -f $approvalRecords.Count) -ForegroundColor Yellow
if ($approvalRecords.Count -eq 0) {
    Write-Host '  None found.'
}
else {
    $approvalRecords | Format-List Scope, View, Source, Name, State, DisabledUtc, RawApproval, RegistryPath | Out-Host
}

if ($script:Warnings.Count -gt 0) {
    Write-Host ('Warnings ({0})' -f $script:Warnings.Count) -ForegroundColor Yellow
    foreach ($message in $script:Warnings) {
        Write-Warning $message
    }
}

Write-Host ('Summary: {0} command entries, {1} approval records.' -f $commandRecords.Count, $approvalRecords.Count) -ForegroundColor Cyan

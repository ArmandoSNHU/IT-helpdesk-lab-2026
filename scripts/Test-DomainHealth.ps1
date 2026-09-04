<#
.SYNOPSIS
    Read-only health check for a domain controller: services, DNS, replication,
    time sync, SYSVOL and disk.

.DESCRIPTION
    The first thing I run when a user reports "I can't log in" or "the network
    is down". It changes nothing — every check is a read — so it is safe to run
    on a production DC during an incident.

    Output is an object per check, so it can be formatted for a ticket, exported
    to CSV, or piped into a monitoring system.

.PARAMETER ComputerName
    DC to check. Defaults to the local machine.

.PARAMETER ExportCsv
    Optional path to write results for attaching to a ticket.

.EXAMPLE
    .\Test-DomainHealth.ps1

.EXAMPLE
    .\Test-DomainHealth.ps1 -ExportCsv .\dc01-health.csv

    Produces evidence to attach to a ServiceNow incident.

.NOTES
    Author : Armando Gomez
    Lab    : IT-helpdesk-lab-2026 (Part 2 / Part 10)
    Safe   : read-only. No configuration is modified.
#>

[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [string]$ExportCsv,
    [ValidateRange(1, 99)]
    [int]$DiskWarnPercentFree = 15
)

Set-StrictMode -Version Latest

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Check,
        [ValidateSet('PASS', 'WARN', 'FAIL', 'INFO')][string]$Status,
        [string]$Detail
    )
    $results.Add([pscustomobject]@{
        Timestamp = Get-Date -Format 's'
        Computer  = $ComputerName
        Check     = $Check
        Status    = $Status
        Detail    = $Detail
    })
}

Write-Verbose "Checking $ComputerName"

# --- 1. Core AD DS services ------------------------------------------------
# If any of these are stopped, authentication is broken and everything else
# downstream is noise.
$coreServices = @{
    'NTDS'      = 'Active Directory Domain Services'
    'DNS'       = 'DNS Server'
    'Netlogon'  = 'Net Logon'
    'W32Time'   = 'Windows Time'
    'KDC'       = 'Kerberos Key Distribution Center'
}

foreach ($svc in $coreServices.GetEnumerator()) {
    try {
        $s = Get-Service -Name $svc.Key -ComputerName $ComputerName -ErrorAction Stop
        if ($s.Status -eq 'Running') {
            Add-Result -Check "Service: $($svc.Value)" -Status PASS -Detail 'Running'
        }
        else {
            Add-Result -Check "Service: $($svc.Value)" -Status FAIL -Detail "State is $($s.Status)"
        }
    }
    catch {
        Add-Result -Check "Service: $($svc.Value)" -Status WARN -Detail "Not found or unreachable: $($_.Exception.Message)"
    }
}

# --- 2. DNS resolution -----------------------------------------------------
# A DC that cannot resolve its own domain will fail replication and logons.
try {
    $domain = (Get-ADDomain -ErrorAction Stop).DNSRoot
    $null = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
    Add-Result -Check 'DNS: resolve domain' -Status PASS -Detail "Resolved $domain"
}
catch {
    Add-Result -Check 'DNS: resolve domain' -Status FAIL -Detail $_.Exception.Message
}

# --- 3. Replication --------------------------------------------------------
# Any consecutive failure count above zero means changes are not converging.
try {
    $failures = Get-ADReplicationFailure -Target $ComputerName -ErrorAction Stop
    if (-not $failures) {
        Add-Result -Check 'AD replication' -Status PASS -Detail 'No replication failures reported'
    }
    else {
        foreach ($f in $failures) {
            Add-Result -Check 'AD replication' -Status FAIL -Detail "$($f.Partner): $($f.FailureCount) failure(s), last $($f.LastError)"
        }
    }
}
catch {
    Add-Result -Check 'AD replication' -Status WARN -Detail "Could not query: $($_.Exception.Message)"
}

# --- 4. Time skew ----------------------------------------------------------
# Kerberos rejects tickets beyond a 5-minute skew, which presents to users as
# random logon failures. This is a classic root cause worth checking early.
try {
    $w32tm = w32tm /query /status 2>&1 | Out-String
    if ($w32tm -match 'Source:\s*(.+)') {
        Add-Result -Check 'Time sync source' -Status INFO -Detail $Matches[1].Trim()
    }
    if ($w32tm -match 'Last Successful Sync Time:\s*(.+)') {
        Add-Result -Check 'Time last sync' -Status PASS -Detail $Matches[1].Trim()
    }
    else {
        Add-Result -Check 'Time last sync' -Status WARN -Detail 'No successful sync reported'
    }
}
catch {
    Add-Result -Check 'Time sync' -Status WARN -Detail $_.Exception.Message
}

# --- 5. SYSVOL / NETLOGON shares ------------------------------------------
# Missing shares mean Group Policy will not apply to any client.
foreach ($share in @('SYSVOL', 'NETLOGON')) {
    if (Test-Path "\\$ComputerName\$share") {
        Add-Result -Check "Share: $share" -Status PASS -Detail 'Reachable'
    }
    else {
        Add-Result -Check "Share: $share" -Status FAIL -Detail 'Not reachable — Group Policy will not apply'
    }
}

# --- 6. Disk space ---------------------------------------------------------
# A full system volume stops the AD database from writing.
try {
    Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $ComputerName -Filter 'DriveType=3' -ErrorAction Stop |
        ForEach-Object {
            $pct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
            $status = if ($pct -lt $DiskWarnPercentFree) { 'WARN' } else { 'PASS' }
            Add-Result -Check "Disk $($_.DeviceID)" -Status $status -Detail "$pct% free ($([math]::Round($_.FreeSpace/1GB,1)) GB)"
        }
}
catch {
    Add-Result -Check 'Disk space' -Status WARN -Detail $_.Exception.Message
}

# --- Report ----------------------------------------------------------------
$results | Format-Table Check, Status, Detail -AutoSize

$fail = @($results | Where-Object Status -eq 'FAIL').Count
$warn = @($results | Where-Object Status -eq 'WARN').Count

Write-Host ""
Write-Host ("  {0} checks | {1} failed | {2} warnings" -f $results.Count, $fail, $warn) -ForegroundColor $(
    if ($fail) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })

if ($ExportCsv) {
    $results | Export-Csv -Path $ExportCsv -NoTypeInformation
    Write-Host "  Exported: $ExportCsv"
}

# Exit code lets this drive a scheduled task or monitoring check.
if ($fail -gt 0) { exit 2 } elseif ($warn -gt 0) { exit 1 } else { exit 0 }

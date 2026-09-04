<#
.SYNOPSIS
    Bulk-creates Active Directory users from a CSV, safely and idempotently.

.DESCRIPTION
    Written for the Windows Server 2022 lab in this repository, but the shape is
    what I use for real onboarding work: validate the whole file BEFORE creating
    anything, skip accounts that already exist instead of erroring, and support
    -WhatIf so a run can be rehearsed against production without touching it.

    Every action is written to a transcript log so the run can be audited or
    handed to a ticket as evidence.

.PARAMETER CsvPath
    CSV with columns: FirstName, LastName, Department, Title, JobOU
    Extra columns are ignored.

.PARAMETER DefaultPassword
    Initial password as a SecureString. Users must change it at first logon.
    If omitted the script prompts, so the password never lands in a command
    line, a script file, or PowerShell history.

.PARAMETER LogPath
    Directory for the run log. Defaults to .\logs.

.EXAMPLE
    .\New-LabADUser.ps1 -CsvPath .\users.csv -WhatIf

    Rehearses the run. Nothing is created. This is how you check a file before
    onboarding day.

.EXAMPLE
    .\New-LabADUser.ps1 -CsvPath .\users.csv -Verbose

.NOTES
    Author : Armando Gomez
    Lab    : IT-helpdesk-lab-2026 (Part 3 / Part 4)
    Needs  : RSAT ActiveDirectory module, rights to create users in the target OU
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) { throw "CSV not found: $_" }
        $true
    })]
    [string]$CsvPath,

    [ValidateNotNullOrEmpty()]
    [string]$DomainSuffix = 'lab.local',

    # SecureString, not [string]. A plaintext password parameter ends up in
    # PSReadLine history, process listings and transcript logs. Omitting it
    # makes PowerShell prompt securely instead.
    [Parameter(Mandatory)]
    [SecureString]$DefaultPassword,

    [string]$LogPath = (Join-Path $PSScriptRoot 'logs')
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw 'ActiveDirectory module not found. Install RSAT: Install-WindowsFeature RSAT-AD-PowerShell'
    }
    Import-Module ActiveDirectory

    if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
    $logFile = Join-Path $LogPath ("New-LabADUser_{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

    function Write-RunLog {
        param([string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
        $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
        Add-Content -Path $logFile -Value $line
        switch ($Level) {
            'ERROR' { Write-Error $Message -ErrorAction Continue }
            'WARN'  { Write-Warning $Message }
            default { Write-Verbose $Message }
        }
    }

    # Deterministic SAM: first initial + last name, lowercased, truncated to the
    # 20-character limit AD enforces on sAMAccountName.
    function Get-SamAccountName {
        param([string]$First, [string]$Last)
        $raw = ($First.Substring(0, 1) + $Last) -replace '[^a-zA-Z0-9]', ''
        return $raw.ToLower().Substring(0, [Math]::Min(20, $raw.Length))
    }

    $stats = [ordered]@{ Created = 0; Skipped = 0; Failed = 0 }
    Write-RunLog "Run started. CSV=$CsvPath WhatIf=$($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf'))"
}

process {
    $rows = Import-Csv -Path $CsvPath

    # Validate the ENTIRE file before creating anything. A half-applied
    # onboarding batch is far worse to clean up than a rejected file.
    $required = @('FirstName', 'LastName', 'Department', 'Title', 'JobOU')
    $columns = $rows | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    $missing = $required | Where-Object { $_ -notin $columns }
    if ($missing) {
        throw "CSV is missing required column(s): $($missing -join ', ')"
    }

    $blank = $rows | Where-Object { -not $_.FirstName -or -not $_.LastName }
    if ($blank) {
        throw "$($blank.Count) row(s) have a blank FirstName or LastName. Fix the CSV and re-run."
    }
    Write-RunLog "Validated $($rows.Count) row(s); all required columns present."

    foreach ($row in $rows) {
        $sam = Get-SamAccountName -First $row.FirstName -Last $row.LastName
        $display = "$($row.FirstName) $($row.LastName)"

        # Idempotent: re-running the same CSV must not error or duplicate.
        if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
            Write-RunLog "SKIP  $sam ($display) already exists." -Level WARN
            $stats.Skipped++
            continue
        }

        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$($row.JobOU)'" -ErrorAction SilentlyContinue)) {
            Write-RunLog "FAIL  $sam target OU does not exist: $($row.JobOU)" -Level ERROR
            $stats.Failed++
            continue
        }

        if ($PSCmdlet.ShouldProcess($display, "Create AD user '$sam' in $($row.JobOU)")) {
            try {
                New-ADUser `
                    -Name $display `
                    -GivenName $row.FirstName `
                    -Surname $row.LastName `
                    -SamAccountName $sam `
                    -UserPrincipalName "$sam@$DomainSuffix" `
                    -DisplayName $display `
                    -Department $row.Department `
                    -Title $row.Title `
                    -Path $row.JobOU `
                    -AccountPassword $DefaultPassword `
                    -ChangePasswordAtLogon $true `
                    -Enabled $true

                Write-RunLog "OK    Created $sam ($display) in $($row.JobOU)"
                $stats.Created++
            }
            catch {
                Write-RunLog "FAIL  $sam - $($_.Exception.Message)" -Level ERROR
                $stats.Failed++
            }
        }
    }
}

end {
    Write-RunLog "Run complete. Created=$($stats.Created) Skipped=$($stats.Skipped) Failed=$($stats.Failed)"
    Write-Host ""
    Write-Host "  Created : $($stats.Created)" -ForegroundColor Green
    Write-Host "  Skipped : $($stats.Skipped) (already existed)" -ForegroundColor Yellow
    Write-Host "  Failed  : $($stats.Failed)" -ForegroundColor $(if ($stats.Failed) { 'Red' } else { 'Gray' })
    Write-Host "  Log     : $logFile"

    # Non-zero exit on failure so this can be used in a pipeline or scheduled task.
    if ($stats.Failed -gt 0) { exit 1 }
}

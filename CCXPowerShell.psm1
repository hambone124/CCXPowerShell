function New-CcxDurationTotalsReport {
    param (
        [Parameter(Mandatory)]$SourceCSV,
        [Parameter(Mandatory)]$DestinationCSV,
        [switch]$ShowReport
    )

    $CcxDurationTotals = Get-CcxDurationTotals -Path $SourceCSV
    $CcxDurationTotals | Export-Csv -Path $DestinationCSV
    if ($ShowReport) {
        $CcxDurationTotals | Format-Table -Property *
    }
}

function Get-CcxDurationTotals {
    param (
        $Path = "./.private/cx_clean.csv"
    )

    # Import CCX data from CSV file
    $CcxData = Import-CcxCsv -Path $Path

    # Get unique properties values for each field
    $AgentIDs = $CcxData | Select-Object -ExpandProperty 'Agent ID' -Unique | Sort-Object
    $Dates = $CcxData.'State Transition Time'.Date | Select-Object -Unique | Sort-Object
    $ReasonCodes = $CcxData.'Reason Code' | Select-Object -Unique | Sort-Object
    
    # Filter down by Agent ID > Date > Reason Code
    foreach ($ID in $AgentIDs) {
        $FilteredToID = $CcxData | Where-Object 'Agent ID' -EQ $ID
        foreach ($Date in $Dates) {
            $FilteredToDate = $FilteredToID | Where-Object {$_.'State Transition Time'.Date -eq $Date}
            foreach ($ReasonCode in $ReasonCodes) {
                $FilteredToReasonCode = $FilteredToDate | Where-Object 'Reason Code' -EQ $ReasonCode
                
                # Calculate duration totals for a certain Reason Code on a certain Date for a certain Agent
                $DurationTotal = [System.TimeSpan]::Zero                
                foreach ($Record in $FilteredToReasonCode) {
                    $DurationTotal += $Record.Duration
                }
                
                # Construct and return data object if duration total is greater than zero
                if ($DurationTotal -gt [System.TimeSpan]::Zero) {                    
                    [PSCustomObject]@{
                        'Agent Name' = $FilteredToReasonCode.'Agent Name' | Get-FirstOfArray
                        'Agent ID' = $ID
                        Extension = $FilteredToReasonCode.Extension | Get-FirstOfArray
                        Date = $Date
                        'Reason Code' = $ReasonCode
                        'Duration Total' = $DurationTotal
                    }                
                }
            }
        }       
    }
}

function Import-CcxCsv {
    param (
        [ValidateScript({Test-Path -Path $_})]
        [Parameter(Mandatory)]$Path
    )

    # Get file contents
    $Content = Get-Content -Path $Path
    
    # Filter out lines with multiple consecutive commas
    $ContentArray = $Content.Split('`r`n')
    $CleanContentArray = $ContentArray | Where-Object {$_ -notmatch ',,,,,'}

    # Build new CSV data
    $Result = [System.String]::Empty   
    foreach ($Line in $CleanContentArray) {
        $Result += $Line + "`r`n"
    }
    
    # Convert to PowerShell objects
    $CcxData = $Result | ConvertFrom-Csv

    # Convert strings to proper .NET object types
    foreach ($DataObject in $CcxData) {
        $DataObject.Extension = [System.UInt16]::Parse($DataObject.Extension)
        $DataObject.'State Transition Time' = [System.DateTime]::Parse($DataObject.'State Transition Time')
        $DataObject.'Reason Code' = [System.UInt16]::Parse($DataObject.'Reason Code')
        $DataObject.Duration = [System.TimeSpan]::Parse($DataObject.Duration)
    }

    return $CcxData
}

function Get-FirstOfArray {
    param (
        [Parameter(ValueFromPipeline)]$InputObject
    )
        
    if (($InputObject -ne $null) -and ($InputObject.GetType().Name -eq 'Array')) {
        $InputObject[0]
    } else {
        $InputObject
    }
}
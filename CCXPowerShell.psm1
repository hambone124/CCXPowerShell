function Get-CcxData {
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
                
                # Return data object
                [PSCustomObject]@{
                    'Agent Name' = $FilteredToReasonCode.'Agent Name' | Get-FirstOfArray
                    'Agent ID' = $FilteredToReasonCode.'Agent ID' | Get-FirstOfArray
                    Extension = $FilteredToReasonCode.Extension | Get-FirstOfArray
                    Date = $Date
                    'Reason Code' = $ReasonCode
                    'Duration Total' = $DurationTotal
                }
            }
        }       
    }
}

function Import-CcxCsv {
    param (
        [Parameter(Mandatory)]$Path
    )
        
    # Get data from CSV file
    $CcxData = Import-Csv -Path $Path -ErrorAction Stop
    
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
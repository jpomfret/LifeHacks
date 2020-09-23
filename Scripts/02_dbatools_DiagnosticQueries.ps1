##############################################
#                                            #
# #2 - Glenn's Diagnostic Queries & dbatools #
#                                            #
##############################################

# Glenn's Resources
Start-Process https://glennsqlperformance.com/resources/

# dbatools commands for Diag queries
    # https://docs.dbatools.io/#Invoke-DbaDiagnosticQuery
    # https://docs.dbatools.io/#Export-DbaDiagnosticQuery
    # https://docs.dbatools.io/#New-DbaDiagnosticAdsNotebook
    # https://docs.dbatools.io/#Save-DbaDiagnosticQueryScript

# Use Selection Helper
Invoke-DbaDiagnosticQuery -SqlInstance mssql1 -UseSelectionHelper

<#
omputerName     : mssql1
InstanceName     : MSSQLSERVER
SqlInstance      : mssql1
Number           : 1
Name             : Version Info
Description      : SQL and OS Version information for current instance
DatabaseSpecific : False
Database         :
Notes            :
Result           : @{Server Name=mssql1; SQL Server and OS Version Info=Microsoft SQL Server 2017 (RTM-CU20) (KB4541283) - 14.0.3294.2 (X64)
                        Mar 13 2020 14:53:45
                        Copyright (C) 2017 Microsoft Corporation
                        Developer Edition (64-bit) on Linux (Ubuntu 16.04.6 LTS)}
#>

# Get Result
(Invoke-DbaDiagnosticQuery -SqlInstance mssql1 -QueryName 'TempDB Data Files').Result

<#
LogDate             ProcessInfo Text
-------             ----------- ----
15/09/2020 13:30:42 spid7s      The tempdb database has 1 data file(s).
#>

# One query across many servers
Invoke-DbaDiagnosticQuery -SqlInstance mssql1, mssql2 -QueryName 'Core Counts' | ForEach-Object -PipelineVariable Result -Process { $_ } | ForEach-Object {
    $psitem | Select-Object -Expand Result | Select-Object @{l='SqlInstance';e={$Result.SqlInstance}}, *
}

# Run all instance level queries, export to CSVs
Invoke-DbaDiagnosticQuery -SqlInstance mssql1 -InstanceOnly | Export-DbaDiagnosticQuery -Path .\Output\

# Add in the ImportExcel module
Invoke-DbaDiagnosticQuery -SqlInstance mssql1 -InstanceOnly | ForEach-Object {
    if($psitem.Result) {
        $excelSplat = @{
            Path            = ('.\Output\{0}.xlsx' -f $psitem.sqlinstance)
            WorksheetName   = $psitem.Name
            InputObject     = $psitem.Result
            TableName       = $psitem.Name.replace(' ','')
            AutoSize        = $true
        }
        Export-Excel @excelSplat
    }
}

# Database specific queries
Invoke-DbaDiagnosticQuery -SqlInstance mssql1 -Database AdventureWorks2017 -DatabaseSpecific | ForEach-Object {
    $excelSplat = @{
        Path            = ('.\Output\{0}.xlsx' -f $psitem.Database)
        WorksheetName   = $psitem.Name
        InputObject     = $psitem.Result
        TableName       = $psitem.Name.replace(' ','')
        AutoSize        = $true
    }
    Export-Excel @excelSplat
}

# Multiple server properties into Excel
Invoke-DbaDiagnosticQuery -SqlInstance mssql1, mssql2 -QueryName 'Configuration Values' | ForEach-Object -PipelineVariable Result -Process { $_ } | ForEach-Object {
    $excelSplat = @{
        Path            = '.\Output\ConfigurationValues.xlsx'
        WorksheetName   = $Result.SqlInstance
        InputObject     = $psitem.Result
        TableName       = ('config{0}' -f $Result.sqlinstance)
        AutoSize        = $true
    }
    Export-Excel @excelSplat
}

# clear up
Remove-Item .\Output\*
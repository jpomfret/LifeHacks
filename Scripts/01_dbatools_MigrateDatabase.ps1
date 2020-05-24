##########################################
#                                        #
#  01 - Migrate Databases with dbatools  #
#                                        #
##########################################

<# pre stream
- 00_setup.ps1
- create logins
- open ads and connect to mssql1
- change OBS to capture screen rather than vscode app!
#>

# 1. Check for processes
# 2. Copy logins
# 3. Copy database

# migrating application databases with dbatools
# https://dbatools.io/migrating-application-dbs/





## 1. Processes

    $processSplat = @{
        SqlInstance = "mssql1"
        Database    = "AdventureWorks2017","DatabaseAdmin"
    }
    Get-DbaProcess @processSplat |
        Select-Object Host, login, Program

    Get-DbaProcess @processSplat | Stop-DbaProcess

## 2. Logins

    $loginSplat = @{
        SqlInstance = 'mssql1'
        ExcludeSystemLogin = $true
        ExcludeFilter =  'NT AUTH*', 'BUI*', '##*'
        OutVariable = 'loginsToMigrate' # OutVariable to also capture this to use later
    }
    Get-DbaLogin @loginSplat |
        Select-Object SqlInstance, Name, LoginType

    ## Migrate login
    $migrateLoginSplat = @{
        Source      = 'mssql1'
        Destination = 'mssql2'
        Login       = $loginsToMigrate.Name
        Verbose     = $true
    }
    Copy-DbaLogin @migrateLoginSplat

## 2. Databases

    $datatbaseSplat = @{
        SqlInstance   = "mssql1"
        ExcludeSystem = $true
        OutVariable   = "dbs"        # OutVariable to also capture this to use later
    }
    Get-DbaDatabase @datatbaseSplat |
        Select-Object Name, Status, RecoveryModel, Owner, Compatibility |
        Format-Table

    ## Migrate the databases
    $migrateDbSplat = @{
        Source           = "mssql1"
        Destination      = 'mssql2'
        Database         = $dbs.name
        BackupRestore    = $true
        SharedPath       = '/sharedpath'
        SetSourceOffline = $true
        Verbose          = $true
    }
    Copy-DbaDatabase @migrateDbSplat

    ## upgrade compat level & check all is ok
    $compatSplat = @{
        SqlInstance = "mssql2"
    }
    Get-DbaDbCompatibility @compatSplat |
        Select-Object SqlInstance, Database, Compatibility

    $compatSplat.Add('Database', $dbs.Name)
    $compatSplat.Add('TargetCompatibility', '15')

    Set-DbaDbCompatibility @compatSplat

    ## Upgrade database - https://thomaslarock.com/2014/06/upgrading-to-sql-server-2014-a-dozen-things-to-check/
    # Updates compatibility level
    # runs CHECKDB with data_purity - make sure column values are in range, e.g. datetime
    # DBCC updateusage
    # sp_updatestats
    # sp_refreshview against all user views
    $upgradeSplat = @{
        SqlInstance = "mssql2"
        Database    = $dbs.Name
    }
    Invoke-DbaDbUpgrade @upgradeSplat
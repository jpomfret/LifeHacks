#Get-Process teams, slack -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue

#Start-Process azuredatastudio

Set-Location C:\github\LifeHacks

docker stop mssql1, mssql2
docker rm mssql1, mssql2

docker-compose -f ".\Scripts\Setup\Docker\docker-compose.yml" up -d --build

# set module path
$env:PSModulePath = "C:\Program Files\WindowsPowerShell\Modules"

$securePassword = ('Password1234!' | ConvertTo-SecureString -asPlainText -Force)
$credential = New-Object System.Management.Automation.PSCredential('sa', $securePassword)

$PSDefaultParameterValues = @{"*:SqlCredential"=$credential
                              "*:DestinationCredential"=$credential
                              "*:DestinationSqlCredential"=$credential
                              "*:SourceSqlCredential"=$credential}

Start-Sleep -Seconds 60

## Logins
(Import-Csv .\Scripts\Setup\users.csv).foreach{
    $server = Connect-DbaInstance -SqlInstance $psitem.Server
    New-DbaLogin -SqlInstance $server -Login $psitem.User -Password ($psitem.Password | ConvertTo-SecureString -asPlainText -Force)
    New-DbaDbUser -SqlInstance $server -Login $psitem.User -Database $psitem.Database
    Add-DbaDbRoleMember -SqlInstance $server -User $psitem.User -Database $psitem.Database -Role $psitem.Role.split(',') -Confirm:$false
}

Invoke-Pester .\Scripts\Setup\Tests\demo.tests.ps1

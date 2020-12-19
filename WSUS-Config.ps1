Write-Verbose "Get WSUS Server Object" -Verbose
 
$wsus = Get-WSUSServer
 
Write-Verbose "Connect to WSUS server configuration" -Verbose
 
$wsusConfig = $wsus.GetConfiguration()
 
Write-Verbose "Set to download updates from Microsoft Updates" -Verbose
 
Set-WsusServerSynchronization -SyncFromMU
 
Write-Verbose "Set Update Languages to English and save configuration settings" -Verbose
 
$wsusConfig.AllUpdateLanguagesEnabled = $false           
$wsusConfig.SetEnabledUpdateLanguages("en")           
$wsusConfig.Save()
 
Write-Verbose "Get WSUS Subscription and perform initial synchronization to get latest categories" -Verbose
 
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
 
While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}
 
Write-Verbose "Sync is done" -Verbose
 
Write-Verbose "Disable Products" -Verbose
 
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable
 
Write-Verbose "Enable Products" -Verbose
 
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows 10" } | Set-WsusProduct
 
Write-Verbose "Configure the Classifications" -Verbose
 
Get-WsusClassification | Where-Object {
    $_.Classification.Title -in (
    'Critical Updates',
    'Definition Updates',
    'Feature Packs',
    'Security Updates',
    'Service Packs',
    'Update Rollups',
    'Updates',
    'Upgrades')
} | Set-WsusClassification
 
Write-Verbose "Configure Synchronizations" -Verbose
 
$subscription.SynchronizeAutomatically=$true
 
Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose
 
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 5)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()
 
Write-Verbose "Kick Off Synchronization" -Verbose
 
$subscription.StartSynchronization()
 
Write-Verbose "Monitor Progress of Synchronisation" -Verbose
 
Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
 Write-Host "." -NoNewline
 Start-Sleep -Seconds 5
}
 


#Change server name and port number and $True if it is on SSL
 
$Computer = $env:COMPUTERNAME
[String]$updateServer1 = $Computer
[Boolean]$useSecureConnection = $False
[Int32]$portNumber = 8530
 
Write-Verbose "Load .NET assembly" -Verbose
 
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$count = 0
 
Write-Verbose "Connect to WSUS Server" -Verbose
 
$updateServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($updateServer1,$useSecureConnection,$portNumber)
 
Write-Verbose "Connected successfully" -Verbose
 
$updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$u=$updateServer.GetUpdates($updatescope )
 
foreach ($u1 in $u )
{
if ($u1.IsSuperseded -eq 'True')
{
 
$u1.Decline()
$count=$count + 1
}
}
 
Write-Verbose "Total Declined Updates : $count" -Verbose
 
trap
 
{
write-host "Error Occurred"
write-host "Exception Message: "
write-host $_.Exception.Message
write-host $_.Exception.StackTrace
exit
}
 
Write-Verbose "Configure Default Approval Rule" -Verbose
 
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$rule = $wsus.GetInstallApprovalRules() | Where {
    $_.Name -eq "Default Automatic Approval Rule"}
$class = $wsus.GetUpdateClassifications() | ? {$_.Title -In (
    'Critical Updates',
    'Definition Updates',
    'Feature Packs',
    'Security Updates',
    'Service Packs',
    'Update Rollups',
    'Updates',
    'Upgrades')}
$class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
$class_coll.AddRange($class)
$rule.SetUpdateClassifications($class_coll)
$rule.Enabled = $True
$rule.Save()
 
Write-Verbose "Run Default Approval Rule" -Verbose
$rule.ApplyRule()
 

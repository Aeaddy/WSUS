
 
$wsus = Get-WSUSServer
 
$wsusConfig = $wsus.GetConfiguration()
 
Set-WsusServerSynchronization -SyncFromMU
 
$wsusConfig.AllUpdateLanguagesEnabled = $false           
$wsusConfig.SetEnabledUpdateLanguages("en")           
$wsusConfig.Save()
 
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
 
While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}
 
 
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable
 
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows 10" } | Set-WsusProduct

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
 
$subscription.SynchronizeAutomatically=$true
 
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 5)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()
 
$subscription.StartSynchronization()
 
Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
 Write-Host "." -NoNewline
 Start-Sleep -Seconds 5
}
 

 
$Computer = $env:COMPUTERNAME
[String]$updateServer1 = $Computer
[Boolean]$useSecureConnection = $False
[Int32]$portNumber = 8530
 
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$count = 0
 
$updateServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($updateServer1,$useSecureConnection,$portNumber)
 
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
 
trap
 
{
write-host "Error Occurred"
write-host "Exception Message: "
write-host $_.Exception.Message
write-host $_.Exception.StackTrace
exit
}
 
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
 
$rule.ApplyRule()
 

Param(
  [Parameter(Mandatory=$True)]
   [string]$ResourceGroupName, 
	
   [Parameter(Mandatory=$True)]
   [string]$ResourceSuffix,

   [Parameter()]
   [string]$Region = "northeurope"
)

"Checking subscription"

$subscriptions = Get-AzSubscription
if ($subscriptions.Length -gt 1) {
    "Available subscriptions:"
    foreach ($sub in  $subscriptions) {
        $sub.Name
    }
    $context = Get-AzContext
    $subName = Read-Host -Prompt "Choose subscription [$($context.Subscription.Name)]"
    if ($subName -ne "") {
        Set-AzContext -SubscriptionName $subName
    }
}

"Making sure resource group exists"

if (!(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Region | Out-Null
}

"Deploying Azure resources"

$deployment = New-AzResourceGroupDeployment -TemplateFile .\arm.json -ResourceGroupName $ResourceGroupName -TemplateParameterObject @{
    suffix = $ResourceSuffix
    region = $Region
}

"Putting secret references into app settings"

$outputs = $deployment.Outputs

$webApp = $($outputs.funcNetName.Value)

$site = Get-AzWebApp -Name $webApp
$oldSettings = ($site.SiteConfig.AppSettings | ForEach-Object -Begin { $s = @{} } -Process { $s[$_.Name] = $_.Value } -End { $s })

$newSettings = @{
    blobStorageConnection = $outputs.blobStorageConnection.Value
    computerVisionApiKey = $outputs.computerVisionApiKey.Value
    cosmosDBAuthorizationKey = $outputs.cosmosDBAuthorizationKey.Value
    eventGridTopicKey = $outputs.eventGridTopicKey.Value
}

Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $webApp -AppSettings ($oldSettings + $newSettings) | Out-Null

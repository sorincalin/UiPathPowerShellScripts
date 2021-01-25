############# EDIT the following section #############
$TenantConfig = [PSCustomObject]@{
    'url'   = "****** TODO *******"
    'tenant' = "****** TODO *******"
    'username' = "****** TODO *******"
    'password' = "****** TODO *******"
    'tokenExpirationInMinutes' =  30
}

$LocalPackageFolder = "****** TODO *******" #local folder where packages will be downloaded, unpacked and analyzed

# You can Disable Debug logs by commenting the next line
$DebugPreference = 'Continue'

######################################################

Import-Module UiPath.PowerShell

########################################

function GetFilesFromNupkg
{
    Param([PSObject] $nupkgFilePath, [PSObject] $destinationFolder)
    
    $nupkgFile = Get-Item -Path $nupkgFilePath
    $zipFilePath = $nupkgFile.DirectoryName + "\" + $nupkgFile.BaseName + ".zip"

    Rename-Item $nupkgFilePath $zipFilePath

    Expand-Archive $zipFilePath $destinationFolder
    Get-ChildItem -path $destinationFolder -Exclude 'lib' | Remove-Item -Recurse -force
    Rename-Item "$destinationFolder\lib" "$destinationFolder\lib-temp-move"
    dir "$destinationFolder\lib-temp-move\net45" | mv -dest $destinationFolder
    Remove-Item "$destinationFolder\lib-temp-move\" -Recurse -force
    Rename-Item $zipFilePath $nupkgFilePath
}

function GetActivePackages
{
    Param([PSObject] $tenantConfig, [PSObject] $packageFolder)
    
    $downloadedPackageFolders = New-Object System.Collections.ArrayList

    $authResponse = Get-UiPathAuthToken -URL $tenantConfig.url -TenantName $tenantConfig.tenant -Username $tenantConfig.username -Password $tenantConfig.password -Session
    
    $packages = Get-UiPathPackage | Get-UiPathPackageVersion
    $activePackages = $packages | Where-Object {$_.IsActive}
    Write-Debug "Found packages: $($packages.Count) Active packages: $($activePackages.Count)"

    # For a large number of files to be uploaded, re-authentication is required periodically
    $authTime = Get-Date -Year 1970 #seeting this to ensure authentication at first iteration
    foreach($package in $activePackages)
    {
        # If we have less than 5 minutes before token expiration, perform an authentication
        if (((Get-Date) - $authTime).TotalMinutes -gt ($tenantConfig.tokenExpirationInMinutes - 5))
        {
            $authTime = Get-Date
            $authResponse = Get-UiPathAuthToken -URL $tenantConfig.url -TenantName $tenantConfig.tenant -Username $tenantConfig.username -Password $tenantConfig.password -Session
        }
        try
        {
            $endpoint = "$($tenantConfig.url)/odata/Processes/UiPath.Server.Configuration.OData.DownloadPackage(key='$($package.Key)')"
            
            $fileName = "$packageFolder\$($package.Id)_$($package.Version).nupkg"
            $extractionFolder = "$packageFolder\$($package.Id)_$($package.Version)"
            
            Write-Debug "Downloading $fileName and extracting to $extractionFolder"

            $response = Invoke-WebRequest -Uri $endpoint -Method GET -Headers @{"Authorization"="Bearer " + $authResponse.Token; "accept"= "image/file"} -OutFile $fileName
            GetFilesFromNupkg $fileName $extractionFolder
            $downloadedPackageFolders.Add($extractionFolder)
        }
        catch
        {
            Write-Error "ERROR downloading package <$packageName>: $_ at line $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}


####################### Execution Steps #######################

$downloadedPackages = GetActivePackages $TenantConfig $LocalPackageFolder
$projectFiles = (Get-ChildItem -Path $LocalPackageFolder -Force -Recurse -Filter "project.json")

###############################################################
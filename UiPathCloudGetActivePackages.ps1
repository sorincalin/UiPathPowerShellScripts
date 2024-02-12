############# Input Parameters #############
$TenantConfig = [PSObject]@{
    'AuthURL'= "https://account.uipath.com/oauth/token"
    'CloudUrl' = "https://cloud.uipath.com/"
    'Token' = $null # The Token will be set once you call the AuthenticateInCloud function
    
    # The following values can be retrieved from Privacy & security settings of your Cloud's organization
    # https://docs.uipath.com/orchestrator/automation-cloud/latest/api-guide/consuming-cloud-api#getting-the-api-access-information-from-the-automation-cloud-ui
    # URL shouldl look like this: https://cloud.uipath.com/[Your_Cloud_Org]/portal_/privacyAndSecuritySetting
    'UserKey' = "******EDIT*****"
    'OrgID'   = "******EDIT*****"
    'Name'    = "******EDIT*****"
    'ClientID'= "******EDIT*****"
}

$LocalDownloadFolder = "******EDIT*****"

# You can disable Debug and Information logs by commenting the next lines
$DebugPreference = 'Continue'
$InformationPreference = 'Continue'

######################################################

function AuthenticateInCloud
{
    Param([PSObject] $TenantConfig)
    
    $requestBody = @{"grant_type"="refresh_token"; "client_id"=$($TenantConfig.ClientID); "refresh_token"=$($TenantConfig.UserKey)}|ConvertTo-Json
    $responseObject = Invoke-WebRequest -Uri $TenantConfig.AuthURL -ContentType "application/json" -Method POST -Headers @{"Authorization"="Bearer"} -Body $requestBody | ConvertFrom-Json
    $TenantConfig.Token = $responseObject.access_token

    return $TenantConfig.Token
}

function GetCloudActivePackages
{
    Param([PSObject] $TenantConfig)

    $accessToken = $TenantConfig.Token;
    $CloudTenantURL = $TenantConfig.CloudUrl + $TenantConfig.OrgID + "/"+ $TenantConfig.Name + "/orchestrator_"

    ################ Get All Folders ################ 
    $url = $CloudTenantURL + "/odata/Folders?" + [System.Web.HttpUtility]::UrlEncode("`$filter=ParentId eq null&$count=true&$select=Id,FullyQualifiedName,FeedType")
    $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

    $folderFeeds = New-Object System.Collections.ArrayList
    foreach($folder in $responseObject.value | Where-Object FeedType -eq "FolderHierarchy")
    {
        $folderFeed = New-Object PSObject
        $folderFeed | Add-Member -NotePropertyName FolderFullyQualifiedName -NotePropertyValue $folder.FullyQualifiedName
        $folderFeed | Add-Member -NotePropertyName FolderId -NotePropertyValue $folder.Id
    
        $url = $CloudTenantURL + "/api/PackageFeeds/GetFolderFeed?folderId=" + $folder.Id
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

        $feedId = $responseObject
        $folderFeed | Add-Member -NotePropertyName FeedId -NotePropertyValue $feedId

        $url = $CloudTenantURL + "/odata/Processes?feedId=$($feedId)"
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

        $feedProcesses = New-Object System.Collections.ArrayList
        foreach($process in $responseObject.value)
        {
            $url = $CloudTenantURL + "/odata/Processes/UiPath.Server.Configuration.OData.GetProcessVersions" + "(processId='$($process.Id)')?feedId=$($feedId)"
            $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
            $activeVersions = $responseObject.Value | Where-Object IsActive
            if($activeVersions)
            {
                $feedProcesses.Add(@{'ProcessName'=$process.Id; 'ActiveVersions' = $activeVersions}) 1>$null
            }
        }

        if($feedProcesses.Count -gt 0)
        {
            $folderFeed | Add-Member -NotePropertyName ActiveProcesses -NotePropertyValue $feedProcesses
            $folderFeeds.Add($folderFeed) 1>$Null
        }
    }

    ################ Get All Personal Workspaces ################ 
    $url = $CloudTenantURL + "/odata/PersonalWorkspaces?" + [System.Web.HttpUtility]::UrlEncode("$count=true")
    $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

    $personalWorkspaceFeeds = New-Object System.Collections.ArrayList
    foreach($folder in $responseObject.value)
    {
        $folderFeed = New-Object PSObject
        $folderFeed | Add-Member -NotePropertyName Name -NotePropertyValue $folder.Name
        $folderFeed | Add-Member -NotePropertyName FolderId -NotePropertyValue $folder.Id
    
        $url = $CloudTenantURL + "/api/PackageFeeds/GetFolderFeed?folderId=" + $folder.Id
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

        $feedId = $responseObject
        $folderFeed | Add-Member -NotePropertyName FeedId -NotePropertyValue $feedId

        $url = $CloudTenantURL + "/odata/Processes?feedId=$($feedId)"
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json

        $feedProcesses = New-Object System.Collections.ArrayList
        foreach($process in $responseObject.value)
        {
            $url = $CloudTenantURL + "/odata/Processes/UiPath.Server.Configuration.OData.GetProcessVersions" + "(processId='$($process.Id)')?feedId=$($feedId)"
            $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
            $activeVersions = $responseObject.Value | Where-Object IsActive
            if($activeVersions)
            {
                $feedProcesses.Add(@{'ProcessName'=$process.Id; 'ActiveVersions' = $activeVersions}) 1>$null
            }
        }

        if($feedProcesses.Count -gt 0)
        {
            $folderFeed | Add-Member -NotePropertyName ActiveProcesses -NotePropertyValue $feedProcesses
            $personalWorkspaceFeeds.Add($folderFeed) 1>$Null
        }
    }

    ################ Get All Tenant Processes ################ 
    $tenantProcesses = New-Object System.Collections.ArrayList
    $url = $CloudTenantURL + "/odata/Processes"
    $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
    foreach($process in $responseObject.value)
    {
        $url = $CloudTenantURL + "/odata/Processes/UiPath.Server.Configuration.OData.GetProcessVersions" + "(processId='$($process.Id)')"
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
        $activeVersions = $responseObject.Value | Where-Object IsActive
        if($activeVersions)
        {
            $tenantProcesses.Add(@{'ProcessName'=$process.Id; 'ActiveVersions' = $activeVersions}) 1>$null
        }
    }

    ################ Get All Tenant Libraries ################ 
    $tenantLibraries = New-Object System.Collections.ArrayList
    $url = $CloudTenantURL + "/odata/Libraries"
    $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
    foreach($library in $responseObject.value)
    {
        $url = $CloudTenantURL + "/odata/Libraries/UiPath.Server.Configuration.OData.GetVersions" + "(packageId='$($library.Id)')"
        $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $accessToken}| ConvertFrom-Json
        if($responseObject.value.Count -gt 0)
        {
            $tenantLibraries.Add(@{'ProcessName'=$library.Id; 'Versions' = $responseObject.Value}) 1>$null
        }
    }

    $allPackages = @{
        'TenantProcesses'= $tenantProcesses
        'TenantLibraries' = $tenantLibraries
        'FolderFeedPackages' = $folderFeeds
        'PersonalWorkspacesPackages' = $personalWorkspaceFeeds
    }

    return $allPackages
}

function IterateThroughAllPackages
{
    Param([PSObject] $TenantConfig, [PSObject] $AllPackages, [String] $DestinationFolder)

    $TenantProcessesFolder = $DestinationFolder + "\TenantProcesses"
    foreach($tenantProcess in $AllPackages.TenantProcesses)
    {
        $downloadPath = $TenantProcessesFolder + "\" + $tenantProcess.ActiveVersions[0].ID
        foreach($packageVersion in $tenantProcess.ActiveVersions)
        {
            ProcessOrchestratorPackage $TenantConfig $downloadPath $packageVersion
        }
    }

    $TenantLibrariesFolder = $DestinationFolder + "\TenantLibraries"
    foreach($tenantLibrary in $AllPackages.TenantLibraries)
    {
        $downloadPath = $TenantLibrariesFolder + "\" + $tenantLibrary.Versions[0].ID
        foreach($packageVersion in $tenantLibrary.Versions)
        {
            ProcessOrchestratorPackage $TenantConfig $downloadPath $packageVersion
        }
    }

    $FolderFeedsFolder = $DestinationFolder + "\FolderFeeds"
    foreach($folderFeed in $AllPackages.FolderFeedPackages)
    {
        $FeedFolder = $FolderFeedsFolder + "\" + $folderFeed.FolderFullyQualifiedName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        foreach($process in $folderFeed.ActiveProcesses)
        {
            $downloadPath = $FeedFolder + "\" + $process.ActiveVersions[0].ID
            foreach($packageVersion in $process.ActiveVersions)
            {
                ProcessOrchestratorPackage $TenantConfig $downloadPath $packageVersion $folderFeed.FeedId
            }
        }
    }

    $PersonalWorkspacesFolder = $DestinationFolder + "\PersonalWorkspaces"
    foreach($personalWorkspace in $AllPackages.PersonalWorkspacesPackages)
    {
        $folder = $PersonalWorkspacesFolder + "\" + $personalWorkspace.Name.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        foreach($process in $personalWorkspace.ActiveProcesses)
        {
            $downloadPath = $folder + "\" + $process.ActiveVersions[0].ID
            foreach($packageVersion in $process.ActiveVersions)
            {
                ProcessOrchestratorPackage $TenantConfig $downloadPath $packageVersion $personalWorkspace.FeedId
            }
        }
    }
}


function ProcessOrchestratorPackage
{
    Param([PSObject] $TenantConfig, [String] $DownloadFolder, [PSObject] $Package, [String] $FeedId)
    
    $filename = "$DownloadFolder\$($Package.Id)_$($Package.Version).nupkg"
    try
    {
        if (-not (Test-Path $DownloadFolder))
        {
             New-Item -ItemType "directory" -Path $DownloadFolder 1>$null
        }
        if (-not (Test-Path $filename))
        {
            Write-Information "Downloading package $($filename)"
            DownloadPackage $TenantConfig $filename $Package $FeedId
        }
        else
        {
            Write-Warning "Skipping downloading package $($filename): already exists"
        }
        
        $extractionFolder = "$DownloadFolder\$($Package.Id)_$($Package.Version)"
        if (-not (Test-Path $extractionFolder))
        {
            Write-Information "Extracting package $($filename)"
            GetFilesFromNupkg $FileName $extractionFolder
        }
        else
        {
            Write-Warning "Skipping extracting package $($filename): already exists"
        }
    }
    catch
    {
        Write-Error "ERROR processing package <$($filename)>: $_ at line $($_.InvocationInfo.ScriptLineNumber)"
    }
}
function DownloadPackage
{
    Param([PSObject] $TenantConfig, [String] $Filename, [PSObject] $Package, [String] $FeedId)

    $CloudTenantURL = $TenantConfig.CloudUrl + $TenantConfig.OrgID + "/"+ $TenantConfig.Name + "/orchestrator_"
    $url = $CloudTenantURL + "/odata/Processes/UiPath.Server.Configuration.OData.DownloadPackage(key='$([System.Web.HttpUtility]::UrlEncode($Package.Key))')"
    if ($FeedId)
    {
        $url = $url + "?feedId=$($FeedId)"
    }
    $responseObject = Invoke-WebRequest -Uri $url -ContentType "application/json" -Method GET -Headers @{"Authorization"="Bearer " + $TenantConfig.Token; "accept"= "application/octet-stream"} -OutFile $fileName
}

function GetFilesFromNupkg
{
    Param([PSObject] $nupkgFilePath, [PSObject] $destinationFolder)
    
    $nupkgFile = Get-Item -Path $nupkgFilePath
    $zipFilePath = $nupkgFile.DirectoryName + "\" + $nupkgFile.BaseName + ".zip"

    Rename-Item $nupkgFilePath $zipFilePath -Force
    Expand-Archive $zipFilePath $destinationFolder -Force
    Rename-Item $zipFilePath $nupkgFilePath -Force
}

#################### Execution Steps ##########################

$token = AuthenticateInCloud $TenantConfig
$myPackages = GetCloudActivePackages $TenantConfig

#Sample output to Json
#$myPackages | ConvertTo-Json -Depth 5

IterateThroughAllPackages $TenantConfig $myPackages $LocalDownloadFolder

#Sample output to Json
#$myPackages | ConvertTo-Json -Depth 5
###############################################################
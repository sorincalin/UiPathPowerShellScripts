############ EDIT THIS SECTION ##############
$url = "****** TODO ********"
$tenant = "****** TODO ********"
$folder = "****** TODO ********"
$username = "****** TODO ********"
$password = "****** TODO ********"

$repositoryFolder = "****** TODO ********"
$newPackageFolder = "****** TODO ********"

#############################################

$regex = '<WriteLine.*DisplayName="(?<DisplayName>.*?)".*Text="(?<Text>.*?)".*\/>'

$affectedProjectFolders = New-Object System.Collections.ArrayList
$affectedFiles = New-Object System.Collections.ArrayList

$xamlFiles = (Get-ChildItem -Path $repositoryFolder -Force -Recurse -Filter "*.xaml")
foreach($file in $xamlFiles)
{
    $originalFileContent = Get-Content $file.FullName -Encoding UTF8 -Raw
    if ($originalFileContent -Match "<WriteLine")
    {
        $newFileContent = $originalFileContent -replace $regex, '<ui:LogMessage DisplayName="Log Message - ${DisplayName}" sap:VirtualizedContainerService.HintSize="334,91" sap2010:WorkflowViewState.IdRef="LogMessage_2" Level="Trace" Message="[&quot;${Text}&quot;]" />' 
        [IO.File]::WriteAllText($file.FullName, $newFileContent)
        Write-Host "Replaced WriteLine in file: $($file.FullName)"
        $affectedFiles.Add($file) 1>$null
        
        $currentFolder = $file.Directory
        do
        {
            if (Test-Path ($currentFolder.FullName + "\project.json"))
            {
                $affectedProjectFolders.Add($currentFolder) 1>$null
                break;
            }
            $currentFolder = $currentFolder.Parent
        }while($repositoryFolder -ne $currentFolder.FullName)
    }
}

$affectedProjectFolders = $affectedProjectFolders | Get-Unique

###############################################################

foreach($projectFolder in $affectedProjectFolders.FullName)
{
    $projectJson = Get-Content "$projectFolder\project.json" | ConvertFrom-Json
    Write-Host "Updating version of project: $($projectJson.name).$($projectJson.projectVersion)"
    $uiRobotExe = '"C:\Program Files (x86)\UiPath\Studio\UiRobot.exe"'
    $command = "$uiRobotExe pack $projectFolder\project.json --output $newPackageFolder"
    iex "& $command" 1>$null
}


###############################################################


Import-Module UiPath.PowerShell
Get-UiPathAuthToken -URL $url -TenantName $tenant -Username $username -Password $password -Session -OrganizationUnit $folder 1>$null

$nugetsToUpload = (Get-ChildItem -Path $newPackageFolder -Force -Recurse -Filter "*.nupkg").FullName
foreach($packageFilePath in $nugetsToUpload)
{
    Write-Host "Uploading package to Orchestrator: $packageFilePath"
    Add-UiPathPackage -PackageFile $packageFilepath
}

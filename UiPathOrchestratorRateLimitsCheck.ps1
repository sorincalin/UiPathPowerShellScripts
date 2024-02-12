############# Input Parameters #############

$LocalRepositoryFolder = "*******EDIT*******"

# You can disable Debug and Information logs by commenting the next lines
$DebugPreference = 'Continue'
$InformationPreference = 'Continue'

#################################################

function GetAffectedProjectDetails
{
    Param([System.String] $ProjectFolder, [System.String] $FileFilter, [System.Collections.ArrayList] $Markers)
    
    $affectedProject = $Null
    $affectedFiles = New-Object System.Collections.ArrayList

    $xamlFiles = (Get-ChildItem -LiteralPath $ProjectFolder -Force -Recurse -Filter $FileFilter)
    
    foreach($file in $xamlFiles)
    {
        $foundMarkers = New-Object System.Collections.ArrayList

        $originalFileContent = Get-Content $file.FullName -Encoding UTF8 -Raw
        foreach($marker in $Markers)
        {
            if ($originalFileContent -Match $marker)
            {
                Write-Warning "Found marker $($marker) in file: $($file.FullName)"
                $foundMarkers.Add($marker) 1>$Null        
            }
        }

        if ($foundMarkers.Count -ne 0)
        {
            $affectedFile = New-Object PSObject
            $affectedFile | Add-Member -NotePropertyName Path -NotePropertyValue $file.FullName
            $affectedFile | Add-Member -NotePropertyName Markers -NotePropertyValue $foundMarkers
            $affectedFiles.Add($affectedFile) 1>$Null
        }
    }

    if ($affectedFiles.Count -ne 0)
    {
        $affectedProject = New-Object PSObject
        $affectedProject | Add-Member -NotePropertyName Path -NotePropertyValue $ProjectFolder
        $affectedProject | Add-Member -NotePropertyName AffectedFiles -NotePropertyValue $affectedFiles
    }

    return $affectedProject
}


#################### Execution Steps ##########################

$projectFiles = (Get-ChildItem -Path $LocalRepositoryFolder -Force -Recurse -Filter "project.json")
$projectFolders = $projectFiles.FullName | Split-Path -Parent
$Markers = @("<ui:GetJobs","<ui:GetQueueItems","GET/odata/Jobs","GET/odata/QueueItems/")

$affectedProjectFolders = New-Object System.Collections.ArrayList

foreach ($folder in $projectFolders)
{
    $affectedProject = GetAffectedProjectDetails $folder "*.xaml" $Markers 
    if ($affectedProject -ne $Null)
    {
        $affectedProjectFolders.Add($affectedProject) 1>$Null
    }
}

#Sample Json output
#$affectedProjectFolders | ConvertTo-Json -Depth 5 

#######################################################
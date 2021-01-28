param
(
	[string]$projectFile = $(throw "projectFile is required."),
    [string]$outFile = $(throw "outFile is required.")
)

if (-not [System.IO.File]::Exists($projectFile))
{
    throw "Project File doesn't exist"
}

# Default Path for MSI installation
$workflowAnalyzerExe = "c:\Program Files (x86)\UiPath\Studio\UiPath.Studio.CommandLine.exe"

$output = & $workflowAnalyzerExe analyze -p $projectFile 2>$null

# extract just the json output
$jsonOutput = ConvertFrom-Json ([regex]::match($output, "(?<=\#json)(.|\n)*(?=\#json)").Groups[0].Value)

$rules = New-Object System.Collections.ArrayList

$uniqueRuleIds = ($jsonOutput | Get-Member | Where-Object {$_.Name.Length -ge 37}).Name.Substring(0,36) | Unique
ForEach ($ruleId in $uniqueRuleIds)
{
    $ruleObject = New-Object PSObject
    $ruleProperties = ($jsonOutput | Get-Member | Where-Object {$_.Name -and ($_.Name.Length -gt 36) -and ($_.Name.Substring(0,36) -eq $ruleId)}).Name.Substring(37)
    $ruleObject | Add-Member -NotePropertyName Id -NotePropertyValue $ruleId
    $ruleProperties | % {$ruleObject | Add-Member -NotePropertyName $_ -NotePropertyValue $jsonOutput."$ruleId-$_"}
    $rules.Add($ruleObject) >$null
}

$rules | ConvertTo-Json | Out-File $outFile

if ($rules.ErrorSeverity.Contains("Error"))
{
    $errorSummary = ($rules | Where-Object {$_.ErrorSeverity -eq "Error"} | Select ErrorCode, Description, FilePath) | ConvertTo-Json    
    $exceptionMessage = "1 or more Errors were found in the project. Check $outFile for more details. Summary: " + $errorSummary
    $Host.UI.WriteErrorLine($exceptionMessage)
    Exit 1
}

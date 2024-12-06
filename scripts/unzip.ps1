######################################################################################
# Unzip all given files and organize them into either "Metadata" or "Promotions" folder
# Ollie Le
# v1.0
######################################################################################

Param(
    [string]$SourcePath
)

# Get timestamp (to milliseconds) to create unique folder name
$TimeStamp = Get-Date -Format "ddMMyyyyHHmmssfff"
$DestinationPath = "\\nasfile10\grpdata\Ollie\PromotionExportAutomation\" + $TimeStamp

# Unzip all files
Get-ChildItem -Path $SourcePath -Recurse | ForEach-Object {
    Expand-Archive -LiteralPath $_.FullName -DestinationPath $DestinationPath

    Write-Host $TimeStamp
    Write-Host $_.Name
}

# Create 2 folder for LT files and PromotionExport files
$DestinationLT = $DestinationPath + "\Metadata"
$DestinationPromotionExport = $DestinationPath + "\Promotions"

New-Item -ItemType Directory -Force -Path $DestinationLT, $DestinationPromotionExport

# Organize each file according to their type (either metadata (LT) or PromotionExport)
Get-ChildItem -Path $DestinationPath -Recurse -File | ForEach-Object {
    $File = $_

    if ($File.Name -match "PromotionExport") {
        Move-Item -Path $File.FullName -Destination $DestinationPromotionExport
    } elseif ($File.Name -match "LT") {
        Move-Item -Path $File.FullName -Destination $DestinationLT
    } else {
        Write-Host "Folder contains file that is neither a metadata or PromotionExport file!!"
    }
}

# Output the $DestinationPath variable to feed into the next script
[Environment]::SetEnvironmentVariable("DestinationPath", $DestinationPath, "Process")
Write-Host "Extraction completed. Destination Path: $DestinationPath"
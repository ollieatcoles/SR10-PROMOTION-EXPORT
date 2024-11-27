######################################################################################
# Processing the LT and Promotion file in order, and output the logs if there are any.
# Ollie Le
# v1.0
######################################################################################

Param(
    [string]$SourcePath
)

$ProcessFolder = "R:\LocalApp\RESB\Coles\Services\LMS"
$CheckErrorFolder = "R:\LocalApp\RESB\Coles\Logs\ERR"
$CheckLogFolder = "R:\LocalApp\RESB\Coles\Logs\LOG"

$TransitinFolder = "R:\LocalApp\RESB\Coles\Services\LMS\mqsitransitin"
# $ArchiveFolder = "R:\LocalApp\RESB\Coles\Services\LMS\mqsiarchive"

Function ProcessFiles {
    Param (
        [string] $FileType
    )

    $Path = $SourcePath + "\" + $FileType
    $StartTime = Get-Date

    # Copy content of files onto LMS folder, and also print out the process status
    Write-Host "Working on $FileType files..."
    Copy-Item -Path $Path -Destination $ProcessFolder -Recurse -Force

    # Keep looping until all files have been processed
    while ($true) {
        $LmsDone = ((Get-ChildItem -Path $ProcessFolder -File -ErrorAction SilentlyContinue).Count -eq 4)
        $TransitinDone = ((Get-ChildItem -Path $TransitinFolder -File -ErrorAction SilentlyContinue).Count -eq 1)

        # All files will have been processed if they disappear from LMS + transitin folder
        If ($LmsDone -and $TransitinDone) {
            Write-Host "All $FileType files have been processed"
            Write-Host "Checking the log..."
            break
        }

        # Printing processing status every minute
        $Interval = (Get-Date) - $StartTime
        If ($Interval.TotalSeconds -ge 60) {
            Write-Host "Still on it..."
            $StartTime = Get-Date
        }

        # Timeout to avoid high CPU usage 
        Start-Sleep -Milliseconds 100
    }

    $HasError = ErrorCheck -FileType $FileType -StartTime $StartTime
    $HasLog = LogCheck -FileType $FileType -StartTime $StartTime

    return $HasError, $HasLog
}

Function ErrorCheck {
    Param(
        [string] $FileType,
        [string] $StartTime
    )
    Write-Host "Checking ERR logs"
    Write-Host "-----------------"
    # Retrieve the total time for processing
    $CurrentTime = Get-Date
    $TotalTime = $CurrentTime - $StartTime

    # Retrieve the expected name of the ERR log
    $CheckErrorFolder += "\LMS.$($FileType).$(Get-Date -Format "yyyyMMdd")"
    
    If (Test-Path $CheckErrorFolder) {
        # Retrieve the latest ERR log modified time
        $ErrorLastModified = (Get-Item -Path $CheckErrorFolder).LastWriteTime
        If ($CurrentTime.AddMinutes($TotalTime) -ge $ErrorLastModified) {
            # Case 1: there is error log today but is irrelevant to us
            Write-Host "No error detected"
            Write-Host "-----------------"
            return 0
        } else {
            # Case 2: there is error log today and is indeed our log
            Write-Host "Error detected"
            Write-Host "-----------------"
            return 1
        }
    } else {
        # Case 3: if no error log was output
        Write-Host "No error detected"
        Write-Host "-----------------"
        return 0
    }
}

Function LogCheck {
    Param(
        [string] $FileType,
        [string] $StartTime
    )
    Write-Host "Checking LOG logs"
    Write-Host "-----------------"
    # Retrieve the total time for processing
    $CurrentTime = Get-Date
    $TotalTime = $CurrentTime - $StartTime

    # Retrieve the expected name of the ERR log
    $CheckLogFolder += "\LMS.$($FileType).$(Get-Date -Format "yyyyMMdd")"
    
    If (Test-Path $CheckLogFolder) {
        # Retrieve the latest ERR log modified time
        $LogLastModified = (Get-Item -Path $CheckLogFolder).LastWriteTime
        If ($CurrentTime.AddMinutes($TotalTime) -ge $LogLastModified) {
            # Case 1: There is logs in the LOG folder, which is good
            Write-Host "Log is found, which is good"
            Write-Host "-----------------"
            return 1
        } else {
            # Case 2: There exists logs in the LOG folder but is irrelevant to us
            Write-Host "No logs found"
            Write-Host "-----------------"
            return 0
        }
    } else {
        # Case 3: There is no logs in the LOG folder, which is weird
        Write-Host "No logs found"
        Write-Host "-----------------"
        return 0
    }
}

#---------------------
#  THE MAIN FUNCTION
#---------------------

<#
.DESCRIPTION
    The main function that calls ProcessFiles of each of the LT and Promotion file type.

.NOTES
    Output meaning:
        0: process is completed with no error.
        99: there is an error during the file processing stage, 
            and user would like to stop the pipeline.
        100: there is an error during the file processing stage, 
            and user would like to continue on.
#>
Function Main {

    # Processing the LT files
    $Result = ProcessFiles -FileType "LT"
    $HasError = $Result[0]
    $HasLog = $Result[1]

    # Metadata: if no error found and expected log file is produced
    If (!($HasError) -and $HasLog) {

        # Processing the promotion files
        $Result = ProcessFiles -FileType "Promotion Export"
        $HasError = $Result[0]
        $HasLog = $Result[1]

        # PromotionExport: if no error found and expected log file is produced
        If (!($HasError) -and $HasLog) {
            Write-Host "Promotion export process has been successfully completed!"
            Write-Host "Remember to check 'Promotions' on OfficeClient!"
            return 0
        } else {
            # PromotionExport: if error found, print message and stop the pipeline
            Write-Host "There has been an error with promotion files!"
            return 100
        }
    } else {
        # Metadata: if error found, ask user if they want to continue on
        $Continue = (Read-Host "There has been an error with the metadata file. Would you like to continue? (Y or N)").ToUpper()

        If ($Continue -match "Y") {

            # Processing the promotion files
            $Result = ProcessFiles -FileType "Promotion Export"
            $HasError = $Result[0]
            $HasLog = $Result[1]

            # PromotionExport: if no error found and expected log file is produced
            If (!($HasError) -and $HasLog) {
                Write-Host "Promotion export process has been successfully completed!"
                Write-Host "Remember to check 'Promotions' on OfficeClient!"
                return 0
            } else {
                Write-Host "There has been an error with promotion files!"
                return 100
            }
        } else {
            Write-Host "User has stopped the process."
            return 99
        }
    }
}

#########################################
######   FUNCTIONS START HERE     #######
#########################################

Main
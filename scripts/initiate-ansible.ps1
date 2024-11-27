######################################################################################
# Kick-starting the Ansible playbook
# Ollie Le
# v1.0
######################################################################################

Param(
    [string]$DestinationPath,
    [string]$Environment,
    [string]$Mware,
    [string]$AnsibleUser,
    [string]$AnsiblePass,
    [string]$TemplateID
)

Write-Host "-Environment: " $Environment
Write-Host "-Mware: " $Mware

# ????????????????????????????????????????
$HeaderAuth = @{ Authorization = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($AnsibleUser):$($AnsiblePass)")) }
$VenafiPath = "\VED\Policy\Non-Production\Applications\Store Customer Platforms"
$Body = $null
$GroupList = @{}

Function DeleteGroups {
    ForEach ($Group in $MyObjHostList) {
        $GroupToDelete = $Group.group
        Write-Host "Group to delete: " $GroupToDelete
        $FindGroupUrl = "https://aap.cmltd.net.au/api/v2/groups/?search=$($GroupToDelete)"

        try {
            $FindGroup = Invoke-WebRequest -Uri $FindGroupUrl -Method Get -Headers $HeaderAuth -UseBasicParsing -ErrorAction Ignore -Noproxy
            $Response - $FindGroup.Content | ConvertFrom-Json
            $GroupID = $Response.results[0].id

            If ($Response.count -eq 0) {
                Write-Host "No group $GroupToDelete found."
            } else {
                Write-Host "Found and deleting $GroupToDelete"
                $DeleteGroupUrl = "https://aap.cmltd.net.au/api/v2/groups/$GroupID/" 
                $DeleteGroup = Invoke-WebRequest -Uri $DeleteGroupUrl -Method Delete -Headers $HeaderAuth -UseBasicParsing -ErrorAction Ignore -Noproxy
            }
        } catch {$_}
    }
}

Function CreateGroups {
    ForEach ($Group in $MyObjHostList) {
        $GroupToCreate - $Group.group
        Write-Host "Group to create: " $GroupToCreate
        $FindGroupUrl = "https://aap.cmltd.net.au/api/v2/groups/?search=$($GroupToCreate)"
        $GroupCheck = Invoke-WebRequest -Uri $FindGroupUrl -Method Get -ContentType 'application/json' -Headers $HeaderAuth -UseBasicParsing -ErrorAction Ignore -Noproxy | ConvertFrom-Json

        if ($GroupCheck.count -eq 0) {
            $PostParams = @{
                inventory = 185
                name = $GroupToCreate
                variables = @{
                    ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o userknownhostsfile=/dev/null"
                    enabled = $true
                } | ConvertTo-Json -Compress
            }

            try {
                $CreateGroup = Invoke-WebRequest -Uri $FindGroupUrl -Method Post -ContentType 'application/json' -Body ($PostParams | ConvertTo-Json) -Headers $HeaderAuth -UseBasicParsing -ErrorAction Ignore -Noproxy
                $Response = $CreateGroup.Content | ConvertFrom-Json
                $GroupID = $Response.$GroupID

                Write-Host "Created group $GroupToCreate with Group ID: " $GroupID
                $GroupList.Add($GroupToCreate, $GroupID)
            } catch {$_}
        }
    }

    Write-Host "Group list keys: " $GroupList.Keys
    Write-Host "Group list values: " $GroupList.Values

    return $GroupList
}

Function CreateHosts {
    ForEach ($MyHost in $MyObjHostList) {
        ForEach ($Group in $GroupList.Keys) {
            If ($MyHost.group -eq $Group) {
                Write-Host "Hostlist host: " $MyHost.host " My grouplist: " $Group " Group ID " $($GroupList.$Group)

                $GroupID = $($GroupList.$Group)
                $HostName = $MyHost.host
                $HostGroupUrl = "https://aap.cmltd.net.au/api/v2/groups/$GroupID/hosts/"

                $PostParams = @{
                    inventory = 185
                    name = $HostName
                    variables = @{
                        ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o userknownhostsfile=/dev/null"
                        enabled = $true
                        resb_server = (($resb).split("."))[0]
                        destination_path = $DestinationPath
                    } | ConvertTo-Json -Compress
                }

                try {
                    $CreateHostsInGroup = Invoke-WebRequest -Uri $HostGroupUrl -Method Post -Body ($PostParams | ConvertTo-Json) -ContentType 'application/json' -Headers $HeaderAuth -UseBasicParsing -ErrorAction Ignore -Noproxy
                } catch {$_}
            }
        }
    }
}

Function TriggerAnsible {
    $Url = "https://aap.cmltd.net.au/api/v2/job_templates/$templateId/launch/" 
    
    try {
        Invoke-WebRequest -Uri $Url -Method Post -ContentType 'application/json' -Headers $HeaderAuth -UseBasicParsing -Noproxy
    } catch {$_}
}

#########################################
#######   FUNCTIONS START HERE?   #######
#########################################

If ($Mware -match "") {
    $MwareArray = $($Mware.split(" "))

    ForEach ($VM in $MwareArray) {
        If (($VM -match "RSB") -or ($VM -match "RESB")) {
            $RESB = $VM
        }
    }
} else {$RESB = $Mware}

# Do a quick GetServerStatusInfo
$Online = Test-Connection -Cn $RESB -BufferSize 16  -Count 4 -TimeToLive 10 -ea 0 -quiet

$RESB += ".retail.ad.cmltd.net.au"
$MyObj = "" | Select Host, Group
$MyObj.host = $RESB
$MyObj.group = "SR10_PROMOTION_EXPORT_RESB"
$MyObjHostList += $MyObj

If ($Online) {
    DeleteGroups
    CreateGroups
    CreateHosts
    TriggerAnsible
}
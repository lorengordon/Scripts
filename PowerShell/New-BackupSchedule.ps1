[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false,Position=0,ValueFromRemainingArguments=$true)] 
    $RemainingArgs
    ,
	[Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [ValidateSet("SqlServer","ExchangeServer","ActiveDirectory")]
    [string[]] $RequiredVssWriters
    ,
	[Parameter(Mandatory=$true,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [ValidateSet("EbsSnapshot","S3Bucket")]
    [string] $BackupType
    ,
	[Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [switch] $QuiesceFileSystem
#    ,
#	[Parameter(Mandatory=$true,Position=0,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)] 
#   [ValidateSet("value1","value2","etc")]
#   [string] $ParamName
)
#Parameter Descriptions
#$RemainingArgs       #Parameter that catches any undefined parameters passed to the script.
                      #Used by the bootstrapping framework to pass those parameters through to other scripts. 
                      #This way, we don't need to know in advance all the parameter names for downstream scripts.

#$ParamName           #ParamDescription...

#System variables
$SystemRoot = $env:SystemRoot
$SystemDrive = $env:SystemDrive
$ComputerName = $env:ComputerName
$ScriptName = $MyInvocation.mycommand.name
$DateTime = $(get-date -format "yyyyMMdd_HHmm_ss")
$WorkingDir = "${SystemDrive}\Backup-WorkingFiles" #Location on the system to save backup metadata files
$LogDir = "${WorkingDir}\Logs" #Location on the system to save log files.
$BackupName = "${ComputerName}_${DateTime}_"
$DshScriptFile = "${WorkingDir}\${BackupName}.dsh"
$ExecScriptFile = ""
$VssMetadataFile = "${WorkingDir}\${BackupName}.cab"

$RemainingArgsHash = $RemainingArgs | ForEach-Object -Begin { $index = 0; $hash = @{} } -Process { if ($_ -match "^-.*:$") { $hash[($_.trim("-",":"))] = $RemainingArgs[$index+1] }; $index++ } -End { Write-Output $hash }
$ScriptStart = "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
$ScriptEnd = "--------------------------------------------------------------------------------"
###

#User variables

###

function log {
	[CmdLetBinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeLine=$true,ValueFromPipeLineByPropertyName=$true)] 
        [string[]] $LogMessage
	)
	PROCESS {
		#Writes the input $LogMessage to the output for capture by the bootstrap script.
		Write-Output "${Scriptname}: $LogMessage"
	}
}

function CreateDshScript {
	[CmdLetBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [Microsoft.Management.Infrastructure.CimInstance[]] $Volumes
        ,
		[Parameter(Mandatory=$true)]
        [string] $VssMetaDataFile
        ,
		[Parameter(Mandatory=$false)]
        [string] $ExecScript
        ,
		[Parameter(Mandatory=$false)]
        [string[]] $RequiredVssWriters
        ,
		[Parameter(Mandatory=$false)]
        [switch] $CleanupVssSnapshots
	)
    BEGIN {
        #Create a lookup table of the supported VSS Writers and their VSS Writer ID
        $VssWriters = @(
                      @{
                            WriterName = "SqlServer"
                            WriterID   = "{a65faa63-5ea8-4ebc-9dbd-a0c4db26912a}"
                       }
                      @{
                            WriterName = "ExchangeServer"
                            WriterID   = "{76fe1ac4-15f7-4bcd-987e-8e1acb462fb7}"
                       }
                      @{
                            WriterName = "ActiveDirectory"
                            WriterID   = "{B2014C9E-8711-4C5C-A5A9-3CF384484757}"
                       }
                   )
    }
    END 
    {
        # Initialize internal variables
        $NoWriters = ""
        $VssWriterStrings = @()
        $VolumeStrings = @()
        $ExecStrings = @()
        $DeleteShadows = @()
        
        #Check for QuiesceFileSystem switch 
        if (-not $QuiesceFileSystem) {
            $NoWriters = "NOWRITERS"
        }
        
        #Construct Dsh strings for required VSS writers 
        if ($RequiredVssWriters) { 
            $VssWriters | where { $_["WriterName"] -in ${RequiredVssWriters} } | foreach { $VssWriterStrings += "WRITER VERIFY $($_["WriterID"])" } 
        }
        
        #Construct Dsh strings for volumes to snapshot
        $Volumes | foreach { $VolumesStrings += "ADD VOLUME $($_.path)" }

        #Construct Dsh strings for the script to execute
        if ( $ExecScript ) { 
            $ExecStrings += "EXEC ${ExecScript}" 
        }

        #Construct Dsh strings to cleanup VSS snapshots
        if ( $CleanupVssSnapshots ) {
            $DeleteShadows = "DELETE SHADOWS ALL"
        }

        $DshScript = @()
        $DshScript += "RESET"
        $DshScript += "SET CONTEXT PERSISTENT $NoWriters"
        $DshScript += $VssWriterStrings
        $DshScript += "SET CONTEXT PERSISTENT"
        $DshScript += "SET METADATA ${VssMetaDataFile}"
        $DshScript += "SET VERBOSE ON"
        $DshScript += "BEGIN BACKUP"
        $DshScript += $VolumesStrings
        $DshScript += "CREATE"
        $DshScript += $ExecStrings
        $DshScript += "END BACKUP"
        $DshScript += $DeleteShadows
        
        return $DshScript
    }
}

#Make sure the working directories exist
New-Item -Path $WorkingDir -ItemType "directory" -Force 1>$null
log "Created backup working directory -- ${WorkingDir}"
New-Item -Path $LogDir -ItemType "directory" -Force 1>$null
log "Created log directory -- ${LogDir}"

#Create log entry to note the script that is executing
log $ScriptStart
log "Within ${ScriptName} --"
log "RequiredVssWriters = ${RequiredVssWriters}"
log "RemainingArgsHash = $(($RemainingArgsHash.GetEnumerator() | % { `"-{0}: {1}`" -f $_.key, $_.value }) -join ' ')"

#Insert script commands
###

#Get all the fixed disk volumes
$FixedVolumes = Get-Volume | where { $_.DriveType -eq "Fixed" }

# Create the diskshadow script file
CreateDshScript -Volumes $FixedVolumes -VssMetaDataFile $VssMetaDataFile -ExecScript $ExecScriptFile -RequiredVssWriters $RequiredVssWriters -CleanupVssSnapshots:$false | Set-Content $DshScriptFile

# Execute diskshadow with the script file (this creates vss snapshots of the volumes specified in $dshscriptfile)
diskshadow.exe /s ${DshScriptFile}

###

#Log exit from script
log "Exiting ${ScriptName} --"
log $ScriptEnd
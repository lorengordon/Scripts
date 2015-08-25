[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeLine=$true)]
    [ValidateScript({ Test-Path "${_}" -PathType Container })]
    [System.IO.DirectoryInfo[]] $source
    ,
    [Parameter(Mandatory=$true,Position=1)]
    [System.IO.DirectoryInfo] $dest_root
    ,
    [Parameter(Mandatory=$false)]
    [string] $prepend_text="### MANAGED FILE ###"
    ,
    [Parameter(Mandatory=$false)]
    [string[]] $prepend_whitelist=@(
		".png"
        ".jpg"
	)
    ,
    [Parameter(Mandatory=$false)]
    [string] $rename_ext=".txt"
    ,
    [Parameter(Mandatory=$false)]
    [string[]] $rename_whitelist=@(
		".png"
        ".jpg"
	)
    ,
    [Parameter(Mandatory=$false)]
    [string[]] $encode_types=@(
		".exe"
        ".rpm"
        ".msi"
        ".pdf"
        ".zip"
        ".class"
        ".jar"
        ".eps"
        ".tar"
        ".gz"
        ".mpp"
	)
    ,
    [Parameter(Mandatory=$false)]
    [string] $exclude_regex="\.git\\|Thumbs\.db$"
    ,
    [Parameter(Mandatory=$false)]
    [switch] $force
)
BEGIN {


    # Define helper functions
    function Convert-BinaryToString {
        [CmdletBinding()]
        param (
            [string] $FilePath
        )

        try 
        {
            $ByteArray = [System.IO.File]::ReadAllBytes($FilePath);
        }
        catch 
        {
            throw "Failed to read file. Please ensure that you have permission to the file, and that the file path is correct.";
        }

        if ($ByteArray) 
        {
            $Base64String = [System.Convert]::ToBase64String($ByteArray);
        }
        else 
        {
            throw '$ByteArray is $null.';
        }

        Write-Output -InputObject $Base64String;
    }


	#Make sure $dest_root exists and is a directory item
	$dest_root = New-Item -Path $dest_root -ItemType Directory -Force

}
PROCESS {
	foreach ($s_dir in $source) {

		"Beginning to process source directory: `'$s_dir`'" | Out-Default

		# Make sure the source is a directory item
		if ( ($s_dir.gettype().name) -ne "DirectoryInfo" ) {
			$s_dir = Get-Item $s_dir
		}

		# Construct the destination path
		$dest = "${dest_root}\$(${s_dir}.name)"
		
		# If the destination path exists, remove it
		if (Test-Path $dest) {
			if (-not $force) {
				Write-Host "Destination path, `'$dest`', already exists and must be removed to continue." -ForegroundColor "Yellow"
				Write-Host "Delete it now? Any response other than `'[Y]es`' will skip this directory. ( [Y]es | [N]o ): " -NoNewLine -ForegroundColor "Yellow"
				$response = Read-Host
				if ($response -notmatch "y|yes") {
					Write-Host "Ok, will not delete `'$dest`'. Skipping this directory." -ForegroundColor "Red"
					continue
				}
			}
			"   Deleting destination directory, `'$dest`'." | Out-Default
			Remove-Item -Path $dest -Recurse -Force
		}

		# Create the target directory
		"   Creating the destination directory, `'${dest}`'." | Out-Default
		$dest = New-Item -Path $dest -ItemType Directory -Force

		# Create array of all subdirectories in the source excluding .git
        $exclude_dirs = "\.git$"
		$dirs = @(Get-ChildItem -Path $s_dir -Recurse | where { $_.FullName -notmatch $exclude_dirs } | where { $_.PSIsContainer -eq $true })

		# Create the directory tree
		"   Replicating the directory tree of the source in the destination directory." | Out-Default
		$new_dirs = $dirs | foreach {
			New-Item -Path "${dest}\$(${_}.FullName.Substring($s_dir.FullName.length))" -ItemType "Directory" -Force
		}

		# Create array of all files that don't match the $exclude_regex string
		"   Getting a list of all the files to process" | Out-Default
		$files = @(Get-ChildItem -Path $s_dir -Recurse | where { $_.FullName -notmatch $exclude_regex } | where { $_.PSIsContainer -eq $false })

		# Copy the files, tacking on a '.txt' extension if the file extension isn't whitelisted
		"   Copying files to the destination directory" | Out-Default
		$new_files = $files | foreach {
			$DestFileName = "${dest}\$($_.FullName.Substring($s_dir.FullName.length))"
			if ( $rename_whitelist -notcontains $_.Extension ) {
				$DestFileName = $DestFileName + $rename_ext
			}
            # Base64 encode files with extensions that match $encode_types; straight copy everything else
            if ( $encode_types -contains $_.Extension -or $_.Extension -match "[0-9]{3}" ) {
                Convert-BinaryToString -FilePath $_.FullName | Out-File -FilePath $DestFileName
            } else {
                Copy-Item -Path "$($_.FullName)" -Destination "$DestFileName" -Force
            }
            Get-Item "$DestFileName"
		}

		# Add the $prepend_text string to each file
		if ( $prepend_text ) {
			"   Pre-pending `'$prepend_text`' to each file in the destination directory." | Out-Default
			$new_files | where { $prepend_whitelist -notcontains $_.Extension } | foreach {
				# Courtesy http://stackoverflow.com/a/8852812
				# Get the contents
				$contents = [IO.File]::ReadAllText($_)
				# Check for unix line endings
				# Courtesy http://www.computing.net/answers/programming/batch-to-detect-unix-and-windows-line-endings/24948.html
				$EOL = "`r`n"
				if ( $contents -Match "[^`r]`n" )	{ $EOL = "`n" }
				# Prepend $prepend_text to $contents
				$contents = $prepend_text + $EOL + $contents
				# Create UTF-8 encoding without signature
				$utf8 = New-Object System.Text.UTF8Encoding $false
				# Write the text back
				[IO.File]::WriteAllText($_, $contents, $utf8)
			}
		}
	}
}
END {
"Completed processing all directories." | Out-Default
}

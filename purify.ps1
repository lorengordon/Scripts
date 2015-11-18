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
    [string] $strip_extension=".txt"
    ,
    [Parameter(Mandatory=$false)]
    [bool] $strip_firstline=$true
    ,
    [Parameter(Mandatory=$false)]
    [string[]] $strip_firstline_whitelist=@(
        ".png"
        ".jpg"
    )
    ,
    [Parameter(Mandatory=$false)]
    [string[]] $decode_types=@(
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
        ".sls"
        ".adml"
        ".admx"
        ".py"
        ".wsf"
        ".template"
    )
    ,
    [Parameter(Mandatory=$false)]
    [switch] $force
)
BEGIN {


    function Convert-StringToBinary {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,Position=0,ValueFromPipeLine=$true)]
            [string] $InputString
            ,
            [Parameter(Mandatory=$false)]
            [string] $FilePath = ('{0}\{1}' -f $env:TEMP, [System.Guid]::NewGuid().ToString())
        )

        try 
        {
            if ($InputString.Length -ge 1) 
            {
                $ByteArray = [System.Convert]::FromBase64String($InputString);
                [System.IO.File]::WriteAllBytes("${FilePath}", $ByteArray);
            }
        }
        catch 
        {
            throw ('Failed to create file from Base64 string: {0}' -f $FilePath);
        }

        Write-Output -InputObject (Get-Item -Path "${FilePath}");
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
		$dirs = @(Get-ChildItem -Path $s_dir -Recurse | where { $_.FullName -notmatch "\.git$"} | where { $_.PSIsContainer -eq $true })

		# Create the directory tree
		"   Replicating the directory tree of the source in the destination directory." | Out-Default
		$new_dirs = $dirs | foreach {
			New-Item -Path "${dest}\$(${_}.FullName.Substring($s_dir.FullName.length))" -ItemType "Directory" -Force
		}

		# Create array of all files that are not in the .git directory
		$files = @(Get-ChildItem -Path $s_dir -Recurse | where { $_.FullName -notmatch "\.git$|\.git\\"} | where { $_.PSIsContainer -eq $false })

		# Copy the files, removing the $strip_extension extension
		"   Copying files to the destination directory" | Out-Default
		$new_files = $files | foreach {
			$DestFileName = "${dest}\$(${_}.FullName.Substring($s_dir.FullName.length))"
			if ( $DestFileName.ToLower().EndsWith($strip_extension) ) {
				$DestFileName = $DestFileName.Substring(0,$DestFileName.Length-$strip_extension.Length)
			}
			Copy-Item -Path $_.FullName -Destination $DestFileName -Force -PassThru
		}

		# Strip the first line from each file
		if ($strip_firstline) {
			"   Stripping first line from each file in the destination directory." | Out-Default
			$new_files | where { $strip_firstline_whitelist -notcontains $_.Extension } | foreach {
				# Courtesy http://stackoverflow.com/a/8852812
				# Get the contents as a string
				$contents = [IO.File]::ReadAllText($_)
				# Check for unix line endings
				# Courtesy http://www.computing.net/answers/programming/batch-to-detect-unix-and-windows-line-endings/24948.html
				$EOL = "`r`n"
				if ( $contents -Match "[^`r]`n" )	{ $EOL = "`n" }
				# Strip the first line
				$contents = $contents -replace "^.*$EOL", ""
				# Create UTF-8 encoding without signature
				$utf8 = New-Object System.Text.UTF8Encoding $false
				# Write the text back
				[IO.File]::WriteAllText($_, $contents, $utf8)
			}
		}
        
        # Decode base64 content for files with extensions that match $decode_types
        "   Decoding base64-encoded files..."
        $null = $new_files | where { $decode_types -contains $_.Extension -or $_.Extension -match "[0-9]{3}" } | foreach {
            (Get-Content $_.FullName) | Convert-StringToBinary -FilePath $_.FullName
        }
	}
}
END {
"Completed processing all directories." | Out-Default
}

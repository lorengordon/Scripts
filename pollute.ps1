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
    [string] $prepend="### MANAGED FILE ###"
    ,
    [Parameter(Mandatory=$false)]
    [switch] $force
)
BEGIN {
	#Make sure $dest_root exists and is a directory item
	$dest_root = New-Item -Path $dest_root -ItemType Directory -Force

	function Get-MimeType 
	{
		#Courtesy http://stackoverflow.com/a/13053795
		[CmdLetBinding()]
		Param(
			[Parameter(Mandatory=$false,Position=0,ValueFromPipeLine=$true)]
			[string[]] $Extension
			,
			[Parameter(Mandatory=$false,Position=1,ValueFromPipeLine=$false)]
			[string] $DefaultType = $null
		)
		BEGIN
		{
			$drive = Get-PSDrive HKCR -ErrorAction SilentlyContinue
			if ( $null -eq $drive )
			{
			  $drive = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
			}
		}
		PROCESS
		{
			foreach ( $ext in $extension ) 
			{
				if ( $null -ne $ext )
				{
					$mimeType = $null
					try
					{
						$mimeType = (Get-ItemProperty HKCR:$ext -ErrorAction "Stop")."Content Type"
					}
					catch
					{
						if ( "System.Management.Automation.ItemNotFoundException" -eq $_.Exception.GetType().FullName )
						{
							#noop
						}
						else
						{
							throw $_.Exception.GetType().FullName
						}
					}
					if ( $null -ne $mimeType ) 
					{
						return $mimeType 
					}
					elseif ( $DefaultType )
					{
						return $DefaultType
					}
				}
			}
		}
	}

	function Get-DestFileName
	{
		[CmdLetBinding()]
		Param(
			[Parameter(Mandatory=$false,Position=0,ValueFromPipeLine=$true)]
			[System.IO.FileInfo[]] $SourceFile
			,
			[Parameter(Mandatory=$false,Position=1,ValueFromPipeLine=$false)]
			[System.IO.DirectoryInfo] $SourceDir
			,
			[Parameter(Mandatory=$false,Position=2,ValueFromPipeLine=$false)]
			[string] $TargetDir
		)
		BEGIN
		{
			$DefaultType = "text/plain"
			$MimeTypesToRename = @(
				"text/plain"
			)
			# Make sure $sourcedir is a directory item
			if ( ($SourceDir.gettype().name) -ne "DirectoryInfo" ) {
				$SourceDir = Get-Item $SourceDir
			}
		}
		PROCESS {
			foreach ( $file in $SourceFile )
			{
				# Make sure the source file is a file item
				if ( ($file.gettype().name) -ne "FileInfo" ) {
					$file = Get-Item $file
				}

				$mime = Get-MimeType $file.Extension -DefaultType $DefaultType
				$DestFileName = "${TargetDir}\$(${file}.FullName.Substring($SourceDir.FullName.length))"
				if ( $MimeTypesToRename -contains $mime )
				{
					return "${DestFileName}.txt"
				}
				else
				{
					return "${DestFileName}"
				}
			}
		}
	}
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

		# Copy the files, tacking on a '.txt' extension
		"   Copying files to the destination directory" | Out-Default
		$new_files = $files | foreach {
			Copy-Item -Path $_.FullName -Destination (Get-DestFileName $_ $s_dir $dest) -Force -PassThru
		}

		# Add the $prepend string to each file
		$exclude='\.png\.txt$'
		"   Pre-pending `'$prepend`' to each file in the destination directory." | Out-Default
		$new_files | where { $_.name -notmatch "$exclude" } | foreach {
			# Courtesy http://www.computing.net/answers/programming/batch-to-detect-unix-and-windows-line-endings/24948.html
			$unixEOF = (Get-Content $_ -Delimiter [String].Empty) -Match "[^`r]`n"
			$prepend,(Get-Content $_) | Set-Content $_
			if ($unixEOF) {
				# Courtesy http://stackoverflow.com/a/8852812
				# get the contents and replace line breaks by U+000A
				$contents = [IO.File]::ReadAllText($_) -replace "`r`n?", "`n"
				# create UTF-8 encoding without signature
				$utf8 = New-Object System.Text.UTF8Encoding $false
				# write the text back
				[IO.File]::WriteAllText($_, $contents, $utf8)
			}
		}
	}
}
END {
"Completed processing all directories." | Out-Default
}

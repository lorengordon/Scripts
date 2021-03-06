[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string] $git_username
    ,
    [Parameter(Mandatory=$true,Position=1)]
    [string] $git_email
    ,
    [Parameter(Mandatory=$false)]
    [string] $download_dir="${env:Temp}"
    ,
    [Parameter(Mandatory=$false)]
    [string] $program_dir="${env:userprofile}\Documents\Programs"
    ,
    [Parameter(Mandatory=$false)]
    [string] $python27_url="https://www.python.org/ftp/python/2.7.12/python-2.7.12.amd64.msi"
    ,
    [Parameter(Mandatory=$false)]
    [string] $vc_python27_url="http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi"
    ,
    [Parameter(Mandatory=$false)]
    [string] $npp_url="https://notepad-plus-plus.org/repository/6.x/6.9.2/npp.6.9.2.bin.zip"
    ,
    [Parameter(Mandatory=$false)]
    [string] $atom_url="https://github.com/atom/atom/releases/download/v1.10.2/atom-windows.zip"
    ,
    [Parameter(Mandatory=$false)]
    [string] $gitforwindows_url="https://github.com/git-for-windows/git/releases/download/v2.10.0.windows.1/PortableGit-2.10.0-64-bit.7z.exe"
    ,
    [Parameter(Mandatory=$false)]

    [string] $poshgit_url = "https://github.com/dahlbyk/posh-git.git"
)


# Create user dirs
"Creating download and program directories..." | Out-Default
$null = New-Item -Path $download_dir -ItemType Directory -Force
$null = New-Item -Path $program_dir -ItemType Directory -Force


# Get python27 installer
"Downloading python27..." | Out-Default
$python27_installer = "${download_dir}\python27.msi"
(new-object net.webclient).DownloadFile("${python27_url}","${python27_installer}")


# Install python27
$python27_dir = "${program_dir}\Python27"
"Creating python27 directory..." | Out-Default
$null = New-Item -Path $python27_dir -ItemType Directory -Force
"Installing python27..." | Out-Default
$python27_params = "/i `"${python27_installer}`" /quiet /qn /norestart TARGETDIR=`"${python27_dir}`" ADDLOCAL=ALL"
$null = Start-Process -FilePath msiexec -ArgumentList ${python27_params} -NoNewWindow -PassThru -Wait


# Get vc_python27 installer
"Downloading vc python27 compiler..." | Out-Default
$vc_python27_installer = "${download_dir}\vc_python27.msi"
(new-object net.webclient).DownloadFile("${vc_python27_url}","${vc_python27_installer}")


# Install vc_python27 installer
"Installing vc python27 compiler..." | Out-Default
$vc_python27_params = "/i `"${vc_python27_installer}`" /quiet /qn /norestart"
$null = Start-Process -FilePath msiexec -ArgumentList ${vc_python27_params} -NoNewWindow -PassThru -Wait


# Get npp zip file
"Downloading notepad++..." | Out-Default
$npp_zipfile = "${download_dir}\npp.zip"
(new-object net.webclient).DownloadFile("${npp_url}","${npp_zipfile}")


# Unzip npp
"Installing notepad++..." | Out-Default
$npp_dir = "${program_dir}\npp"
$null = New-Item -Path $npp_dir -ItemType Directory -Force
$shell = new-object -com shell.application
$shell.namespace($npp_dir).copyhere($shell.namespace("$npp_zipfile").items(), 0x14)


# Get atom zip file
"Downloading atom..." | Out-Default
$atom_zipfile = "${download_dir}\atom-windows.zip"
(new-object net.webclient).DownloadFile("${atom_url}","${atom_zipfile}")


# Unzip atom
"Installing atom..." | Out-Default
$atom_dir = "${program_dir}\atom"
$null = New-Item -Path $atom_dir -ItemType Directory -Force
$shell = new-object -com shell.application
$shell.namespace($atom_dir).copyhere($shell.namespace("$atom_zipfile").items(), 0x14)


#TODO: Use ftypes and assoc to build the list of text file types automatically
#$notepad_ftypes = cmd /c ftype | where { $_ -match "notepad"} | % {$_.split('=')[0] }


# List of python file types to be handled by python
$python_ftypes = @(
	".py"
)


# Add handler for python27
"Adding handler for python27 to the registry..." | Out-Default
iex @'
reg add `"HKCU\Software\Classes\Applications\python.exe\shell\open\command`" /ve /t REG_SZ /d `"\`"${python27_dir}\python.exe\`" \`"%1\`" %*`" /f
'@


# Make python27 the default for all python file types
$python_ftypes | % {
	"Making python27 the default handler for file type: $_" | Out-Default
	iex @'
reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$_\UserChoice`" /v `"Progid`" /t REG_SZ /d `"Applications\python.exe`" /f
'@
}


# List of text file types handled by notepad by default
$text_ftypes = @(
	".compositefont", ".css", ".dic", ".example", ".exc", ".gitattributes"
  ".gitignore", ".gitmodules", ".inf", ".ini", ".log", ".md", ".oqy", ".ps1"
  ".ps1xml", ".psd1", ".psm1", ".rqy", ".scp", ".sct", ".sh", ".sls", ".txt"
  ".wsc", ".wtx", ".yaml", ".yml"
)


# Add handler for atom
"Adding handler for atom to the registry..." | Out-Default
iex @'
reg add `"HKCU\Software\Classes\Applications\atom.exe\shell\open\command`" /ve /t REG_SZ /d `"\`"${atom_dir}\Atom\atom.exe\`" \`"%1\`"`" /f
'@


# Make atom the default for all text file types
$text_ftypes | % {
	"Making atom the default handler for file type: $_" | Out-Default
	iex @'
reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$_\UserChoice`" /v `"Progid`" /t REG_SZ /d `"Applications\atom.exe`" /f
'@
}


# Get git for windows installer
"Downloading git for windows..." | Out-Default
$gitforwindows_installer = "${download_dir}\gitforwindows.exe"
(new-object net.webclient).DownloadFile("${gitforwindows_url}","${gitforwindows_installer}")


# Install git for windows
"Stopping ssh-agent..." | Out-Default
$null = Stop-Process -Name ssh-agent -ErrorAction SilentlyContinue

"Installing git for windows..." | Out-Default
$gitforwindows_dir = "${program_dir}\Git"
$null = New-Item -Path $gitforwindows_dir -ItemType Directory -Force
$gitforwindows_params = "-y -gm2 -InstallPath=`"${gitforwindows_dir}`""
$null = Start-Process -FilePath ${gitforwindows_installer} -ArgumentList ${gitforwindows_params} -NoNewWindow -PassThru -Wait


# Setup basic git settings
"Configuring basic git settings..." | Out-Default
$env:path += ";${gitforwindows_dir}\cmd;${gitforwindows_dir}\bin"
iex "git config --global user.name `"${git_username}`""
iex "git config --global user.email `"${git_email}`""
iex "git config --global core.autocrlf false"
iex "git config --global branch.autosetuprebase always"
iex "git config --global credential.helper wincred"
iex "git config --global push.default simple"


# Configure ssh over https
"Configuring ssh to work over https..." | Out-Default
$ssh_dir = "${env:userprofile}\.ssh"
$ssh_config_file = "${ssh_dir}\config"
$null = New-Item -Path $ssh_dir -ItemType Directory -Force
$null = New-Item -Path $ssh_config_file -ItemType File -ErrorAction SilentlyContinue
$ssh_config_contents = @(Get-Content -Path $ssh_config_file)
$ssh_config = @()
$ssh_config += "Host github.com"
$ssh_config += "  Hostname ssh.github.com"
$ssh_config += "  Port 443"
$ssh_config += ""
if (-not $ssh_config_contents -contains "Host github.com") {
	Set-Content -Value $ssh_config,$ssh_config_contents -Path $ssh_config_file
}


# Setup PowerShell Profile
"Setting up PowerShell profile..." | Out-Default
$ps_profile_dir = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell"
$ps_profile = "${ps_profile_dir}\Microsoft.PowerShell_profile.ps1"
$null = New-Item -Path $ps_profile_dir -ItemType Directory -Force
$null = New-Item -Path $ps_profile -ItemType File -ErrorAction SilentlyContinue
$ps_profile_contents = @()
$ps_profile_contents += "`$program_dir = `"${program_dir}`""
$ps_profile_contents += '$env:path += ";${program_dir}\Git\bin"'
$ps_profile_contents += '$env:path += ";${program_dir}\Git\usr\bin"'
$ps_profile_contents += '$env:path += ";${program_dir}\Python27"'
$ps_profile_contents += '$env:path += ";${program_dir}\Python27\Scripts"'
$ps_profile_contents += '$env:path += ";${program_dir}\atom\Atom"'
$ps_profile_contents += '$env:path += ";${env:localappdata}\Programs\Common\Microsoft\Visual C++ for Python\9.0"'
$ps_profile_contents += 'set-alias npp "${program_dir}\npp\notepad++.exe"'
$ps_profile_contents += 'set-alias notepad "${program_dir}\npp\notepad++.exe"'
$ps_profile_contents = $ps_profile_contents | where { !(Select-String -SimpleMatch "${_}" -Path ${ps_profile} -Quiet)}
$ps_profile_contents,(Get-Content -Path $ps_profile) | Set-Content -Path ${ps_profile}


# Install posh-git
"Installing posh-git" | Out-Default
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "${program_dir}"
iex "git clone ${poshgit_url}"
cd posh-git
iex "git pull"
iex ".\install.ps1"


# Load ps profile
'Bootstrap complete. Run ". $PROFILE" to load the PowerShell profile' | Out-Default

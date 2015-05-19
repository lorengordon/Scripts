[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string] $git_username
    ,
    [Parameter(Mandatory=$true,Position=1)]
    [string] $git_email
    ,
    [Parameter(Mandatory=$false)]
    [string] $download_dir="${env:userprofile}\Downloads"
    ,
    [Parameter(Mandatory=$false)]
    [string] $program_dir="${env:userprofile}\Documents\Programs"
    ,
    [Parameter(Mandatory=$false)]
    [string] $python27_url="https://www.python.org/ftp/python/2.7.9/python-2.7.9.amd64.msi"
    ,
    [Parameter(Mandatory=$false)]
    [string] $vc_python27_url="http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi"
    ,
    [Parameter(Mandatory=$false)]
    [string] $npp_url="https://notepad-plus-plus.org/repository/6.x/6.7.8.1/npp.6.7.8.1.bin.zip"
    ,
    [Parameter(Mandatory=$false)]
    [string] $msysgit_url="https://github.com/msysgit/msysgit/releases/download/Git-1.9.5-preview20150319/Git-1.9.5-preview20150319.exe"
    ,
    [Parameter(Mandatory=$false)]
    [string] $poshgit_url = "https://github.com/dahlbyk/posh-git.git"
)


# Create user dirs
"Creating download and program directories" | Out-Default
New-Item -Path $download_dir -ItemType Directory -Force
New-Item -Path $program_dir -ItemType Directory -Force


# Get python27 installer
"Downloading python27" | Out-Default
$python27_installer = "${download_dir}\python27.msi"
(new-object net.webclient).DownloadFile("${python27_url}","${python27_installer}")


# Install python27
$python27_dir = "${program_dir}\Python27"
"Creating python27 directory" | Out-Default
New-Item -Path $python27_dir -ItemType Directory -Force
"Installing python27" | Out-Default
$python27_params = "/i `"${python27_installer}`" /quiet /qn /norestart TARGETDIR=`"${python27_dir}`" ADDLOCAL=ALL"
Start-Process -FilePath msiexec -ArgumentList ${python27_params} -NoNewWindow -PassThru -Wait


# Get vc_python27 installer
"Downloading vc python27 compiler" | Out-Default
$vc_python27_installer = "${download_dir}\vc_python27.msi"
(new-object net.webclient).DownloadFile("${vc_python27_url}","${vc_python27_installer}")


# Install python
"Installing vc python27 compiler" | Out-Default
$vc_python27_params = "/i `"${vc_python27_installer}`" /quiet /qn /norestart"
Start-Process -FilePath msiexec -ArgumentList ${vc_python27_params} -NoNewWindow -PassThru -Wait


# Get npp zip file
"Downloading notepad++" | Out-Default
$npp_zipfile = "${download_dir}\npp.zip"
(new-object net.webclient).DownloadFile("${npp_url}","${npp_zipfile}")


# Unzip npp
"Installing notepad++" | Out-Default
$npp_dir = "${program_dir}\npp"
New-Item -Path $npp_dir -ItemType Directory -Force
$shell = new-object -com shell.application
$shell.namespace($npp_dir).copyhere($shell.namespace("$npp_zipfile").items(), 0x14) 


#TODO: Use ftypes and assoc to build the list of text file types automatically
#$notepad_ftypes = cmd /c ftype | where { $_ -match "notepad"} | % {$_.split('=')[0] }

# List of text file types handled by notepad by default
$text_ftypes = @(
	".compositefont", ".css", ".dic", ".exc", ".gitattributes", ".gitignore"
	".gitmodules", ".inf", ".ini", ".log", ".oqy", ".ps1", ".ps1xml", ".psd1"
	".psm1", ".rqy", ".scp", ".sct", ".txt", ".wsc", ".wtx"
)


# Add handler for npp
"Adding handler for notepad++ to the registry"
iex @'
reg add `"HKCU\Software\Classes\Applications\notepad++.exe\shell\open\command`" /ve /t REG_SZ /d `"\`"${npp_dir}\notepad++.exe\`" \`"%1\`"`" /f
'@


# Make npp the default for all text file types
$text_ftypes | % {
	"Making notepad++ the default handler for file type: $_" | Out-Default
	iex @'
reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$_\UserChoice`" /v `"Progid`" /t REG_SZ /d `"Applications\notepad++.exe`" /f
'@
}


# Get msysgit installer
"Downloading msysgit" | Out-Default
$msysgit_installer = "${download_dir}\msysgit.exe"
(new-object net.webclient).DownloadFile("${msysgit_url}","${msysgit_installer}")


# Install msysgit
"Installing msysgit" | Out-Default
$msysgit_dir = "${program_dir}\Git"
New-Item -Path $msysgit_dir -ItemType Directory -Force
$msysgit_params = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NOCLOSEAPPLICATIONS /NORESTART /DIR=`"${msysgit_dir}`" /COMPONENTS=`"icons,icons\quicklaunch,icons\desktop,ext,ext\cheetah,assoc,assoc_sh`""
Start-Process -FilePath ${msysgit_installer} -ArgumentList ${msysgit_params} -NoNewWindow -PassThru -Wait


# Setup basic git settings
"Configuring basic git settings" | Out-Default
$env:path += ";${msysgit_dir}\cmd;${msysgit_dir}\bin"
iex "git config --global user.name ${git_username}"
iex "git config --global user.email ${git_email}"
iex "git config --global core.autocrlf false"
iex "git config --global branch.autosetuprebase always"
iex "git config --global credential.helper wincred"
iex "git config --global push.default simple"


# Configure ssh over https
"Configuring ssh to work over https" | Out-Default
$ssh_dir = "${env:userprofile}\.ssh"
$ssh_config_file = "${ssh_dir}\config"
New-Item -Path $ssh_dir -ItemType Directory -Force
New-Item -Path $ssh_config_file -ItemType File -ErrorAction SilentlyContinue
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
"Setting up PowerShell profile" | Out-Default
$ps_profile_dir = "${env:userprofile}\Documents\WindowsPowerShell"
$ps_profile = "${ps_profile_dir}\Microsoft.PowerShell_profile.ps1"
New-Item -Path $ps_profile_dir -ItemType Directory -Force
New-Item -Path $ps_profile -ItemType File -ErrorAction SilentlyContinue
$ps_profile_contents = @()
$ps_profile_contents += '$env:path += ";${env:userprofile}\Documents\Programs\Git\cmd"'
$ps_profile_contents += '$env:path += ";${env:userprofile}\Documents\Programs\Git\bin"'
$ps_profile_contents += '$env:path += ";${env:userprofile}\Documents\Programs\Python27"'
$ps_profile_contents += '$env:path += ";${env:userprofile}\Documents\Programs\Python27\Scripts"'
$ps_profile_contents += '$env:path += ";${env:localappdata}\Programs\Common\Microsoft\Visual C++ for Python\9.0"'
$ps_profile_contents += 'set-alias npp "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents += 'set-alias notepad "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents = $ps_profile_contents | where { !(Select-String -SimpleMatch "${_}" -Path ${ps_profile} -Quiet)}
$ps_profile_contents,(Get-Content -Path $ps_profile) | Set-Content -Path ${ps_profile}


# Install posh-git
"Installing posh-git" | Out-Default
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "${program_dir}"
iex "git clone ${poshgit_url}"
cd posh-git
iex ".\install.ps1"


# Load ps profile
"Loading the PowerShell profile" | Out-Default
. $PROFILE

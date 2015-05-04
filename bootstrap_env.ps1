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
    [string] $npp_url="http://notepad-plus-plus.org/repository/6.x/6.7.7/npp.6.7.7.bin.zip"
    ,
    [Parameter(Mandatory=$false)]
    [string] $msysgit_url="https://github.com/msysgit/msysgit/releases/download/Git-1.9.5-preview20150319/Git-1.9.5-preview20150319.exe"
    ,
    [Parameter(Mandatory=$false)]
    [string] $posh-git_url = "https://github.com/dahlbyk/posh-git.git"
)


# Create user dirs
New-Item -Path $download_dir -ItemType Directory -Force
New-Item -Path $program_dir -ItemType Directory -Force


# Get npp zip file
$npp_zipfile = "${download_dir}\npp.zip"
(new-object net.webclient).DownloadFile("${npp_url}","${npp_zipfile}")


# Unzip npp
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
iex @'
reg add `"HKCU\Software\Classes\Applications\notepad++.exe\shell\open\command`" /ve /t REG_SZ /d `"\`"${npp_dir}\notepad++.exe\`" \`"%1\`"`" /f
'@


# Make npp the default for all text file types
$text_ftypes | % { iex @'
reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$_\UserChoice`" /v `"Progid`" /t REG_SZ /d `"Applications\notepad++.exe`" /f
'@
}


# Get msysgit installer
$msysgit_installer = "${download_dir}\msysgit.exe"
(new-object net.webclient).DownloadFile("${msysgit_url}","${msysgit_installer}")


# Install msysgit
$msysgit_dir = "${program_dir}\Git"
New-Item -Path $msysgit_dir -ItemType Directory -Force
$msysgit_params = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NOCLOSEAPPLICATIONS /NORESTART /DIR=`"${msysgit_dir}`" /COMPONENTS=`"icons,icons\quicklaunch,icons\desktop,ext,ext\cheetah,assoc,assoc_sh`""
Start-Process -FilePath ${msysgit_installer} -ArgumentList ${msysgit_params} -NoNewWindow -PassThru -Wait


# Setup basic git settings
$env:path += ";${msysgit_dir}\cmd;${msysgit_dir}\bin"
iex "git config --global user.name ${git_username}"
iex "git config --global user.email ${git_email}"
iex "git config --global core.autocrlf false"
iex "git config --global branch.autosetuprebase always"
iex "git config --global credential.helper wincred"
iex "git config --global push.default simple"


# Configure ssh over https
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
$ps_profile_dir = "${env:userprofile}\Documents\WindowsPowerShell"
$ps_profile = "${ps_profile_dir}\Microsoft.PowerShell_profile.ps1"
New-Item -Path $ps_profile_dir -ItemType Directory -Force
New-Item -Path $ps_profile -ItemType File -ErrorAction SilentlyContinue
$ps_profile_contents = @()
$ps_profile_contents += '$env:path += ";${env:userprofile}\Documents\Programs\Git\cmd;${env:userprofile}\Documents\Programs\Git\bin"'
$ps_profile_contents += 'set-alias npp "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents += 'set-alias notepad "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents = $ps_profile_contents | where { !(Select-String -SimpleMatch "${_}" -Path ${ps_profile} -Quiet)}
$ps_profile_contents,(Get-Content -Path $ps_profile) | Set-Content -Path ${ps_profile}


# Install posh-git
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "${program_dir}"
iex "git clone ${posh-git_url}"
cd posh-git
iex ".\install.ps1"


# Load ps profile
iex ". $PROFILE"

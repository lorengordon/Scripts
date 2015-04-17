$git_username = ""
$git_email = ""
$git_dir = "${env:userprofile}\Documents\git"

$npp_url = "http://notepad-plus-plus.org/repository/6.x/6.7.7/npp.6.7.7.bin.zip"
$msysgit_url = "https://github.com/msysgit/msysgit/releases/download/Git-1.9.5-preview20150319/Git-1.9.5-preview20150319.exe"

$download_dir = "${env:userprofile}\Downloads"
$program_dir = "${env:userprofile}\Documents\Programs"


# Create user dirs
New-Item -Path $download_dir -ItemType Directory -Force
New-Item -Path $program_dir -ItemType Directory -Force
New-Item -Path $git_dir -ItemType Directory -Force

# Get npp zip file
$npp_zipfile = "${download_dir}\npp.zip"
(new-object net.webclient).DownloadFile("${npp_url}","${npp_zipfile}")


# Unzip npp
$npp_dir = "${program_dir}\npp"
New-Item -Path $npp_dir -ItemType Directory -Force
$shell = new-object -com shell.application
$shell.namespace($npp_dir).copyhere($shell.namespace("$npp_zipfile").items(), 0x14) 


# Get msysgit installer
$msysgit_installer = "${download_dir}\msysgit.exe"
(new-object net.webclient).DownloadFile("${msysgit_url}","${msysgit_installer}")


# Install msysgit
$msysgit_dir = "${program_dir}\Git"
New-Item -Path $msysgit_dir -ItemType Directory -Force
$msysgit_params = "/SP- /VERYSILENT /NORESTART /DIR=`"${msysgit_dir}`" /COMPONENTS=`"icons,icons\quicklaunch,icons\desktop,ext\cheetah,assoc,assoc_sh`""
Start-Process -FilePath ${msysgit_installer} -ArgumentList ${msysgit_params} -NoNewWindow -PassThru -Wait


# Setup git
& "git config --global user.name ${git_username}"
& "git config --global user.email ${git_email}"


# Setup PowerShell Profile
$ps_profile_dir = "${env:userprofile}\Documents\WindowsPowerShell"
$ps_profile = "${ps_profile_dir}\Microsoft.PowerShell_profile.ps1"
New-Item -Path $ps_profile_dir -ItemType Directory -Force
New-Item -Path $ps_profile -ItemType File -ErrorAction SilentlyContinue
$ps_profile_contents = @()
$ps_profile_contents += '$env:path = "${env:path};${env:userprofile}\Documents\Programs\Git\cmd"'
$ps_profile_contents += 'set-alias npp "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents += 'set-alias notepad "${env:userprofile}\Documents\Programs\npp\notepad++.exe"'
$ps_profile_contents = $ps_profile_contents | where { !(Select-String -SimpleMatch "${_}" -Path ${ps_profile} -Quiet)}
$ps_profile_contents,(Get-Content -Path $ps_profile) | Set-Content -Path ${ps_profile}


# Install posh-git
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
$env:path = "${env:path};${msysgit_dir}\cmd"
cd "${program_dir}"
git clone https://github.com/dahlbyk/posh-git.git
cd posh-git
iex ".\install.ps1"


# Load ps profile
iex ". $PROFILE"

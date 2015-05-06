:: UDS_DataRoot_Share.bat
::
:: Creates SMB Shares (shared folders) to expose the
:: user data store root for folder redirection and profile targets
::
:: See the Windows Administration Resource Kit for documentation
::
:: Neither Microsoft nor Intelliem guarantee the performance
:: of scripts, scripting examples or tools.
::
:: See www.intelliem.com/resourcekit for updates to this script
::
:: (c) 2007 Intelliem, Inc.

@echo off

:: Check to see whether usage is requested or required
if "%1"=="?" goto usage
if "%1"=="/?" goto usage
if "%1"=="" goto usage

Set UserRoot="%1"
Set UserDataShare=users$
Set UserProfileShare=profiles$
Set UserBackupShare=backups$

cls
echo Creating User Data Root Share

net share %UserDataShare%="%UserRoot%" /GRANT:Everyone,Full /CACHE:Manual /REMARK:"Root data share for all user data stores. Allows offline files." >NUL
net share %UserProfileShare%="%UserRoot%" /GRANT:Everyone,Full /CACHE:None /REMARK:"Root share for all user profiles. Does not allow offline files." >NUL
net share %UserBackupShare%="%UserRoot%" /GRANT:Everyone,Full /CACHE:None /REMARK:"Root share for all user backups. Does not allow offline files." >NUL

echo User Data Store Root Shares Created

goto:eof

:: ===========================================================================
:: USAGE EXPLANATION
:: ===========================================================================
:usage

echo This tool can be used to share the user data root folder.
echo.
echo Usage:
echo UDS_DataRoot_Share [path to user data root]
echo.

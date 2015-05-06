:: UDS_DataRoot_ACL.bat
::
:: Creates and applies permissions to the root folder
:: above user data stores for redirected folders and profiles
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

:: CONFIGURATION
:: Define the groups that will be given permissions
Set GRP_ADMIN="ACL_User Data and Settings_Admin"
Set GRP_USERS="Authenticated Users"
Set GRP_AUDIT="ACL_User Data and Settings_Audit"

:: Check to see whether usage is requested or required
if "%1"=="?" goto usage
if "%1"=="/?" goto usage
if "%1"=="" goto usage

Set DIRA="%1"
cls

:: Create the folder
if not exist %DIRA% md %DIRA% 

:: Reset folder to defaults in order to get rid of the explicit
:: ACE assigned to the user running this script as the creator
:: of the folder
icacls %DIRA% /reset 1>NUL

:: Attempt to remove inheritance with icacls
:: Requires version of icacls.exe included with
:: Windows Vista SP1 or Windows Server 2008 
:: Create a flag to indicate whether or not it worked
set manualinherit=0
icacls %DIRA% /inheritance:r 1>NUL 2>NUL
if errorlevel==1 set manualinherit=1

:: Now assign permissions to the folder

:: CONFIGURATION
:: Customize these lines to reflect your security policy
:: System::Full Control (Apply To: This folder, subfolder, and files
icacls %DIRA% /grant SYSTEM:(OI)(CI)(F) 1>NUL

:: Administrators::Full Control
icacls %DIRA% /grant Administrators:(OI)(CI)(F) 1>NUL

:: Grant Full Control to the group that will administer
:: the user data folders. Also grant Read and Create Folders
:: permissions so that the group can create the first-level
:: subfolders (%%username%%) under the user data root folder
icacls %DIRA% /grant %GRP_ADMIN%:(OI)(CI)(IO)(F) 1>NUL
icacls %DIRA% /grant %GRP_ADMIN%:(NP)(RX,AD) 1>NUL

:: Grant Read permission to a group tha represents security auditing
icacls %DIRA% /grant %GRP_AUDIT%:(OI)(CI)(RX) 1>NUL

:: If you are provisioning subfolders for each user, so that
:: below the user data root there will be a folder for each
:: user BEFORE the user has a roaming profile or folder redirection
:: policy applied, then users do not need permissions at the user
:: data root itself--they need permissions only to their individual folder.
:: If, however, you want Windows to create the folders for each 
:: user, then call the script with the AddUsers

if not "%2"=="AddUsers" goto complete
icacls %DIRA% /grant %GRP_USERS%:(NP)(RX) 1>NUL
icacls %DIRA% /grant %GRP_USERS%:(CI)(NP)(AD) 1>NUL
icacls %DIRA% /grant "CREATOR OWNER":(OI)(CI)(OI)(F) 1>NUL

:complete
if %manualinherit%==1 goto:fixinherit
echo Permissioning of %1 complete.
echo.
echo Resulting permissions for visual confirmation:
icacls %DIRA%
echo.
goto:eof

:fixinherit
:: Script was unable to remove inheritance with icacls
:: Prompt user to do it manually
echo Unable to remove inheritance using icacls.exe.
echo.
echo Remove inheritance manually.
echo ----------------------------
echo Open the security properties for %DIRA%
echo and click the Advanced button. On the Permissions tab,
echo deselect the check box that allows inheritance from the parent.
echo When prompted to Copy or Remove inherited permissions,
echo choose REMOVE.
echo.
echo Then return to this command prompt and
pause
echo Permissioning of %1 complete.
echo.
echo Resulting permissions for visual confirmation:
icacls %DIRA%
echo.
goto:eof

:: ===========================================================================
:: USAGE EXPLANATION
:: ===========================================================================
:usage

echo This tool can be used to configure the 
echo permissions required on a user data root folder.
echo.
echo Usage:
echo UDS_DataRoot_ACL [path to user data root] [AddUsers]
echo.
echo [path to user data root] a folder that exists
echo                          or will be created by the script.
echo.
echo AddUsers                 CASE SENSITIVE flag
echo                          adds permissions for users to
echo                          user data root so that Windows
echo                          can create subfolders for each
echo                          user automatically.
echo                          Not required if you are provisioning
echo                          user data folders.
echo.
echo Modify the script to define the permissions applied.
echo.
echo Requires icacls.exe, which is installed by default on
echo Windows Vista, Windows Server 2008 and Windows Server 2003 SP2. 
echo For Windows XP or pre-SP2 versions of Windows Server 2003,
echo copy icacls.exe from a Windows Server 2003 SP2 to System32.
echo.
echo If using Windows XP, Windows Server 2003, or 
echo pre-SP1 versions of Windows Vista, the version of icacls.exe
echo that is included does not allow removing inheritance, so you
echo will be instructed to remove inheritance manually.
echo.
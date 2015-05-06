'==========================================================================
'
' VBScript Source File -- Created with SAPIEN Technologies PrimalScript 2007
'
' NAME: UDS_UserFolders_Provision.vbs
'
' AUTHOR: Dan Holme , Intelliem
' DATE  : 11/12/2007
'
' USAGE:  
' cscript.exe UDS_UserFolders_Provision.vbs UserFolderPath
'
' Creates a physical namespace for user data stores.
' See the Windows Administration Resource Kit for documentation
' See the scripts UDS_UserFolders_Provision_DFS And
' UDS_UserFolders_Extended_Provision_DFS for more advanced solutions.
'
' Neither Microsoft nor Intelliem guarantee the performance
' of scripts, scripting examples or tools.
'
' See www.intelliem.com/resourcekit for updates to this script
'
' (c) 2007 Intelliem, Inc
'==========================================================================

Option Explicit

Dim FSO, WSHShell
Dim sParentFolder, sUsername, sCommand, sFolder
Dim arr, i, ret
Dim sDomainNetBIOS, sTemplate_UserData
Dim bInheritanceError

' CONFIGURATION BLOCK
' Your domain name
sDomainNetBIOS = "CONTOSO"
' The name of the quota template you want applied to the user's Data folder
' Change to blank ("") if you want to skip the application of a quota
sTemplate_UserData = "1 GB User Data Storage Limit with 100 MB Extension"

Create_Common_Objects
Check_Arguments

If Not FolderPath_Create(sParentFolder) Then
	WScript.Echo sParentFolder & " could not be found and could not be created."
	WScript.Quit
End If

' Determine the user name by looking at the last folder in the folder path
sUsername = FSO.GetFolder(sParentFolder).Name

sFolder = sParentFolder & "\Data"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
	' For example, apply a quota:
	If sTemplate_UserData > "" Then
		sCommand = "dirquota quota add /path:""" & sFolder & _
			""" /sourcetemplate:""" & sTemplate_UserData & """"
		arr = Execute_Capture(sCommand, 10, True)
	End If
End If

sFolder = sParentFolder & "\Data\Documents"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
End If

sFolder = sParentFolder & "\Data\Desktop"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
End If

sFolder = sParentFolder & "\Backups"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
End If

sFolder = sParentFolder & "\Profile"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
End If

sFolder = sParentFolder & "\Profile.V2"
If FolderPath_Create( sFolder ) Then
	' Management logic here:
	' any code you want to perform after the folder has beeen created
End If

' INHERITANCE
' Ensure that inheritance is enabled for the %username% folder and the profile folders
' If the roaming profile created the folder first, it will be off!
' WS2008 code using icacls.exe with the new /inheritance switch
sCommand = "icacls """ & sParentFolder & """ /inheritance:e"
arr = Execute_Capture(sCommand, 10, True)
if arr(0) > 0 then bInheritanceError = True
sCommand = "icacls """ & sParentFolder & "\Profile"" /inheritance:e"
arr = Execute_Capture(sCommand, 10, True)
If arr(0) > 0 then bInheritanceError = True
sCommand = "icacls """ & sParentFolder & "\Profile.V2"" /inheritance:e"
arr = Execute_Capture(sCommand, 10, True)
if arr(0) > 0 then bInheritanceError = True

If bInheritanceError Then
	WScript.Echo "There was an error enabling inheritance using icacls.exe." & VbCrLf & VbCrLf & _
		"If you are executing this script from a system that is not running" & VbCrLf & _
		"Windows Server 2008 or Windows Vista SP1, then the error is expected: " & VbCrLf & _
		"older versions of icacls.exe do not support the /inheritance switch." & VbCrLf & VbCrLf & _
		"Once the script is complete, you must check to ensure inheritance is enabled" &VbCrLf & _
		"on the following folders: " & VbCrLf & _
		"    - " & sParentFolder & VbCrLf & _
		"    - " & sParentFolder & "\Profile" & VbCrLf & _
		"    - " & sParentFolder & "\Profile.V2" & VbCrLf & VbCrLf & _ 
	WScript.Echo
End If

' We've been creating all of these folders.  We need to ensure the user has full control and owns them.
sCommand = "icacls """ & sParentFolder & """ /grant " & sDomainNetBIOS &"\" & sUsername & ":(CI)(OI)F"
arr = Execute_Capture(sCommand, 10, True)
sCommand = "icacls """ & sParentFolder & """ /setowner " & sDomainNetBIOS &"\" & sUsername & " /T"
arr = Execute_Capture(sCommand, 10, True)

WScript.Echo sParentFolder & " provisioned."

Sub Create_Common_Objects()
	Set FSO = CreateObject("Scripting.FileSystemObject")
	Set WSHShell = CreateObject("Wscript.Shell")
End Sub

Sub Check_Arguments()
	On Error Resume Next
	If Right(WScript.Arguments(0),1) = "?" Then
		Call Usage()
		WScript.Quit
	End If
	sParentFolder = WScript.Arguments(0)
	If sParentFolder = "" Then 
		WScript.Echo "No parent folder provided"
		WScript.Echo
		Call Usage()
		WScript.Quit
	End If
	On Error GoTo 0
End Sub

Sub Usage()
		WScript.Echo "UDS_UserFolders_Provision"
		WScript.Echo "========================="
		WScript.Echo "Create user data stores for a user."
		WScript.Echo 
		WScript.Echo "USAGE:"
		WScript.Echo "   cscript.exe UDS_UserFolders_Provision.vbs UserFolderPath"
		WScript.Echo
		WScript.Echo "WHERE:"
		WScript.Echo
		WScript.Echo "UserFolderPath"
		WScript.Echo "--------------"
		WScript.Echo "Full local or network path to a user's folder,"
		WScript.Echo "e.g. E:\Users\jfine or \\server01\users$\jfine."
		WScript.Echo "The user's folder will be created if it does not already exist."
		WScript.Echo "It is assumed that the last folder in the path (e.g. jfine) is the user's"
		WScript.Echo "pre-Windows 2000 Logon Name. That account must already exist. It is given"
		WScript.Echo "ownership and Full Control of the folder"
		WScript.Echo
		WScript.Echo "Run the script from a Windows Vista SP1 or Windows Server 2008 system."
		WScript.Echo "Run locally on a Windows Server 2008 server as an adminsitrator."
		WScript.Echo "Run remotely gainst a Windows Server 2008 or Windows Server 2003 system"
		WScript.Echo "as a user with sufficient NTFS permissions to create the folders,"
		WScript.Echo "DFS namespace delegation to create the DFS namespace, and the"
		WScript.Echo "Restore Files And Directories user right to transfer ownership."
End Sub

Function FolderPath_Create(FolderPath)
	' VERSION 070918
	' Creates a folder path specified by FolderPath
	' and returns True (success) or False (failure)
	'
	' Recursively create a folder path
	' This is an "inside out" recursion that starts with the lowest level,
	' works its way "up" to the nearest ancestor that exists, then
	' creates folders down from there as it works its way out of recursions
	'
	' INPUT:	FolderPath:			desired folder path
	' OUTPUT:	FolderPath_Create:	TRUE: 	success
	'								FALSE:	failure
	
	Dim bFolderExists
	
	FolderPath_Create = False
	On Error Resume Next
	bFolderExists = FSO.FolderExists(FolderPath)
	If Err.Number <> 0 Then
		' This handles scenarios where a sharename in a UNC doesn't exist.
		' I was getting Out of Memory errors on the FolderExists method.
		FolderPath_Create = False
		Exit Function
	End If
	If Not bFolderExists Then
		' If the folder doesn't exist already, test its parent
		' (RECURSIVE CALL TO SELF)
		If FolderPath_Create(FSO.GetParentFolderName(FolderPath)) Then
			' Create the folder
			FolderPath_Create = True
			Call FSO.CreateFolder(FolderPath)
		End If
	Else
		' This level of folder does exist
		FolderPath_Create = True
	End If
End Function

Function Execute_Capture(ByVal sCommand, ByVal iTimeout, ByVal bTerminate)
	' VERSION 071112
	' Executes command in sCommand
	' Times out after iTimeout and (optionally) terminates the process
	' Returns exit code, StdOut & StdErr
	'
	' INPUTS:	sCommand: 			Command to run
	'			iTimeout:			Time (in seconds) to wait for process
	'			bTerminate:			TRUE  = terminate process after timeout
	'								FALSE = return from function
	' RETURNS:	Execute_Capture:	*ARRAY*
	'				(0): 			Exit code of command 
	'								0.01 = timed out but NOT terminated
	'								0.99 = timed out and TERMINATED
	'				(1):			StdOut
	'				(2):			StdErr
	
	Dim oExec, iTimer, iExitCode, sOut, sErr

	On Error Resume Next
	Set oExec = WSHShell.Exec(sCommand)
	If Err.Number<>0 Then
		' Could not successfully run command
		iExitCode = 500
		sOut = ""
		sErr = "Could not execute command: " & VbCrLf & _
			sCommand & VbCrLf & Err.Description
		Execute_Capture = Array(iExitCode, sOut, sErr)
		Exit Function
	End If
	On Error GoTo 0
	
	iTimer = 0
	Do While oExec.Status = 0
		WScript.Sleep 100
		iTimer = iTimer + 100
		If (iTimer/1000) > iTimeout Then Exit Do
	Loop
	
	If oExec.Status = 0 Then
		' Not completed, but timed out
		If bTerminate Then
			' Terminate
			oExec.Terminate
			iExitCode = 0.99
		Else
			' Timeout but do not terminate
			iExitCode = 0.01
		End If
	Else
		' Completed
		iExitCode = oExec.ExitCode
	End If

	sOut = oExec.StdOut.ReadAll
	sErr = oExec.StdErr.ReadAll
	Execute_Capture = Array(iExitCode, sOut, sErr)
	
End Function

'' SIG '' Begin signature block
'' SIG '' MIIkCAYJKoZIhvcNAQcCoIIj+TCCI/UCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFIrRkKaycE3U
'' SIG '' R5PY8knEN7V75nhYoIIe4TCCBBIwggL6oAMCAQICDwDB
'' SIG '' AIs8PIgR0T72Y+zfQDANBgkqhkiG9w0BAQQFADBwMSsw
'' SIG '' KQYDVQQLEyJDb3B5cmlnaHQgKGMpIDE5OTcgTWljcm9z
'' SIG '' b2Z0IENvcnAuMR4wHAYDVQQLExVNaWNyb3NvZnQgQ29y
'' SIG '' cG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBSb290
'' SIG '' IEF1dGhvcml0eTAeFw05NzAxMTAwNzAwMDBaFw0yMDEy
'' SIG '' MzEwNzAwMDBaMHAxKzApBgNVBAsTIkNvcHlyaWdodCAo
'' SIG '' YykgMTk5NyBNaWNyb3NvZnQgQ29ycC4xHjAcBgNVBAsT
'' SIG '' FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMY
'' SIG '' TWljcm9zb2Z0IFJvb3QgQXV0aG9yaXR5MIIBIjANBgkq
'' SIG '' hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQK9wXDmO/JO
'' SIG '' Gyifl3heMOqiqY0lX/j+lUyjt/6doiA+fFGim6KPYDJr
'' SIG '' 0UJkee6sdslU2vLrnIYcj5+EZrPFa3piI9YdPN4PAZLo
'' SIG '' lsS/LWaammgmmdA6LL8MtVgmwUbnCj44liypKDmo7EmD
'' SIG '' QuOED7uabFVhrIJ8oWAtd0zpmbRkO5pQHDEIJBSfqeeR
'' SIG '' KxjmPZhjFGBYBWWfHTdSh/en75QCxhvTv1VFs4mAvzrs
'' SIG '' VJROrv2nem10Tq8YzJYJKCEAV5BgaTe7SxIHPFb/W/uk
'' SIG '' ZgoIptKBVlfvtjteFoF3BNr2vq6Alf6wzX/WpxpyXDzK
'' SIG '' vPAIoyIwswaFybMgdxOF3wIDAQABo4GoMIGlMIGiBgNV
'' SIG '' HQEEgZowgZeAEFvQcO9pcp4jUX4Usk2O/8uhcjBwMSsw
'' SIG '' KQYDVQQLEyJDb3B5cmlnaHQgKGMpIDE5OTcgTWljcm9z
'' SIG '' b2Z0IENvcnAuMR4wHAYDVQQLExVNaWNyb3NvZnQgQ29y
'' SIG '' cG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBSb290
'' SIG '' IEF1dGhvcml0eYIPAMEAizw8iBHRPvZj7N9AMA0GCSqG
'' SIG '' SIb3DQEBBAUAA4IBAQCV6AvAjfOXGDXtuAEk2HcR81xg
'' SIG '' Mp+eC8s+BZGIj8k65iHy8FeTLLWgR8hi7/zXzDs7Wqk2
'' SIG '' VGn+JG0/ycyq3gV83TGNPZ8QcGq7/hJPGGnA/NBD4xFa
'' SIG '' IE/qYnuvqhnIKzclLb5loRKKJQ9jo/dUHPkhydYV81Ks
'' SIG '' bkMyB/2CF/jlZ2wNUfa98VLHvefEMPwgMQmIHZUpGk3V
'' SIG '' HQKl8YDgA7Rb9LHdyFfuZUnHUlS2tAMoEv+Q1vAIj364
'' SIG '' l8WrNyzkeuSod+N2oADQaj/B0jaK4EESqDVqG2rbNeHU
'' SIG '' HATkqEUEyFozOG5NHA1itwqijNPVVD9GzRxVpnDbEjqH
'' SIG '' k3Wfp9KgMIIEEjCCAvqgAwIBAgIPAMEAizw8iBHRPvZj
'' SIG '' 7N9AMA0GCSqGSIb3DQEBBAUAMHAxKzApBgNVBAsTIkNv
'' SIG '' cHlyaWdodCAoYykgMTk5NyBNaWNyb3NvZnQgQ29ycC4x
'' SIG '' HjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEh
'' SIG '' MB8GA1UEAxMYTWljcm9zb2Z0IFJvb3QgQXV0aG9yaXR5
'' SIG '' MB4XDTk3MDExMDA3MDAwMFoXDTIwMTIzMTA3MDAwMFow
'' SIG '' cDErMCkGA1UECxMiQ29weXJpZ2h0IChjKSAxOTk3IE1p
'' SIG '' Y3Jvc29mdCBDb3JwLjEeMBwGA1UECxMVTWljcm9zb2Z0
'' SIG '' IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQg
'' SIG '' Um9vdCBBdXRob3JpdHkwggEiMA0GCSqGSIb3DQEBAQUA
'' SIG '' A4IBDwAwggEKAoIBAQCpAr3BcOY78k4bKJ+XeF4w6qKp
'' SIG '' jSVf+P6VTKO3/p2iID58UaKboo9gMmvRQmR57qx2yVTa
'' SIG '' 8uuchhyPn4Rms8VremIj1h083g8BkuiWxL8tZpqaaCaZ
'' SIG '' 0Dosvwy1WCbBRucKPjiWLKkoOajsSYNC44QPu5psVWGs
'' SIG '' gnyhYC13TOmZtGQ7mlAcMQgkFJ+p55ErGOY9mGMUYFgF
'' SIG '' ZZ8dN1KH96fvlALGG9O/VUWziYC/OuxUlE6u/ad6bXRO
'' SIG '' rxjMlgkoIQBXkGBpN7tLEgc8Vv9b+6RmCgim0oFWV++2
'' SIG '' O14WgXcE2va+roCV/rDNf9anGnJcPMq88AijIjCzBoXJ
'' SIG '' syB3E4XfAgMBAAGjgagwgaUwgaIGA1UdAQSBmjCBl4AQ
'' SIG '' W9Bw72lyniNRfhSyTY7/y6FyMHAxKzApBgNVBAsTIkNv
'' SIG '' cHlyaWdodCAoYykgMTk5NyBNaWNyb3NvZnQgQ29ycC4x
'' SIG '' HjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEh
'' SIG '' MB8GA1UEAxMYTWljcm9zb2Z0IFJvb3QgQXV0aG9yaXR5
'' SIG '' gg8AwQCLPDyIEdE+9mPs30AwDQYJKoZIhvcNAQEEBQAD
'' SIG '' ggEBAJXoC8CN85cYNe24ASTYdxHzXGAyn54Lyz4FkYiP
'' SIG '' yTrmIfLwV5MstaBHyGLv/NfMOztaqTZUaf4kbT/JzKre
'' SIG '' BXzdMY09nxBwarv+Ek8YacD80EPjEVogT+pie6+qGcgr
'' SIG '' NyUtvmWhEoolD2Oj91Qc+SHJ1hXzUqxuQzIH/YIX+OVn
'' SIG '' bA1R9r3xUse958Qw/CAxCYgdlSkaTdUdAqXxgOADtFv0
'' SIG '' sd3IV+5lScdSVLa0AygS/5DW8AiPfriXxas3LOR65Kh3
'' SIG '' 43agANBqP8HSNorgQRKoNWobats14dQcBOSoRQTIWjM4
'' SIG '' bk0cDWK3CqKM09VUP0bNHFWmcNsSOoeTdZ+n0qAwggRg
'' SIG '' MIIDTKADAgECAgouqxHcUP9cncvAMAkGBSsOAwIdBQAw
'' SIG '' cDErMCkGA1UECxMiQ29weXJpZ2h0IChjKSAxOTk3IE1p
'' SIG '' Y3Jvc29mdCBDb3JwLjEeMBwGA1UECxMVTWljcm9zb2Z0
'' SIG '' IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQg
'' SIG '' Um9vdCBBdXRob3JpdHkwHhcNMDcwODIyMjIzMTAyWhcN
'' SIG '' MTIwODI1MDcwMDAwWjB5MQswCQYDVQQGEwJVUzETMBEG
'' SIG '' A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
'' SIG '' ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
'' SIG '' MSMwIQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5n
'' SIG '' IFBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
'' SIG '' ggEBALd5fdZds0U5qDSsMdr5JTVJd8D7H57HRXHv0Ubo
'' SIG '' 1IzDa0xSYvSZAsNN2ElsLyQ+Zb/OI7cLSLd/dd1FvaqP
'' SIG '' DlDFJSvyoOcNIx/RQST6YpnPGUWlk0ofmc2zLyLDSi18
'' SIG '' b9kVHjuMORA53b0p9GY7LQEy//4nSKa1bAGHnPu6smN/
'' SIG '' gvlcoIGEhY6w8riUo884plCFFyeHTt0w9gA99Mb5PYG+
'' SIG '' hu1sOacuNPa0Lq8KfWKReGacmHMNhq/yxPMguU8SjWPL
'' SIG '' LNkyRRnuu0qWO1BTGM5mUXmqrYfIVj6fglCIbgWxNcF7
'' SIG '' JL1SZj2ZTswrfjNuhEcG0Z7QSoYCboYApMCH31MCAwEA
'' SIG '' AaOB+jCB9zATBgNVHSUEDDAKBggrBgEFBQcDAzCBogYD
'' SIG '' VR0BBIGaMIGXgBBb0HDvaXKeI1F+FLJNjv/LoXIwcDEr
'' SIG '' MCkGA1UECxMiQ29weXJpZ2h0IChjKSAxOTk3IE1pY3Jv
'' SIG '' c29mdCBDb3JwLjEeMBwGA1UECxMVTWljcm9zb2Z0IENv
'' SIG '' cnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgUm9v
'' SIG '' dCBBdXRob3JpdHmCDwDBAIs8PIgR0T72Y+zfQDAPBgNV
'' SIG '' HRMBAf8EBTADAQH/MB0GA1UdDgQWBBTMHc52AHBbr/Ha
'' SIG '' xE6aUUQuo0Rj8DALBgNVHQ8EBAMCAYYwCQYFKw4DAh0F
'' SIG '' AAOCAQEAe6uufkom8s68TnSiWCd0KnWzhv2rTJR4AE3p
'' SIG '' yusY3GnFDqJ88wJDxsqHzPhTzMKfvVZv8GNEqUQA7pbI
'' SIG '' mtUcuAufGQ2U19oerSl97+2mc6yP3jmOPZhqvDht0oiv
'' SIG '' I/3f6dZpCZGIvf7hALs08/d8+RASLgXrKZaTQmsocbc4
'' SIG '' j+AHDcldaM29gEFrZqi7t7uONMryAxB8evXS4ELfe/7h
'' SIG '' 4az+9t/VDbNw1pLjT7Y4onwt1D3bNAtiNwKfgWojifZc
'' SIG '' Y4+wWrs512CMVYQaM/U7mKCCDKJfi7Mst6Gly6vaILa/
'' SIG '' MBmFIBQNKrxS9EHgXjDjkihph8Fw4vOnq86AQnJ2DjCC
'' SIG '' BGowggNSoAMCAQICCmEPeE0AAAAAAAMwDQYJKoZIhvcN
'' SIG '' AQEFBQAweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
'' SIG '' c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
'' SIG '' BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEjMCEGA1UE
'' SIG '' AxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EwHhcN
'' SIG '' MDcwODIzMDAyMzEzWhcNMDkwMjIzMDAzMzEzWjB0MQsw
'' SIG '' CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
'' SIG '' MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
'' SIG '' b2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNyb3Nv
'' SIG '' ZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUA
'' SIG '' A4IBDwAwggEKAoIBAQCi2wqNz8LBSZvNqjo0rSNZa9ts
'' SIG '' viEit5TI6q6/xtUmwjIRi7zaXSz7NlYeFSuujw3dFKNu
'' SIG '' KEx/Fj9BrI1AsUaIDdmBlK2XBtBXRHZc6vH8DuJ/dKMz
'' SIG '' y3Tl7+NhoX4Dt0X/1T4S1bDKXg3Qe/K3Ew38YGoohXWM
'' SIG '' t628hegXtJC+9Ra2Yl3tEd867iFbi6+Ac8NF45WJd2Cb
'' SIG '' 5613wTeNMxQvE9tiya4aqU+YZ63UIDkwceCNZ0bixhz0
'' SIG '' DVB0QS/oBSRqIWtJsJLEsjnHQqVtXBhKq4/XjoM+eApH
'' SIG '' 2KSyhCPD4vJ7ZrFKdL0mQUucYRRgTjDIgvPQC3B87lVN
'' SIG '' d9IIVXaBAgMBAAGjgfgwgfUwDgYDVR0PAQH/BAQDAgbA
'' SIG '' MB0GA1UdDgQWBBTzIUCOfFH4VEuY5RfXaoM0BS4m6DAT
'' SIG '' BgNVHSUEDDAKBggrBgEFBQcDAzAfBgNVHSMEGDAWgBTM
'' SIG '' Hc52AHBbr/HaxE6aUUQuo0Rj8DBEBgNVHR8EPTA7MDmg
'' SIG '' N6A1hjNodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
'' SIG '' L2NybC9wcm9kdWN0cy9DU1BDQS5jcmwwSAYIKwYBBQUH
'' SIG '' AQEEPDA6MDgGCCsGAQUFBzAChixodHRwOi8vd3d3Lm1p
'' SIG '' Y3Jvc29mdC5jb20vcGtpL2NlcnRzL0NTUENBLmNydDAN
'' SIG '' BgkqhkiG9w0BAQUFAAOCAQEAQFdvU2eeIIM0AQ7mF0s8
'' SIG '' revYgX/uDXl0d0+XRxjzABVpfttikKL9Z6Gc5Cgp+lXX
'' SIG '' mf5Qv14Js7mm7YLzmB5vWfr18eEM04sIPhYXINHAtUVH
'' SIG '' CCZgVwlLlPAIzLpNbvDiSBIoNYshct9ftq9pEiSU7uk0
'' SIG '' Cdt+bm+SClLKKkxJqjIshuihzF0mvLw84Fuygwu6NRxP
'' SIG '' hEVH/7uUoVkHqZbdeL1Xf6WnTszyrZyaQeLLXCQ+3H80
'' SIG '' R072z8h7neu2yZxjFFOvrZrv17/PoKGrlcp6K4cswMfZ
'' SIG '' /GwD2r84rfHRXBkXD8D3yoCmEAga3ZAj57ChTD7qsBEm
'' SIG '' eA7BLLmka8ePPDCCBJ0wggOFoAMCAQICCmFHUroAAAAA
'' SIG '' AAQwDQYJKoZIhvcNAQEFBQAweTELMAkGA1UEBhMCVVMx
'' SIG '' EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
'' SIG '' ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
'' SIG '' dGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IFRpbWVzdGFt
'' SIG '' cGluZyBQQ0EwHhcNMDYwOTE2MDE1MzAwWhcNMTEwOTE2
'' SIG '' MDIwMzAwWjCBpjELMAkGA1UEBhMCVVMxEzARBgNVBAgT
'' SIG '' Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
'' SIG '' BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEnMCUG
'' SIG '' A1UECxMebkNpcGhlciBEU0UgRVNOOkQ4QTktQ0ZDQy01
'' SIG '' NzlDMScwJQYDVQQDEx5NaWNyb3NvZnQgVGltZXN0YW1w
'' SIG '' aW5nIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IB
'' SIG '' DwAwggEKAoIBAQCbbdyGUegyOzc6liWyz2/uYbVB0hg7
'' SIG '' Wp14Z7r4H9kIVZKIfuNBU/rsKFT+tdr+cDuVJ0h+Q6Ay
'' SIG '' LyaBSvICdnfIyan4oiFYfg29Adokxv5EEQU1OgGo6lQK
'' SIG '' MyyH0n5Bs+gJ2bC+45klprwl7dfTjtv0t20bSQvm08OH
'' SIG '' bu5GyX/zbevngx6oU0Y/yiR+5nzJLPt5FChFwE82a1Ma
'' SIG '' p4az5/zhwZ9RCdu8pbv+yocJ9rcyGb7hSlG8vHysLJVq
'' SIG '' l3PqclehnIuG2Ju9S/wnM8FtMqzgaBjYbjouIkPR+Y/t
'' SIG '' 8QABDWTAyaPdD/HI6VTKEf/ceCk+HaxYwNvfqtyuZRvT
'' SIG '' nbxnAgMBAAGjgfgwgfUwHQYDVR0OBBYEFE8YiYrSygB4
'' SIG '' xuxZDQ/9fMTBIoDeMB8GA1UdIwQYMBaAFG/oTj+XuTSr
'' SIG '' S4aPvJzqrDtBQ8bQMEQGA1UdHwQ9MDswOaA3oDWGM2h0
'' SIG '' dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3By
'' SIG '' b2R1Y3RzL3RzcGNhLmNybDBIBggrBgEFBQcBAQQ8MDow
'' SIG '' OAYIKwYBBQUHMAKGLGh0dHA6Ly93d3cubWljcm9zb2Z0
'' SIG '' LmNvbS9wa2kvY2VydHMvdHNwY2EuY3J0MBMGA1UdJQQM
'' SIG '' MAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIGwDANBgkq
'' SIG '' hkiG9w0BAQUFAAOCAQEANyce9YxA4PZlJj5kxJC8PuNX
'' SIG '' hd1DDUCEZ76HqCra3LQ2IJiOM3wuX+BQe2Ex8xoT3oS9
'' SIG '' 6mkcWHyzG5PhCCeBRbbUcMoUt1+6V+nUXtA7Q6q3P7ba
'' SIG '' YYtxz9R91Xtuv7TKWjCR39oKDqM1nyVhTsAydCt6BpRy
'' SIG '' AKwYnUvlnivFOlSspGDYp/ebf9mpbe1Ea7rc4BL68K2H
'' SIG '' DJVjCjIeiU7MzH6nN6X+X9hn+kZL0W0dp33SvgL/826C
'' SIG '' 84d0xGnluXDMS2WjBzWpRJ6EfTlu/hQFvRpQIbU+n/N3
'' SIG '' HI/Cmp1X4Wl9aeiDzwJvKiK7NzM6cvrWMB2RrfZQGusT
'' SIG '' 3jrFt1zNszCCBJ0wggOFoAMCAQICCmFJfO0AAAAAAAUw
'' SIG '' DQYJKoZIhvcNAQEFBQAweTELMAkGA1UEBhMCVVMxEzAR
'' SIG '' BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
'' SIG '' bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
'' SIG '' bjEjMCEGA1UEAxMaTWljcm9zb2Z0IFRpbWVzdGFtcGlu
'' SIG '' ZyBQQ0EwHhcNMDYwOTE2MDE1NTIyWhcNMTEwOTE2MDIw
'' SIG '' NTIyWjCBpjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
'' SIG '' c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
'' SIG '' BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEnMCUGA1UE
'' SIG '' CxMebkNpcGhlciBEU0UgRVNOOjEwRDgtNTg0Ny1DQkY4
'' SIG '' MScwJQYDVQQDEx5NaWNyb3NvZnQgVGltZXN0YW1waW5n
'' SIG '' IFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
'' SIG '' ggEKAoIBAQDqugVjyNl5roREPqWzxO1MniTfOXYeCdYy
'' SIG '' Slh40ivZpQeQ7+c9+70mfKP75X1+Ms/ZPYs5N/L42Ds0
'' SIG '' FtSSgvs07GiFchqP4LhM4LiF8zMKAsGidnM1TF3xt+FK
'' SIG '' fR24lHjb/x6FFUJGcc5/J1cS0YNPO8/63vaL7T8A49Xe
'' SIG '' YfkXjUukgTz1aUDq4Ym/B0+6dHvpDOVH6qts8dVngQj4
'' SIG '' Fsp9E7tz4glM+mL77aA5mjr+6xHIYR5iWNgKVIPVO0tL
'' SIG '' 4lW9L2AajpIFQ9pd64IKI5cJoAUxZYuTTh5BIaKSkP1F
'' SIG '' REVvNbFFN61pqWX5NEOxF8I7OeEQjPIah+NUUB87nTGt
'' SIG '' AgMBAAGjgfgwgfUwHQYDVR0OBBYEFH5y8C4/VingJfdo
'' SIG '' uAH8S+F+z+M+MB8GA1UdIwQYMBaAFG/oTj+XuTSrS4aP
'' SIG '' vJzqrDtBQ8bQMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6
'' SIG '' Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
'' SIG '' Y3RzL3RzcGNhLmNybDBIBggrBgEFBQcBAQQ8MDowOAYI
'' SIG '' KwYBBQUHMAKGLGh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
'' SIG '' bS9wa2kvY2VydHMvdHNwY2EuY3J0MBMGA1UdJQQMMAoG
'' SIG '' CCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIGwDANBgkqhkiG
'' SIG '' 9w0BAQUFAAOCAQEAaXqCCQwW0d7PRokuv9E0eoF/JyhB
'' SIG '' KvPTIZIOl61fU14p+e3BVEqoffcT0AsU+U3yhhUAbuOD
'' SIG '' HShFpyw5Mt1vmjda7iNSj1QDjT+nnGQ49jbIFEO2Oj6Y
'' SIG '' yQ3DcYEo82anMeJcXY/5UlLhXOuTkJ1pCUyJ0dF2TDQN
'' SIG '' auF8RKcrW4NUf0UkGSXEikbFJeMZgGkpFPYXxvAiLIFG
'' SIG '' Xiv0+abGdz4jb/mmZIWOomINqS0eqOWQPn//sI78l+zx
'' SIG '' /QSvzUnOWnSs+vMTHxs5zqO01rz0tO7IrfJWHvs88cjW
'' SIG '' KkS8v5w/fWYYzbIgYwrKQD1lMhl8srg9wSZITiIZmW6M
'' SIG '' MMHxkTCCBJ0wggOFoAMCAQICEGoLmU/AACWrEdtFH1h6
'' SIG '' Z6IwDQYJKoZIhvcNAQEFBQAwcDErMCkGA1UECxMiQ29w
'' SIG '' eXJpZ2h0IChjKSAxOTk3IE1pY3Jvc29mdCBDb3JwLjEe
'' SIG '' MBwGA1UECxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
'' SIG '' HwYDVQQDExhNaWNyb3NvZnQgUm9vdCBBdXRob3JpdHkw
'' SIG '' HhcNMDYwOTE2MDEwNDQ3WhcNMTkwOTE1MDcwMDAwWjB5
'' SIG '' MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
'' SIG '' bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
'' SIG '' cm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNy
'' SIG '' b3NvZnQgVGltZXN0YW1waW5nIFBDQTCCASIwDQYJKoZI
'' SIG '' hvcNAQEBBQADggEPADCCAQoCggEBANw3bvuvyEJKcRjI
'' SIG '' zkg+U8D6qxS6LDK7Ek9SyIPtPjPZSTGSKLaRZOAfUIS6
'' SIG '' wkvRfwX473W+i8eo1a5pcGZ4J2botrfvhbnN7qr9EqQL
'' SIG '' WSIpL89A2VYEG3a1bWRtSlTb3fHev5+Dx4Dff0wCN5T1
'' SIG '' wJ4IVh5oR83ZwHZcL322JQS0VltqHGP/gHw87tUEJU05
'' SIG '' d3QHXcJc2IY3LHXJDuoeOQl8dv6dbG564Ow+j5eecQ5f
'' SIG '' Kk8YYmAyntKDTisiXGhFi94vhBBQsvm1Go1s7iWbE/jL
'' SIG '' ENeFDvSCdnM2xpV6osxgBuwFsIYzt/iUW4RBhFiFlG6w
'' SIG '' HyxIzG+cQ+Bq6H8mjmsCAwEAAaOCASgwggEkMBMGA1Ud
'' SIG '' JQQMMAoGCCsGAQUFBwMIMIGiBgNVHQEEgZowgZeAEFvQ
'' SIG '' cO9pcp4jUX4Usk2O/8uhcjBwMSswKQYDVQQLEyJDb3B5
'' SIG '' cmlnaHQgKGMpIDE5OTcgTWljcm9zb2Z0IENvcnAuMR4w
'' SIG '' HAYDVQQLExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
'' SIG '' BgNVBAMTGE1pY3Jvc29mdCBSb290IEF1dGhvcml0eYIP
'' SIG '' AMEAizw8iBHRPvZj7N9AMBAGCSsGAQQBgjcVAQQDAgEA
'' SIG '' MB0GA1UdDgQWBBRv6E4/l7k0q0uGj7yc6qw7QUPG0DAZ
'' SIG '' BgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8E
'' SIG '' BAMCAYYwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0B
'' SIG '' AQUFAAOCAQEAlE0RMcJ8ULsRjqFhBwEOjHBFje9zVL0/
'' SIG '' CQUt/7hRU4Uc7TmRt6NWC96Mtjsb0fusp8m3sVEhG28I
'' SIG '' aX5rA6IiRu1stG18IrhG04TzjQ++B4o2wet+6XBdRZ+S
'' SIG '' 0szO3Y7A4b8qzXzsya4y1Ye5y2PENtEYIb923juasxtz
'' SIG '' niGI2LS0ElSM9JzCZUqaKCacYIoPO8cTZXhIu8+tgzpP
'' SIG '' sGJY3jDp6Tkd44ny2jmB+RMhjGSAYwYElvKaAkMve0aI
'' SIG '' uv8C2WX5St7aA3STswVuDMyd3ChhfEjxF5wRITgCHIes
'' SIG '' BsWWMrjlQMZTPb2pid7oZjeN9CKWnMywd1RROtZyRLIj
'' SIG '' 9jGCBJMwggSPAgEBMIGHMHkxCzAJBgNVBAYTAlVTMRMw
'' SIG '' EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
'' SIG '' b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
'' SIG '' b24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25p
'' SIG '' bmcgUENBAgphD3hNAAAAAAADMAkGBSsOAwIaBQCggb4w
'' SIG '' GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
'' SIG '' BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
'' SIG '' AQkEMRYEFIdSlDJSLTeSAlpmMxLVpjFoQnWtMF4GCisG
'' SIG '' AQQBgjcCAQwxUDBOoCaAJABNAGkAYwByAG8AcwBvAGYA
'' SIG '' dAAgAEwAZQBhAHIAbgBpAG4AZ6EkgCJodHRwOi8vd3d3
'' SIG '' Lm1pY3Jvc29mdC5jb20vbGVhcm5pbmcgMA0GCSqGSIb3
'' SIG '' DQEBAQUABIIBAGcNNNpUd/Ka8L4sfCMLsCBavnHUVev+
'' SIG '' DBsvhajrgdUYXtHlSGysohUOnoRWigz3oz6L89wUsMT0
'' SIG '' c+VBVE1N5naWsHPqqmALwQXid+Pd98cA3n2vZTYXcPNL
'' SIG '' a4l0KZ7XTQIOzDpauQn6lUXS+tvO+eKqX0ZyiKpLg1hS
'' SIG '' A9DcX6dZpjyVHFGZwQj3LoJhNDaqJIW0ufY7L8Htzcyg
'' SIG '' GeBo7nc1oSzT07yqps6UInw52EIIY6ppxkahwaLyww5n
'' SIG '' p7pjoidJsB5eJAbRdQ3B7R+1JXEv8rFZjvpS1GKmm9R4
'' SIG '' j9a08ehETj9no4xtsE0Y7UEfTrMTxrF/DU8g/8acgN7Y
'' SIG '' HY+hggIfMIICGwYJKoZIhvcNAQkGMYICDDCCAggCAQEw
'' SIG '' gYcweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
'' SIG '' bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
'' SIG '' FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMa
'' SIG '' TWljcm9zb2Z0IFRpbWVzdGFtcGluZyBQQ0ECCmFJfO0A
'' SIG '' AAAAAAUwBwYFKw4DAhqgXTAYBgkqhkiG9w0BCQMxCwYJ
'' SIG '' KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0wODAyMDUw
'' SIG '' MjAxMDNaMCMGCSqGSIb3DQEJBDEWBBSNBEK4GRTiIcjx
'' SIG '' ncCc/7OLS89prTANBgkqhkiG9w0BAQUFAASCAQB/T0T5
'' SIG '' 11j/5BjCKo6jlXU/imWrKLWJFBo5FI22TnPRJ0VIksFB
'' SIG '' gKOGcCGfriyezl/C2bvDWVZtVVNMSe7nSi46WiiAhdv7
'' SIG '' QMkDw8SSI94L/2fRjEhLmVqaOQ7BdWLK3IfjGZ3q3Ayo
'' SIG '' EHct+t+8yRXKd9D94FkLvfk4aH+DPggfYjEoYM/oqM4M
'' SIG '' CEQnMPSvC9esGi+H9mSE9rEsP4yijj9k7bJjqcVBHTYp
'' SIG '' +okX4z/NI7CRkAfLfKuPkNsFoWb0UKVopDRTAw9OMXII
'' SIG '' EOdm37S95xAplN9Wv7bbFrgXeLTKPJsnyr/vbtiC181o
'' SIG '' Kq5bPDN+vtJ4c6lkjY2ZQcNJDQ+L
'' SIG '' End signature block

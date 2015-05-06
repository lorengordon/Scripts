'==========================================================================
'
' VBScript Source File -- Created with SAPIEN Technologies PrimalScript 2007
'
' NAME: Foldler_Synch.vbs
'
' AUTHOR: Dan Holme , Intelliem
' DATE  : 9/17/2007
'
' Synchronizes two folders using Robocopy.
' Has many applications as described in the 
' Windows Administration Resource Kit
' See the resource kit for documentation
'
' Neither Microsoft nor Intelliem guarantee the performance
' of scripts, scripting examples or tools.
'
' See www.intelliem.com/resourcekit for updates to this script
'
' (c) 2007 Intelliem, Inc
'==========================================================================

Const Robocopy_OK_Synched = 00			' no errors and no copying - source and destination are synched
Const Robocopy_OK_Copied = 01			' one or more files were copied
Const Robocopy_OK_ExtraFilesOrDirs = 02	' extra files or directories were detected - examine the output log
Const Robocopy_OK_Mismatched = 04		' mismatched files or directories detected - examine the output log
Const Robocopy_ERR_Skipped = 08			' some files or folders not copied due to error or retry limit
Const Robocopy_ERR_Serious = 16			' no copying due to usage or access denied Error
Const FileAttrib_Hidden = 2
Const FileAttrib_System = 4

' Set global objects and variables
Set WSHShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
sUser = WSHShell.ExpandEnvironmentStrings("%username%")
sUserProfile = WSHShell.ExpandEnvironmentStrings("%userprofile%")

'==========================================================================
' CONFIGURATION BLOCK

' ROBOCOPY CONFIGURATION
' Include path to robocopy if not in the system path (e.g. system32)
sRobocopy = "robocopy.exe"
' Robocopy options (/MIR is hardwired later in the code)
' The script uses /COPY:DATSO which copies all attributes
' including the Data, Attributes, Timestamps, 
' Security (NTFS ACLs), and Ownership.
' It is not using the U option (or /COPYALL) because
' standard users don't have rights to copy auditing settings
sRobocopyOptions = "/COPY:DATSO /R:1 /W:30"
' How long (in minutes) to allow Robocopy to run 
' before terminating the process
iRobocopyTimeout = 10

' TARGET (SERVER) BACKUP/SYNCH FOLDER CONFIGURATION
' The root folder on the server for user sync folders
' You may need to add logic to determine this path if your
' users are not under a single share or DFS folder.
sUserSyncRoot = "\\contoso.com\users\" & sUser & "\backups"

' LOCAL FOLDERS ALLOWED TO BE SYNCHED
' The next three variables control which folders are allowed
' to be synched. When synched, all child folders are included
' because the Robocopy /MIR switch is hard-coded in the routine
' The local root folders under which sync folders are allowed.
' Folders in other namespaces will not be able to be synch'ed.
sUserLocalRoot = sUserProfile
' These subfolders of the root folder are allowed to be synched.
' The result will be that sUserSyncRoot has a structure of these
' subfolders just as the local user profile does.
aSyncFolders = Array("Local Files","Music","Videos","Pictures","Desktop")
' If the following flag is True, users can synch any subfolder
' of the folders listed in aSyncFolders.
' If False, then users can only sync the "top level" folders--
' those listed in aSyncFolders.
bSyncSubFolders = True
' So the RESULT is that folders matching this pattern can
' be synched:
' <sUserLocalRoot>\<any one of aSyncFolders>\[subfolder]
' where [subfolder] can be synched only if bSyncSubFolders is True
' These three variables and the Source Folder Validation work together.

' LOGGING CONFIGURATION
' Name for synch log. 
sSyncLogFileName = "_Contoso Synchronization Log.txt"
' Set hidden attribute on synch Log
' Requires the folder option "Show hidden files and folders" to "see" the log
bHideLog = True
' Set hidden & system attribute on synch Log
' Requires deselecting the folder option 
' "Hide protected operating system files" to see the log
bSuperhideLog = False
' The log will be prepended with the results of each synch log.
' Specify the maximum size of the log, in KB
' When the log exceeds this size, the "oldest" 25% of the log is purged.
iSyncLogMaxSize = 2048 ' 2MB
' The following describes how sections can be recognized within the log.
' It is used when log overflow results in the need to purge the log,
' so that purging grabs entire sections. 
' If you change what is written to the logs in the code, 
' you should change this accordingly.
' BUT it is cosemetic, only, so if you make a mistake, 
' it will just mean the logs are chopped off in less aesthetic places. 
sLogSectionMarker = VbCrLf & VbCrLf & VbCrLf & String(80, "=")

' SELF MANAGEMENT CONFIGURATION
' The script supports adding a flag file to the folder to indicate
' a successful or failed synchronization attempt. 
sSuccessFlagFile = "_Contoso Synchronization Success.txt"
sFailureFlagFile = "_Contoso Synchronization Failure.txt"
' Code is included that causes the script to exit if the
' most recent successful synchronization was within the
' numer of days specified by iBackupInterval.
' That way, back up happens only if that interval has been
' reached or exceeded.  
' This appies only in non-interactive (cscript) mode
' to support automation of the script as a scheduled task
' or startup/logon/logoff/shutdown script.
' If the user launches the script manually, it will prompt the user
' but will allow syncrhonization.
iBackupInterval = 5
' END CONFIGURATION BLOCK
'==========================================================================

' DETERMINE WHETHER SCRIPT IS RUNNING INTERACTIVELY
' This uses a check to see if the script was called with cscript
' and assumes, if it was, that the script should not run interactively
' and, if it was not, that the script should run interactively.
' You may want to have more sophisticated logic here.
' If interactive, messages are popups.
' If not, they are WScript.Echo'ed.
bInteractive = (WScript.FullName <> WScript.Path & "\cscript.exe")

' EVALUATE SOURCE & DESTINATION
If Not bInteractive Then
	sSource = WScript.Arguments.Named("source")
	sTarget = WScript.Arguments.Named("target")
Else
	' Not interactive - called from WScript
	If WScript.Arguments.Count = 0 Then
		' The script has been double-clicked 
		' or otherwise called with no arguments.
		' This supports a scenario in which user runs the script "Back Up This".
		' We assume, then, that we are to back up the script's parent folder.
		sSource = FSO.GetParentFolderName(Wscript.ScriptFullName)
	Else
		' The script has been called from WScript with an argument.
		' This supports adding the script as a shell command
		' for folders in Explorer, by adding a key to the Folder key
		' in HKEY_CLASSES_ROOT,
		' where the command should be
		' wscript.exe <path to script> %1
		sSource = WScript.Arguments(0)
	End If
	
	' SOURCE FOLDER VALIDATION
	' Make sure that the specified source folder is allowed to be synched
	bAllowed = False
	For Each sSyncFolder In aSyncFolders
		' For each subfolder specified in aSyncFolders
		' underneath the root specified by sUserLocalRoot
		' check to see if there's a match with the sSource
		sAllowedFolder = sUserLocalRoot & "\" & sSyncFolder
		If StrComp(Left(sSource, Len(sAllowedFolder)), sAllowedFolder, vbTextCompare) = 0 Then
			If ((bSyncSubFolders) Or  _
				(Len(sSource) = Len(sAllowedFolder))) Then
				bAllowed = True
				Exit For
			End If
		End If
	Next
	If Not bAllowed Then
		sMessage =  "Synchronizing is not allowed for this folder" & VbCrLf & _
					"SOURCE: " & sSource
		Call Notify(sMessage, "ERROR SYNCRHONIZING", 30, 64)
		WScript.Quit(501)
	End If			
	sTarget = sUserSyncRoot & Mid(sSource, Len(sUserLocalRoot)+1)
End If

If Not FSO.FolderExists(sSource) Then
	sMessage =  "Source folder does not exist" & VbCrLf & _
				"SOURCE: " & sSource
	Call Notify(sMessage, "ERROR SYNCRHONIZING", 30, 64)
	WScript.Quit(501)
End If
If Not FolderPath_Create(sTarget) Then
	sMessage =  "Target folder does not exist and cannot be created" & VbCrLf & _
				"TARGET: " & sTarget
	Call Notify(sMessage, "ERROR SYNCRHONIZING", 30, 64)
	WScript.Quit(501)
End If

' Self-management. Check flag file for most recent successful synch.
sSuccessFlag = sSource & "\" & sSuccessFlagFile
sFailureFlag = sSource & "\" & sFailureFlagFile
If FSO.FileExists(sSuccessFlag) Then
	Set oFile = FSO.GetFile(sSuccessFlag)
	dLastSuccess = oFile.DateCreated
	iInterval = Int(dLastSuccess - Now())
	WScript.Echo "Days since last backup: " & iInterval
	WScript.Quit
End If

' Unhide the log to avoid write errors
sSyncLogFile = sSource & "\" & sSyncLogFileName
If FSO.FileExists(sSyncLogFile) Then 
	Set oFile = FSO.GetFile(sSyncLogFile)
	oFile.Attributes = 0
	Set oFile = Nothing
End If

' Notify that operation is about to begin
sMessage =  "SOURCE: " & sSource & VbCrLf & _
			"TARGET: " & sTarget & VbCrLf & VbCrLf 
If bInteractive Then
			sMessage = sMessage & _
			"Synchronization will begin in 30 seconds, " & _
			"or when you click OK." & VbCrLf & VbCrLf 
End If			
			sMessage = sMessage &  _
			"Synchronization will proceed in the background, " & _
			"and may take some time (up to " & iRobocopyTimeout & " minutes)." & VbCrLf & VbCrLf & _
			"You will be notified when synchronization is complete." & VbCrLf & VbCrLf & _
			"You may continue to work during synchronization, " & _
			"but you should not open or work with files in the source folder."
Call Notify(sMessage, "Synchronization Operation", 30, 128)

' Run Robocopy, capturing the time started and time finished			
sCommand = """" & sRobocopy & """ """ & sSource & """ """ & sTarget & """ /MIR " & sRobocopyOptions
dStartDate = Now()
aResults = Execute_Capture(sCommand, iRobocopyTimeout * 60, True)
dEndDate = Now()

iResults = aResults(0)
bError = False
sMessage = ""

If iResults = 0 Then
	' Folder is synchronized
	bError = False
ElseIf iResults < Robocopy_ERR_Skipped Then
	' Results from Robocopy indicate changes were made.
	' Anything between 1 and 7 indicates changes were made.
	' So that we don't have to look through the log, we will
	' run robocopy again and check to see that synchronization is complete
	sCommand = """" & sRobocopy & """ """ & sSource & """ """ & sTarget & """ /MIR /R:1 /W:30"
	aResultsTest = Execute_Capture(sCommand, iRobocopyTimeout * 60, True)
	If aResultsTest(0) = 0 Then
		' We're in synch now.
		bError = False
	Else
		' We're still not in synch. Something is wrong.
		bError = True
	End If
Else
	' Anything >=8 means there was in fact an error synchronizing
	bError = True
End If

If Not bError Then
	' FULLY SYNCHED
	sMessage =  "Synchronized" & VbCrLf & _
				"SOURCE: " & sSource & VbCrLf & "TARGET: " & sTarget
	sLogMsg = 	String(80,"=") & VbCrLf & _
				"SUCCESS: FULLY SYNCHRONIZED" & VbCrLf & _
				"Source:  " & sSource & VbCrLf & _
				"Target:  " & sTarget & VbCrLf & _
				"Start:   " & dStartDate & VbCrLf & _
				"Finish:  " & dEndDate & VbCrLf & _
				"Code:    " & iResults & VbCrLf & _
				String(80,"=") & VbCrLf & VbCrLf
Else
	' NOT FULLY SYNCHED
	sMessage =  "Did not successfully synchronize:" & VbCrLf & _
				sSource & VbCrLf & "TO" & VbCrLf & sTarget
	sLogMsg = 	String(80,"=") & VbCrLf & _
				"ERROR:   SYNCHRONIZATION PROBLEM (" & iResults & ")" & VbCrLf & _
				"Source:  " & sSource & VbCrLf & _
				"Target:  " & sTarget & VbCrLf & _
				"Start:   " & dStartDate & VbCrLf & _
				"Finish:  " & dEndDate & VbCrLf & _
				"Code:    " & iResults & VbCrLf & _
				VbCrLf & _
				String (80,"-") & aResults(1) & VbCrLf & _
				String (80,"-") & aResults(2) & VbCrLf & _
				VbCrLf & _
				String(80,"=") & VbCrLf & VbCrLf
End If	

' Write the message to the log
ret = WriteFile_Prepend(sSyncLogFile, sLogMsg, False)

If ret Then
	' Log successfully updated.
	' Purge Log
	ret = TextFile_Purge(sSyncLogFile, iSyncLogMaxSize, 25, _
						 "bottom", sLogSectionMarker)
	If ret <= 2 Then
		' Purged log successfully or no purge needed
	Else
		' Problem purging Log
		sMessage = 	sMessage & VbCrLf & VbCrLf & _
					"Error " & ret & " purging the synchronization log." & _
					VbCrLf & sSyncLogFile
		bError = True
	End If	
	
	' Make sure log is superhidden
	Set oLog = FSO.GetFile(sSyncLogFile)
	If bHideLog Then _
		oLog.Attributes = oLog.Attributes Or FileAttrib_Hidden
	If bSuperhideLog Then
		oLog.Attributes = oLog.Attributes Or FileAttrib_Hidden
		oLog.Attributes = oLog.Attributes Or FileAttrib_System
	End If
	
	' Copy synchronization log to destination.
	' The xcopy command is using only the /h option
	' not the /o or /x options (which copy security settings)
	' so that it can run more easily under user credentials
	sCommand = "xcopy.exe """ & sSyncLogFile & """ """ & sTarget & """" & _
			   " /h /y"
	aResults = Execute_Capture(sCommand, 10, True)
	If aResults(0) = 0 Then
		' Copied log to destination successfully
	Else
		' Error copying up the synch log
		sMessage = 	sMessage & VbCrLf & _
					"Error copying synchronization log to server:" & VbCrLf & sCommand & VbCrLf & _
					aResults(2)
		bError = True
	End If
	
Else
	' Could not update local copy of log
	sMessage = 	sMessage & VbCrLf & VbCrLf & _
				"Error updating log information in " & VbCrLf & sSyncLogFile & VbCrLf & _
	bError = True
	' Note the way the code is structured right now, the log file
	' will remain UNhidden at this point.  It is only hidden by the
	' code above if the log was successfully updated.
	' This allows for easier troubleshooting.
End If

If Not bError Then
	' All went well
	sMessage =  "SUCCESSFUL synchronization" & VbCrLf & VbCrLf & _
				sMessage
	Call Notify (sMessage, "Synchronization Notification", 60, 128)
Else
	sMessage = 	"ERROR encountered during synchronization" & VbCrLf & VbCrLf & _
				sMessage
	Call Notify (sMessage, "Synchronization Notification", 60, 64)
	WSHShell.Run ("notepad.exe """ & sSyncLogFile & """")
End If
	

Function Execute_Capture(ByVal sCommand, ByVal iTimeout, ByVal bTerminate)
	' VERSION 070918
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
	
	Set oExec = WSHShell.Exec(sCommand)
	
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

Function WriteFile_Prepend(ByVal FilePath, ByVal Text, ByVal Overwrite)
	WriteFile_Prepend = False
	
	Const ForReading = 1, ForWriting = 2, ForAppending = 8, TristateUseDefault = -2
	Dim FSO, oFile, IOMode, sFileText, oFileText
	
	If Overwrite Then 
		IOMode = ForWriting
	Else
		IOMode = ForAppending
	End If
	
	Set FSO = CreateObject("Scripting.FileSystemObject")
	If FSO.FolderExists( FSO.GetParentFolderName(FilePath) ) Then
		If FSO.FileExists(FilePath) Then
			Set oFile = FSO.OpenTextFile(FilePath, ForReading)
			sFileText = oFile.ReadAll
			Text = Text & VbCrLf & sFileText
			Set oFile = Nothing
		End If
		' On Error Resume Next
		Set oFile = FSO.CreateTextFile(FilePath, True, False)
		oFile.Write Text
		oFile.Close
		If Err Then
			Err.Clear
			WriteFile_Prepend = False
		Else
			WriteFile_Prepend = True
		End If
	End If
	
End Function

Function TextFile_Purge (ByVal FilePath, ByVal MaxSize, ByVal PurgePercent, _
	ByVal TopBottom, ByVal Marker)
	' If the file specified by FilePath is bigger than MaxSize,
	' the file's contents are truncated by a percentage approximately
	' equal to PurgePercent, either at the beginning (top) or end (bottom)
	' of the file.
	' Additionally, a marker can be set to specify text to find within
	' the file as the start/end of the area to purge
	
	Const ForReading = 1, ForWriting = 2, ForAppending = 8, TristateUseDefault = -2
	Dim FSO, oFile, sFileText, oFileText

	Select Case UCase(TopBottom)
		Case "TOP"
			bTop = True
		Case "BOTTOM"
			bTop = False
		Case Else
			' Error bad parameter
			TextFile_Purge = 4
			Exit Function
	End Select
	
	If (PurgePercent<1 Or PurgePercent >99) Then
		' Bad parameter
		TextFile_Purge = 4
		Exit Function
	End If
	
	
	Set FSO = CreateObject("Scripting.FileSystemObject")
	If Not FSO.FileExists( FilePath ) Then
		' File does not exist
		TextFile_Purge = 2
		Exit Function
	End If

	On Error Resume Next
	Set oFile = FSO.GetFile(FilePath)
	If Err.Number <> 0 Then
		' Error getting file
		TextFile_Purge = 3
		Err.Clear
		Exit Function
	End If
	On Error GoTo 0
	iFileSize = oFile.Size /1024 ' convert to MB
	
	If iFileSize < MaxSize Then
		' Have not reached maximum size yet
		' No purge needed
		TextFile_Purge = 0
		Exit Function
	End If
	MsgBox "FileSize: " & iFileSize/1024 & VbCrLf & "Limit:    " & MaxSize
	On Error Resume Next
	Set oFile = FSO.OpenTextFile(FilePath, ForReading)
	If Err.Number <> 0 Then
		' Error reading file
		TextFile_Purge = 4
		Err.Clear
		Exit Function
	End If
	On Error GoTo 0
	
	sFileText = oFile.ReadAll
	oFile.Close
	
	iLenText = Len(sFileText)
	iPurgeChrs = Int(iLenText * (PurgePercent/100))
	If bTop Then
		iStart = InStr(iPurgeChrs, sFileText, Marker, vbtextcompare)
		If iStart = 0 Then iStart = iPurgeChrs
		iEnd = iLenText
	Else
		iStart = 1
		iEnd = InStr(iLenText - iPurgeChrs, sFileText, Marker, vbtextcompare)
		If iEnd = 0 Then iEnd = iLenText - iPurgeChrs
		iEnd = iEnd - 1
	End If
	
	sFileText = Mid(sFileText, iStart, iEnd)
	On Error Resume Next
	Set oFile = FSO.CreateTextFile(FilePath, True, False)
	oFile.Write sFileText
	oFile.Close
	If Err.Number <> 0 Then
		' Error writing the purged log
		TextFile_Purge = 5
		' DEBUG: WScript.Echo Err.Description
		' DEBUG: WScript.Echo FilePath
		Err.Clear
	Else
		' Purged successfully
		TextFile_Purge = 1
		WriteFile = True
	End If
	On Error GoTo 0
	
End Function

Sub Notify(ByVal sMessage, ByVal sTitle, ByVal sTimeOut, ByVal iButtonType)
	If ((Not bInteractive) Or (sTimeOut = 0)) Then
		WScript.Echo String(80,"-") & VbCrLf & _
					 sTitle & VbCrLf & String(80,".") & VbCrLf &_
					 sMessage & VbCrLf & String(80,"-") & VbCrLf 
	Else
		Call PopUp(sMessage, sTitle, sTimeOut, iButtonType)
	End If

End Sub

Sub PopUp(ByVal sMessage, ByVal sTitle, ByVal sTimeOut, ByVal iButtonType)
	' Version 070709 *VARIATION* with button type
	' Displays a popup message for a specified period of time
	' INPUTS:	sMessage: message to display
	'			sTitle: title bar of popup window
	'			sTimeOut: how long to display the popup
	
	Dim wshShell, btnCode
	Set wshShell = CreateObject("WScript.Shell")
	btnCode = wshShell.Popup (sMessage, sTimeOut, sTitle, iButtonType)
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
'' SIG '' Begin signature block
'' SIG '' MIIkCAYJKoZIhvcNAQcCoIIj+TCCI/UCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFOw0tqFJnL32
'' SIG '' GnOifHW8SsOsJlnnoIIe4TCCBBIwggL6oAMCAQICDwDB
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
'' SIG '' AQkEMRYEFK8YgZOoSvFPTAoflmNXhglxjEY1MF4GCisG
'' SIG '' AQQBgjcCAQwxUDBOoCaAJABNAGkAYwByAG8AcwBvAGYA
'' SIG '' dAAgAEwAZQBhAHIAbgBpAG4AZ6EkgCJodHRwOi8vd3d3
'' SIG '' Lm1pY3Jvc29mdC5jb20vbGVhcm5pbmcgMA0GCSqGSIb3
'' SIG '' DQEBAQUABIIBADd888IeD0fIuEU0srjQvURMxQIetAbO
'' SIG '' l2LbexI7yGrdjZkLSMgbAgZFP/58bYAve5Hb9rjaYPKI
'' SIG '' mo878wMlHfALbhyQoWsWyijoGO9PVOmL9FwrY+DVpSqZ
'' SIG '' b+5dr+I/EOA0QpREh0n6IxqResulFYNpI7UfJ8NJeBvB
'' SIG '' 0Q5HUCv7BPkj+71z7zwYIOXney+v0G3XA+tWluBjvhXj
'' SIG '' M/wCzfTFu3wmjoXsqEQv83odVnhzKRos0PqRqMAzVBx0
'' SIG '' FaDhsUjh2PME8s+fv0vp2pbBXzeYDqHqvAfTcHKtUWAF
'' SIG '' fCZyT0t5SuMG94qMrarzXCQTI/k1qVtcSI5RzP6k1zQx
'' SIG '' eeOhggIfMIICGwYJKoZIhvcNAQkGMYICDDCCAggCAQEw
'' SIG '' gYcweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
'' SIG '' bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
'' SIG '' FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMa
'' SIG '' TWljcm9zb2Z0IFRpbWVzdGFtcGluZyBQQ0ECCmFJfO0A
'' SIG '' AAAAAAUwBwYFKw4DAhqgXTAYBgkqhkiG9w0BCQMxCwYJ
'' SIG '' KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0wODAyMDUw
'' SIG '' MjAxMjFaMCMGCSqGSIb3DQEJBDEWBBRv1cG/OLzX2df9
'' SIG '' tMf4M2/ncNr2+TANBgkqhkiG9w0BAQUFAASCAQA7XZHA
'' SIG '' j6G0eq8zxweZhJ9V+Cq4fxo+z+jUqCpts9kPVUI4XQDC
'' SIG '' YdtVfCTEW282RZGVaINSR21uFimNwArmKTl1gIJS0ho0
'' SIG '' Mo+Nff/YFbA72QfcIwanbdkqc+I8efmEeDDBD+/V4BAK
'' SIG '' GG4PT0QHhHAXR20nWW5sWgqGmDJmp/jqvORLrQHkM/tR
'' SIG '' dD/50CE6Pama67xbEEh7PONup3S4JbjA8DCBVEqrvSqq
'' SIG '' 916Z9MqF9OAMTn0oVumRGRDDWfvEQiqAke1KEh2r4bKu
'' SIG '' 30QFqe0F1u5rTkphwobvgi4NgQxhuNyfRxT5uFU4tY46
'' SIG '' muyuHdA0uEO9k7oygLiyGCJiTSGH
'' SIG '' End signature block

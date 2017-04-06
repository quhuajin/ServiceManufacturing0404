'Setup to continue execution if there is an error
On Error Resume Next

'Check if the Matlab runtime is installed.  this is done 
'by checking the registry
Set WshShell = WScript.CreateObject("WScript.shell")
regValue = WshShell.RegRead("HKLM\SOFTWARE\MATLAB\MCRPathDir\MCRPathDir")
       
if isempty(regValue) then
    'Installation is needed

    'Ask user if installation is desired
    installationChoice = MsgBox("Required Component Matlab Runtime Component Not Installed" & vbCrLF &  "Install Now?",vbOKCancel)
    if installationChoice = 1 then
    	WshShell.run("MCRInstaller.exe")
    end if
end if

'Check again if the Matlab runtime component was just intalled
'if so start the script
regValue = WshShell.RegRead("HKLM\SOFTWARE\MATLAB\MCRPathDir\MCRPathDir")
if Not isempty(regValue) then
	'Matlab executables run incredibly slow so copy onto the harddrive
	'and run from there
	Set filesys = CreateObject("Scripting.FileSystemObject")
	Set tempDir = filesys.GetSpecialFolder(2)
	set filesys=CreateObject("Scripting.FileSystemObject")
	MakoScriptsDir = tempDir + "\MakoScripts"
	X = filesys.CreateFolder(MakoScriptsDir)
	X = filesys.CopyFolder("WindowsBinaries\loadServiceMfgScripts_*",MakoScriptsDir,true)
	X = filesys.CopyFile("WindowsBinaries\loadServiceMfgScripts.*",MakoScriptsDir,true)
	sourceDrive = filesys.GetDriveName(WshShell.CurrentDirectory)
	'Copy the rest of the scripts using the matlab script
	'to show a nice GUI
	WshShell.CurrentDirectory = MakoScriptsDir
	X = WshShell.run("loadServiceMfgScripts.exe """ + sourceDrive + """",0,true)

	'Execute the default Matlab Executable
	WshShell.CurrentDirectory = MakoScriptsDir
	X = WshShell.run("ServiceAndManufacturingMain.exe",0,true)
   	
	'All done Clean up
	WshShell.CurrentDirectory = tempDir 
	X = filesys.deleteFolder(MakoScriptsDir,true)
end if 

#Treating All Errors as Terminating
$ErrorActionPreference = "Stop"

#Global variables -> Change Variables Here!!
#Connection Parameters
$remoteMachine = "192.168.1.1"
$userName = "username"
$userPassword = "userpassword"
$folderForWarFiles = "D:\upload\"
$path1 = "C:\Users\joshimuk\data1"
$path2 = "C:\Users\joshimuk\data2"
#Posh-SSH package path
Import-Module D:\Tools\Posh-SSH
#Update Email Address
$To = "<mukesh.bciit@gmail.com>"

#No Changes Needed Here!!
#Connection Parameters
$remotepath1 = "/tmp/data1/"
$remotepath2 = "/tmp/data2/"
$sftpSshPort = "22"

#Script start time
$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#Parameter validation
$instanceName = $args[0]
if($instanceName -eq "test1" -OR $instanceName -eq "test2") {
	Write-Host "Script started for : '$instanceName' at : '$startTime'"
} else {
	Write-Host "'$instanceName' is not a valid parameter, valid parameter is test1 or test2"
    Exit
}

#Email configuration
$SMTP = ""
$From = ""
#Function to sending Email (How functions work in powershell)
function SendMail {
	Param ([String] $Subject, [String] $Body)
	#Comment/Uncomment below line for sending/stopping emails
	Send-MailMessage -To $To -From $From -SmtpServer $SMTP -Body $Body -Subject $Subject
}

Try
{
	#Credentila for accessing server
	$Password = ConvertTo-SecureString $userPassword -AsPlainText -Force
	$Credential = New-Object System.Management.Automation.PSCredential ($userName, $Password)

	#Create ssh session
	New-SSHSession -ComputerName $remoteMachine -Credential $Credential -Port $sftpSshPort -AcceptKey

	#Perform some operation inside the server
	Invoke-SSHCommand -Index 0 -Command "source ~/.profile; touch $instanceName"

	#Remove directories
	if($instanceName -eq "test1") {
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath1/A"
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath1/B"
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath1/C"
	} else {
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath2/D"
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath2/E"
		Invoke-SSHCommand -Index 0 -Command "rm -rf $remotepath2/F"
	}

	#Stop SSH Session
	Get-SSHSession | Remove-SSHSession

	# Clean folder
	Remove-Item $folderForWarFiles\* -Filter *.war

	# Copy *.war files from target to one folder for doing SFTP
	if($instanceName -eq "test1") {
		Copy-Item $path1\source\A.war $folderForWarFiles
		Copy-Item $path1\source\B.war $folderForWarFiles
		Copy-Item $path1\source\C.war $folderForWarFiles
	} else {
		Copy-Item $path2\sources\D.war $folderForWarFiles
		Copy-Item $path2\sources\E.war $folderForWarFiles
		Copy-Item $path2\sources\F.war $folderForWarFiles
	}

	#Remove any open sessions
	Get-SFTPsession | Remove-SFTPSession | Out-Null

	#Create SFTP Session
	$Session = New-SFTPSession -ComputerName $remoteMachine -Credential $Credential -Port $sftpSshPort -AcceptKey

	$sftpRemotePath = $remotepath2
	if($instanceName -eq "test1") {
		$sftpRemotePath = $remotepath1
	}

	#Specify the local files
	Set-Location $folderForWarFiles
	$LocalFiles = Get-ChildItem $folderForWarFiles

	#Now copy the files up
	ForEach ($LocalFile in $LocalFiles)
	{
		$uploadTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		Write-Host "Uploading started for $LocalFile at: $uploadTime"
		Set-SFTPFile -SessionId $Session.SessionId -LocalFile "$LocalFile" -RemotePath "$sftpRemotePath" -Overwrite
		$uploadedTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		Write-Host "Upload completed for $LocalFile at: $uploadedTime`n"
	}

	#Remove SFTP session
	Get-SFTPsession | Remove-SFTPSession

	# Clean folder
	Remove-Item $folderForWarFiles\* -Filter *.war

	#Create ssh session
	New-SSHSession -ComputerName $remoteMachine -Credential $Credential -AcceptKey

	#Execute command in server
	Invoke-SSHCommand -Index 0 -Command "source ~/.profile; touch $instanceName"

	#Stop SSH Session
	Get-SSHSession | Remove-SSHSession
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    # $FailedItem = $_.Exception.ItemName
	$Subject = "Upload Failed($instanceName)"
	$Body = "Hi Team, `r`n`nUpload failed `r`n`nError message: $ErrorMessage `r`n`nRegards, `r`nTeam"
	Write-Host "Upload Failed with message: '$ErrorMessage', execution will stop"
	SendMail -Subject $Subject -Body $Body
    Exit
}

#Print Script Finish Time
$finishTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Script finish time: $finishTime"

#Print Total Time Used
$totalTime = New-TimeSpan -Start $startTime -End $finishTime
Write-Host "Script completed in: $totalTime"

#Send an email when process has ended
$Subject = "Upload Completed($instanceName)"
$Body = "Hi Team,`r`n`nUpload completed successfully `r`n`nFiles copied `r`nFrom: $folderForWarFiles `r`nTo: $sftpRemotePath`r`nTotal time taken: $totalTime `r`n`nTest server: $($Session.Host)`r`n`nRegards,`r`nTeam"
SendMail -Subject $Subject -Body $Body

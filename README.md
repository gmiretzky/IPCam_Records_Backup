# IPCam_Records_Backup
Automation tool for downloading IP camera video records 

This powershell script was build to allow downloading of video records from a Reolink camera.

The configuration contain two files, one for configuration and the other for device list. 

The configuration file contains information regarding the operation of the backup script. 

The device listfile contains infromation regarding the devices. 

For each device, under the devie list file, will have the type of the device, aka - Device_Type 
The device type is an ID that will cause the backup script to run the worker script that is assign to that same Device_Type. 
Each worker file is located in its own directory under the main workers folder .
The worker.ps1 file , contain a defenition of a worker class. 
the backup script will import the worker class and will run the [worker]::RunBackup() function. 
For example, if the device type is reolink, the script will be:
workers/reolink/worker.ps1 
And the backup will be done using: 
#Create new worker: 
$g=[worker]::new(camera_ip, username, password , camera_name, owner_name, number of days to backup, backup path, working path)
#Run backup
$g.RunBackup()


Requirements: 

PowerShell 7.3.1

To aviod Certificate issues , this script uses the -SkipCertificateCheck for Invoke-RestMethod . For it to work, there is a need to install PowerShell 7.3.1 (This is the tested version). 

You can use 'choco install powershell-core' 

This is still under build - should be consider as beta only. 

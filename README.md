# IPCam_Records_Backup
Automation tool for downloading IP camera video records 

This powershell script was build to allow downloading of video records from a Reolink camera.

The configuration contain two files, one for configuration and the other for device list. 

The configuration file contains information regarding the operation of the backup script. 

The device listfile contains infromation regarding the devices. 

For each device, under the devie list file, will have the type of the device, aka - Device_Type 
The device type is an ID that will cause the backup script to run the worker script that is assign to that same Device_Type. 
the backup script will try to run the script name worker.ps1 witch is located under the workers/device_type/ folder. 
For example, if the device type is reolink, the script will be:
workers/reolink/worker.ps1 


Requirements: 
PowerShell 7.3.1
This script uses the -SkipCertificateCheck for Invoke-RestMethod . For it to work, there is a need to install PowerShell 7.3.1 (This is the tested version). 
You can use 'choco install powershell-core' 

This is still under build - should be consider as beta only. 

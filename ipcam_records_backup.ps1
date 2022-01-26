#This is the main function for the playback backup utility 
#Setup some varibles 
$working_path = "D:\google_drive\backup\Guy\reolink_powershell_scripts\"
$configuration_file = "reolink_playbackup.conf"

#start 
#Get configuration from file 
$config = @{}
foreach ($l in (Get-Content $working_path$configuration_file | where{$_ -ne "" -and $_ -notlike "#*"}))
{
    $config.Add(($l.split('='))[0].trim(),($l.split('='))[1].trim())
}

#Get a list of cameras 
$cameras = (Get-Content -Path "$($working_path)$($config.camera_list)" | where {$_ -ne "" -and $_ -notlike "#*"})


#Now, for each day from the configuration , we will check each camera for backups 
foreach ($d in 1..$config.days_to_download)
{
    foreach ($c in $cameras)
    {
        #Call the working script 
        Start-Process powershell "$($working_path)reolink_download_worker.ps1 -camera_ip 1 $($c[0]) -username $($c[1]) -password $($c[2])"
    }
}


